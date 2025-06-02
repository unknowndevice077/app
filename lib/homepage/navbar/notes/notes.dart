import 'package:flutter/material.dart';
import 'dart:async';
import 'note_models.dart';
import 'note_data_manager.dart';
import 'note_ui_components.dart';
import 'note_image_manager.dart';
import 'note_attachment_manager.dart';
import 'note_subject_manager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotesScreen extends StatefulWidget {
  final Function(bool)? onNoteEditingChanged;

  const NotesScreen({super.key, this.onNoteEditingChanged});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  bool _showingAddNote = false;

  void _toggleAddNote() {
    if (!mounted) return;
    
    setState(() {
      _showingAddNote = !_showingAddNote;
    });
    widget.onNoteEditingChanged?.call(_showingAddNote);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: _showingAddNote
          ? AddNoteScreen(onBack: _toggleAddNote)
          : NotesOverview(onAddNote: _toggleAddNote),
    );
  }
}

class NotesOverview extends StatefulWidget {
  final VoidCallback onAddNote;

  const NotesOverview({super.key, required this.onAddNote});

  @override
  State<NotesOverview> createState() => _NotesOverviewState();
}

class _NotesOverviewState extends State<NotesOverview> {
  bool _editMode = false;
  final NoteDataManager _dataManager = NoteDataManager();
  final NoteUIComponents _uiComponents = NoteUIComponents();

  Future<void> _deleteNote(String docId) async {
    await _dataManager.deleteNote(docId);
    
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Note deleted'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _uiComponents.buildNotesAppBar(
        context: context,
        editMode: _editMode,
        onAddNote: widget.onAddNote,
        onEditModeToggle: () {
          if (!mounted) return;
          setState(() {
            _editMode = !_editMode;
          });
        },
      ),
      body: Container(
        color: Colors.white,
        child: _uiComponents.buildNotesList(
          context: context,
          editMode: _editMode,
          onDeleteNote: _deleteNote,
        ),
      ),
    );
  }
}

class AddNoteScreen extends StatefulWidget {
  final VoidCallback onBack;
  final String? initialTitle;
  final String? docId;
  final String? initialSubject;

  const AddNoteScreen({
    super.key,
    required this.onBack,
    this.initialTitle,
    this.docId,
    this.initialSubject,
  });

  @override
  State<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends State<AddNoteScreen> with WidgetsBindingObserver {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController contentController = TextEditingController();
  final FocusNode titleFocusNode = FocusNode();
  final FocusNode contentFocusNode = FocusNode();

  // Managers
  final NoteDataManager _dataManager = NoteDataManager();
  final NoteImageManager _imageManager = NoteImageManager();
  final NoteAttachmentManager _attachmentManager = NoteAttachmentManager();
  final NoteSubjectManager _subjectManager = NoteSubjectManager();
  final NoteUIComponents _uiComponents = NoteUIComponents();

  // State variables
  List<String> _uploadedImageIds = [];
  final bool _isLoadingImages = false;
  List<Map<String, dynamic>> attachments = [];
  String? selectedSubject;
  List<String> subjects = [];
  bool subjectsLoading = true;
  List<Task> _tasks = [];

  Timer? _autosaveTimer;
  bool _hasUnsavedChanges = false;
  String _lastSavedTitle = '';
  String _lastSavedContent = '';
  NavigatorState? _navigator;
  bool _isSaving = false; // Add this variable
  bool isEditing = false; // <-- Add this line

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeScreen();
    isEditing = widget.docId != null; // <-- Set initial state
  }

  void _initializeScreen() {
    if (widget.initialTitle != null) {
      titleController.text = widget.initialTitle!;
      _lastSavedTitle = widget.initialTitle!;
    }

    selectedSubject = widget.initialSubject;
    attachments = [];

    _loadData();
    _setupListeners();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.docId == null && mounted) {
        titleFocusNode.requestFocus();
      }
    });
  }

  void _loadData() {
    _subjectManager.fetchSubjects().then((fetchedSubjects) {
      if (mounted) {
        setState(() {
          subjects = fetchedSubjects;
          subjectsLoading = false;
        });
      }
    });

    if (widget.docId != null) {
      _dataManager.loadExistingData(widget.docId!).then((noteData) {
        if (mounted && noteData != null) {
          setState(() {
            titleController.text = noteData.title;
            contentController.text = noteData.content;
            selectedSubject = noteData.subject;
            _uploadedImageIds = noteData.imageIds;
            attachments = noteData.attachments;
            _tasks = noteData.tasks;
          });
        }
      });
    }
  }

  void _setupListeners() {
    titleController.addListener(_onContentChanged);
    contentController.addListener(_onContentChanged);
    _setupAutosave();
  }

  void _setupAutosave() {
    _autosaveTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      if (_hasUnsavedChanges) {
        _saveNoteQuietly().catchError((e) {
          print('Autosave error: $e');
        });
      }
    });
  }

  void _onContentChanged() {
    final currentTitle = titleController.text.trim();
    final currentContent = contentController.text.trim();
    if (currentTitle != _lastSavedTitle || currentContent != _lastSavedContent) {
      if (!mounted) return;
      
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<void> _saveNoteQuietly() async {
    if (_isSaving || !mounted) return;
    _isSaving = true;
    try {
      final noteData = NoteData(
        title: titleController.text.trim().isEmpty ? 'Untitled' : titleController.text.trim(),
        content: contentController.text.trim(),
        subject: selectedSubject ?? '',
        tasks: _tasks,
        attachments: attachments,
        imageIds: _uploadedImageIds,
      );

      final success = await _dataManager.saveNote(
        noteData: noteData,
        docId: widget.docId,
      );

      if (success && mounted) {
        _lastSavedTitle = titleController.text.trim();
        _lastSavedContent = contentController.text.trim();
        setState(() {
          _hasUnsavedChanges = false;
          if (!isEditing) isEditing = true; // <-- Set to true after first save
        });
      }
    } catch (e) {
      print('Save error: $e');
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _saveAndExit() async {
    await _saveNoteQuietly();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('Note saved successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: EdgeInsets.all(16),
          duration: Duration(seconds: 2),
        ),
      );
      
      widget.onBack();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _navigator = Navigator.of(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosaveTimer?.cancel();
    
    // Remove listeners before disposing controllers
    titleController.removeListener(_onContentChanged);
    contentController.removeListener(_onContentChanged);
    
    // Don't save on dispose to prevent crashes
    titleController.dispose();
    contentController.dispose();
    titleFocusNode.dispose();
    contentFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      if (_hasUnsavedChanges) {
        _saveNoteQuietly();
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (_hasUnsavedChanges && !_isSaving) {
      await _saveNoteQuietly();
    }
    return true;
  }

  Future<void> _addFileToNote() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final fileName = result.files.single.name;
        final filePath = result.files.single.path!;
        final fileSize = result.files.single.size;

        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        // Save file metadata to Firestore (or your note's attachments list)
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notes')
            .doc(widget.docId) // or the current note's ID
            .collection('files')
            .add({
          'name': fileName,
          'path': filePath,
          'addedAt': FieldValue.serverTimestamp(),
          'size': fileSize,
          'type': 'file',
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Text('File added successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Error adding file'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: _uiComponents.buildAddNoteScreen(
        context: context,
        titleController: titleController,
        contentController: contentController,
        titleFocusNode: titleFocusNode,
        contentFocusNode: contentFocusNode,
        selectedSubject: selectedSubject,
        uploadedImageIds: _uploadedImageIds,
        isLoadingImages: _isLoadingImages,
        attachments: attachments,
        tasks: _tasks,
        onBack: () async {
          print('onBack called');
          if (_hasUnsavedChanges && !_isSaving) {
            try {
              print('Saving note...');
              await _saveNoteQuietly();
              print('Note saved.');
            } catch (e) {
              print('Error saving note: $e');
            }
          }
          if (mounted) {
            try {
              print('Calling widget.onBack');
              widget.onBack();
              print('widget.onBack finished');
            } catch (e) {
              print('Error in widget.onBack: $e');
            }
          }
        },
        onSaveAndExit: _saveAndExit,
        onSubjectSelection: () => _subjectManager.showSubjectSelection(
          context,
          subjects,
          selectedSubject,
          subjectsLoading,
          (newSubject) {
            if (mounted) {
              setState(() {
                selectedSubject = newSubject;
                _hasUnsavedChanges = true;
              });
            }
          },
        ),
        onImagePicker: () => _imageManager.showImagePicker(
          context,
          (imageId) {
            if (mounted && imageId != null) {
              setState(() {
                _uploadedImageIds.add(imageId);
                _hasUnsavedChanges = true;
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 20),
                      SizedBox(width: 12),
                      Text('Image added successfully!'),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: EdgeInsets.all(16),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
          widget.docId, // Pass the note ID
        ),
        onImageRemove: (imageId) {
          if (mounted) {
            setState(() {
              _uploadedImageIds.remove(imageId);
              _hasUnsavedChanges = true;
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.white, size: 20),
                    SizedBox(width: 12),
                    Text('Image removed'),
                  ],
                ),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: EdgeInsets.all(16),
                duration: Duration(seconds: 1),
              ),
            );
          }
        },
        onAttachmentOptions: () => _attachmentManager.showAttachmentOptions(
          context,
          (attachment) {
            if (mounted && attachment != null) {
              setState(() {
                attachments.add(attachment);
                _hasUnsavedChanges = true;
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 20),
                      SizedBox(width: 12),
                      Text('File attached successfully!'),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: EdgeInsets.all(16),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
        ),
        onAttachmentOpen: (attachment) => _attachmentManager.openAttachment(context, attachment),
        onAttachmentRemove: (index) {
          if (mounted) {
            setState(() {
              attachments.removeAt(index);
              _hasUnsavedChanges = true;
            });
          }
        },
        isEditing: isEditing, // <-- Pass the state here!
      ),
    );
  }
}
