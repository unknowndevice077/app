import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_sound/flutter_sound.dart';

// Import the separated modules
import 'drawing.dart';
import 'todo.dart';
import 'attachments.dart';
import 'text_formatter.dart';

class Notes extends StatefulWidget {
  const Notes({super.key});

  @override
  State<Notes> createState() => _NotesState();
}

class _NotesState extends State<Notes> {
  String get uid => FirebaseAuth.instance.currentUser!.uid;

  bool _subjectsLoading = true;
  List<String> _subjects = [];
  String? _selectedSubject;
  bool _deleteMode = false;
  final Set<String> _selectedNotes = {};

  @override
  void initState() {
    super.initState();
    fetchSubjects();
  }

  // Enhanced helper method for safe field access
  String _getFieldSafely(Map<String, dynamic>? data, String fieldName, [String defaultValue = '']) {
    try {
      if (data == null || !data.containsKey(fieldName)) {
        return defaultValue;
      }
      final value = data[fieldName];
      if (value == null) {
        return defaultValue;
      }
      return value.toString().trim();
    } catch (e) {
      print('Error accessing field "$fieldName": $e');
      return defaultValue;
    }
  }

  Future<void> fetchSubjects() async {
    try {
      setState(() {
        _subjectsLoading = true;
      });
      
      // Fixed: Use per-user Classes collection
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('Classes')
          .get();
      final uniqueSubjects = <String>{};
      
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final title = _getFieldSafely(data, 'title');
          if (title.isNotEmpty) {
            uniqueSubjects.add(title);
          }
        } catch (e) {
          print('Error processing document ${doc.id}: $e');
        }
      }
      
      setState(() {
        _subjects = uniqueSubjects.toList();
        _subjectsLoading = false;
      });
    } catch (e) {
      print('Error fetching subjects: $e');
      setState(() {
        _subjects = [];
        _subjectsLoading = false;
      });
    }
  }

  void _openAddNoteScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddNoteScreen(
          initialSubject: _selectedSubject,
        ),
      ),
    );
  }

  Future<void> _deleteSelectedNotes() async {
    try {
      for (String docId in _selectedNotes) {
        // Fixed: Use per-user Notes collection
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('Notes')
            .doc(docId)
            .delete();
      }
      setState(() {
        _selectedNotes.clear();
        _deleteMode = false;
      });
    } catch (e) {
      print('Error deleting notes: $e');
      setState(() {
        _selectedNotes.clear();
        _deleteMode = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          'Notes',
          style: GoogleFonts.dmSerifText(fontSize: 40),
        ),
        actions: [
          if (_deleteMode) ...[
            IconButton(
              icon: const Icon(Icons.close, color: Colors.black),
              tooltip: 'Cancel',
              onPressed: () {
                setState(() {
                  _deleteMode = false;
                  _selectedNotes.clear();
                });
              },
            ),
            if (_selectedNotes.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: 'Delete Selected (${_selectedNotes.length})',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Notes'),
                      content: Text('Delete ${_selectedNotes.length} selected note(s)?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await _deleteSelectedNotes();
                  }
                },
              ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.black),
              tooltip: 'Delete Notes',
              onPressed: () {
                setState(() {
                  _deleteMode = true;
                  _selectedNotes.clear();
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.add, color: Colors.black, size: 28),
              tooltip: 'New Note',
              onPressed: _subjectsLoading ? null : _openAddNoteScreen,
            ),
          ],
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // ✅ Already using per-user Notes collection - this is correct
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('Notes')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading notes',
                    style: GoogleFonts.dmSerifText(fontSize: 22, color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.note_add, color: Colors.grey, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'No notes found',
                    style: GoogleFonts.dmSerifText(fontSize: 22, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap the + button to create your first note',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          
          final notes = snapshot.data!.docs.toList();

          return ListView.builder(
            itemCount: notes.length,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            itemBuilder: (context, index) {
              final doc = notes[index];
              final data = doc.data() as Map<String, dynamic>?;

              // Use safe field access everywhere
              final title = _getFieldSafely(data, 'title');
              final content = _getFieldSafely(data, 'content');
              final subject = _getFieldSafely(data, 'subject');
              final imagePath = _getFieldSafely(data, 'imagePath');
              final filePath = _getFieldSafely(data, 'filePath');
              final audioPath = _getFieldSafely(data, 'audioPath');

              final isSelected = _selectedNotes.contains(doc.id);

              return Card(
                key: ValueKey(doc.id),
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                color: isSelected ? Colors.red[100] : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    if (_deleteMode) {
                      setState(() {
                        if (isSelected) {
                          _selectedNotes.remove(doc.id);
                        } else {
                          _selectedNotes.add(doc.id);
                        }
                      });
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddNoteScreen(
                            docId: doc.id,
                            initialTitle: title,
                            initialContent: content,
                            initialSubject: subject,
                            initialImagePath: imagePath.isNotEmpty ? imagePath : null,
                            initialFilePath: filePath.isNotEmpty ? filePath : null,
                            initialAudioPath: audioPath.isNotEmpty ? audioPath : null,
                          ),
                        ),
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title.isNotEmpty ? title : 'Untitled',
                                style: GoogleFonts.dmSerifText(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                content.isNotEmpty ? content : 'No content',
                                style: GoogleFonts.roboto(
                                  fontSize: 16,
                                  color: Colors.black54,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (subject.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.book, size: 14, color: Colors.deepPurple[300]),
                                    const SizedBox(width: 4),
                                    Text(
                                      subject,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.deepPurple[300],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (imagePath.isNotEmpty || filePath.isNotEmpty || audioPath.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (imagePath.isNotEmpty)
                                      Icon(Icons.image, size: 16, color: Colors.blue[400]),
                                    if (filePath.isNotEmpty)
                                      Icon(Icons.attach_file, size: 16, color: Colors.green[400]),
                                    if (audioPath.isNotEmpty)
                                      Icon(Icons.audiotrack, size: 16, color: Colors.orange[400]),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Has attachments',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (_deleteMode)
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Checkbox(
                              value: isSelected,
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedNotes.add(doc.id);
                                  } else {
                                    _selectedNotes.remove(doc.id);
                                  }
                                });
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class AddNoteScreen extends StatefulWidget {
  final String? initialTitle;
  final String? initialContent;
  final String? docId;
  final String? initialImagePath;
  final String? initialFilePath;
  final String? initialAudioPath;
  final String? initialSubject;

  const AddNoteScreen({
    super.key,
    this.initialTitle,
    this.initialContent,
    this.docId,
    this.initialImagePath,
    this.initialFilePath,
    this.initialAudioPath,
    this.initialSubject,
  });

  @override
  State<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends State<AddNoteScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  List<Map<String, dynamic>> _attachments = [];
  bool _isRecording = false;
  final recorder = FlutterSoundRecorder();
  String? _pendingAudioPath;
  String? _selectedSubject;
  List<String> _subjects = [];
  bool _subjectsLoading = true;
  final Set<int> _selectedAttachments = {};
  
  // Drawing functionality
  bool _isDrawingMode = false;
  List<DrawingPoint> _drawingPoints = <DrawingPoint>[];
  List<List<DrawingPoint>> _drawingHistory = [];
  int _historyIndex = -1;
  Color _selectedColor = Colors.blue;
  bool _isErasing = false;
  double _strokeWidth = 3.0;
  bool _showColorPalette = false;
  bool _showBrushSizes = false;
  
  // Available colors and brush sizes from helpers
  late final List<Color> _drawingColors = DrawingHelper.getDefaultColors();
  late final List<double> _brushSizes = DrawingHelper.getDefaultBrushSizes();

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  // Enhanced helper method for safe field access
  String _getFieldSafely(Map<String, dynamic>? data, String fieldName, [String defaultValue = '']) {
    try {
      if (data == null || !data.containsKey(fieldName)) {
        return defaultValue;
      }
      final value = data[fieldName];
      if (value == null) {
        return defaultValue;
      }
      return value.toString().trim();
    } catch (e) {
      print('Error accessing field "$fieldName": $e');
      return defaultValue;
    }
  }

  // Drawing methods
  void _addDrawingPoint(Offset point) {
    setState(() {
      _drawingPoints.add(DrawingPoint(
        offset: point,
        color: _selectedColor,
        strokeWidth: _strokeWidth,
        isEraser: _isErasing,
      ));
    });
  }

  void _addDrawingNull() {
    setState(() {
      _drawingPoints.add(DrawingPoint(
        offset: null,
        color: _selectedColor,
        strokeWidth: _strokeWidth,
        isEraser: _isErasing,
      ));
      _saveToHistory();
    });
  }

  void _saveToHistory() {
    DrawingHelper.saveToHistory(
      _drawingHistory,
      _drawingPoints,
      _historyIndex,
      (newHistory, newIndex) {
        setState(() {
          _drawingHistory = newHistory;
          _historyIndex = newIndex;
        });
      },
    );
  }

  void _clearDrawing() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Drawing'),
        content: const Text('Are you sure you want to clear the entire drawing? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _drawingPoints.clear();
        _saveToHistory();
      });
    }
  }

  void _toggleDrawingMode() {
    setState(() {
      _isDrawingMode = !_isDrawingMode;
      _showColorPalette = false;
      _showBrushSizes = false;
      
      // Initialize history properly
      if (_isDrawingMode && _drawingHistory.isEmpty) {
        _drawingHistory.add(List<DrawingPoint>.from(_drawingPoints));
        _historyIndex = 0;
      }
    });
    
    if (_isDrawingMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Drawing mode enabled. Use the toolbar below!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _selectColor(Color color) {
    setState(() {
      _selectedColor = color;
      _isErasing = false;
      _showColorPalette = false;
    });
  }

  void _selectBrushSize(double size) {
    setState(() {
      _strokeWidth = size;
      _showBrushSizes = false;
    });
  }

  void _toggleEraser() {
    setState(() {
      _isErasing = !_isErasing;
      _showColorPalette = false;
      _showBrushSizes = false;
    });
  }

  void _toggleColorPalette() {
    setState(() {
      _showColorPalette = !_showColorPalette;
      _showBrushSizes = false;
    });
  }

  void _toggleBrushSizes() {
    setState(() {
      _showBrushSizes = !_showBrushSizes;
      _showColorPalette = false;
    });
  }

  void _undo() {
    if (_historyIndex > 0) {
      setState(() {
        _historyIndex--;
        _drawingPoints = List<DrawingPoint>.from(_drawingHistory[_historyIndex]);
      });
    }
  }

  void _redo() {
    if (_historyIndex < _drawingHistory.length - 1) {
      setState(() {
        _historyIndex++;
        _drawingPoints = List<DrawingPoint>.from(_drawingHistory[_historyIndex]);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialTitle != null) {
      _titleController.text = widget.initialTitle!;
    }
    if (widget.initialContent != null) {
      _contentController.text = widget.initialContent!;
    }
    _selectedSubject = widget.initialSubject;

    _attachments = [];
    if (widget.initialImagePath != null && widget.initialImagePath!.isNotEmpty) {
      _attachments.add({'type': 'image', 'path': widget.initialImagePath!});
    }
    if (widget.initialFilePath != null && widget.initialFilePath!.isNotEmpty) {
      _attachments.add({'type': 'file', 'path': widget.initialFilePath!});
    }
    if (widget.initialAudioPath != null && widget.initialAudioPath!.isNotEmpty) {
      _attachments.add({'type': 'audio', 'path': widget.initialAudioPath!});
    }

    fetchSubjects();
    _initializeRecorder();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    recorder.closeRecorder();
    super.dispose();
  }

  Future<void> _initializeRecorder() async {
    try {
      await recorder.openRecorder();
    } catch (e) {
      print('Failed to initialize recorder: $e');
    }
  }

  Future<void> fetchSubjects() async {
    try {
      setState(() {
        _subjectsLoading = true;
      });
      
      // Fixed: Use per-user Classes collection
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('Classes')
          .get();
      final uniqueSubjects = <String>{};
      
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final title = _getFieldSafely(data, 'title');
          if (title.isNotEmpty) {
            uniqueSubjects.add(title);
          }
        } catch (e) {
          print('Error processing document ${doc.id}: $e');
        }
      }
      
      setState(() {
        _subjects = uniqueSubjects.toList();
        _subjectsLoading = false;
        if (_selectedSubject != null && !_subjects.contains(_selectedSubject)) {
          _subjects.add(_selectedSubject!);
        }
      });
    } catch (e) {
      print('Error fetching subjects: $e');
      setState(() {
        _subjects = [];
        _subjectsLoading = false;
      });
    }
  }

  void _saveNote() async {
    try {
      final title = _titleController.text.trim();
      final content = _contentController.text.trim();

      String imagePath = '';
      String filePath = '';
      String audioPath = '';

      for (final att in _attachments) {
        if (att['type'] == 'image' && imagePath.isEmpty) imagePath = att['path'];
        if (att['type'] == 'file' && filePath.isEmpty) filePath = att['path'];
        if (att['type'] == 'audio' && audioPath.isEmpty) audioPath = att['path'];
      }

      final Map<String, dynamic> noteData = {
        'title': title,
        'content': content,
        'imagePath': imagePath,
        'filePath': filePath,
        'audioPath': audioPath,
        'subject': (_selectedSubject ?? '').trim(),
        'subject_normalized': (_selectedSubject ?? '').trim().toLowerCase(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.docId != null && widget.docId!.isNotEmpty) {
        // Fixed: Use per-user Notes collection for updates
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('Notes')
            .doc(widget.docId)
            .update(noteData);
      } else {
        noteData['createdAt'] = FieldValue.serverTimestamp();
        // Fixed: Use per-user Notes collection for new notes
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('Notes')
            .add(noteData);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving note: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickAndSaveImage() async {
    final path = await AttachmentManager.pickAndSaveImage();
    if (path != null) {
      setState(() {
        _attachments.add({'type': 'image', 'path': path});
      });
    }
  }

  Future<void> _pickAndSaveFile() async {
    final path = await AttachmentManager.pickAndSaveFile();
    if (path != null) {
      setState(() {
        _attachments.add({'type': 'file', 'path': path});
      });
    }
  }

  Future<void> _recordOrStopAudio() async {
    if (!_isRecording) {
      final path = await AttachmentManager.recordAudio(recorder);
      if (path != null) {
        setState(() {
          _isRecording = true;
        });
        _pendingAudioPath = path;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission is required for recording')),
          );
        }
      }
    } else {
      await AttachmentManager.stopRecording(recorder);
      setState(() {
        _isRecording = false;
        _attachments.removeWhere((att) => att['type'] == 'audio');
        if (_pendingAudioPath != null) {
          _attachments.add({'type': 'audio', 'path': _pendingAudioPath!});
        }
      });
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => AttachmentOptionsBottomSheet(
        isRecording: _isRecording,
        onPickImage: _pickAndSaveImage,
        onPickFile: _pickAndSaveFile,
        onToggleRecording: _recordOrStopAudio,
      ),
    );
  }

  void _showSubjectSelection() {
    if (_subjectsLoading || _subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No subjects available.')),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Subject'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('None'),
                onTap: () {
                  setState(() {
                    _selectedSubject = null;
                  });
                  Navigator.pop(context);
                },
                selected: _selectedSubject == null,
                selectedTileColor: Colors.deepPurple[50],
              ),
              ..._subjects.map((subject) {
                return ListTile(
                  title: Text(subject),
                  onTap: () {
                    setState(() {
                      _selectedSubject = subject;
                    });
                    Navigator.pop(context);
                  },
                  selected: _selectedSubject == subject,
                  selectedTileColor: Colors.deepPurple[50],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          widget.docId != null ? 'Edit Note' : 'Add Note',
          style: GoogleFonts.dmSerifText(
            fontSize: 28,
            color: Colors.black,
          ),
        ),
        actions: [
          if (_isDrawingMode) ...[
            IconButton(
              icon: Icon(
                Icons.undo,
                color: _historyIndex > 0 ? Colors.blue : Colors.grey,
              ),
              onPressed: _historyIndex > 0 ? _undo : null,
              tooltip: 'Undo',
            ),
            IconButton(
              icon: Icon(
                Icons.redo,
                color: _historyIndex < _drawingHistory.length - 1 ? Colors.blue : Colors.grey,
              ),
              onPressed: _historyIndex < _drawingHistory.length - 1 ? _redo : null,
              tooltip: 'Redo',
            ),
            TextButton(
              onPressed: _toggleDrawingMode,
              child: Text(
                'Done',
                style: GoogleFonts.roboto(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.menu_book, color: Colors.black, size: 28),
              tooltip: 'Select Subject',
              onPressed: _showSubjectSelection,
            ),
            IconButton(
              icon: const Icon(Icons.check, color: Colors.black),
              tooltip: 'Save',
              onPressed: _saveNote,
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      if (_selectedSubject != null && _selectedSubject!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              const Icon(Icons.book, color: Colors.deepPurple),
                              const SizedBox(width: 8),
                              Text(
                                _selectedSubject!,
                                style: GoogleFonts.roboto(
                                  fontSize: 16,
                                  color: Colors.deepPurple,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      TextField(
                        controller: _titleController,
                        enabled: !_isDrawingMode,
                        style: GoogleFonts.dmSerifText(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'TITLE',
                          hintStyle: GoogleFonts.dmSerifText(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[400],
                            letterSpacing: 2,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          UpperCaseTextFormatter(),
                        ],
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTapDown: _isDrawingMode ? null : (details) => TodoHelper.toggleTodoCompletion(
                            _contentController, 
                            details, 
                            GoogleFonts.roboto(
                              fontSize: 18,
                              fontWeight: FontWeight.normal,
                              color: Colors.black87,
                              letterSpacing: 0.1,
                            )
                          ),
                          onPanUpdate: _isDrawingMode ? (details) => _addDrawingPoint(details.localPosition) : null,
                          onPanEnd: _isDrawingMode ? (details) => _addDrawingNull() : null,
                          child: TextField(
                            controller: _contentController,
                            enabled: !_isDrawingMode,
                            onChanged: (value) => TodoHelper.handleTextChange(_contentController, value),
                            style: GoogleFonts.roboto(
                              fontSize: 18,
                              fontWeight: FontWeight.normal,
                              color: Colors.black87,
                              letterSpacing: 0.1,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: _isDrawingMode ? 'Drawing mode - Use toolbar below to draw!' : 'Write your note here...',
                              hintStyle: GoogleFonts.roboto(
                                fontSize: 18,
                                color: Colors.grey[400],
                                fontStyle: FontStyle.italic,
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            maxLines: null,
                            expands: true,
                            textInputAction: TextInputAction.newline,
                          ),
                        ),
                      ),
                      // Add text statistics
                      if (!_isDrawingMode && _contentController.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              TextStatistics(text: _contentController.text),
                              const SizedBox(width: 8),
                              TodoStatistics(text: _contentController.text),
                            ],
                          ),
                        ),
                      if (_attachments.isNotEmpty && !_isDrawingMode)
                        AttachmentList(
                          attachments: _attachments,
                          selectedAttachments: _selectedAttachments,
                          onToggleSelection: (index) {
                            setState(() {
                              if (_selectedAttachments.contains(index)) {
                                _selectedAttachments.remove(index);
                              } else {
                                _selectedAttachments.add(index);
                              }
                            });
                          },
                          onRemoveSelected: () {
                            setState(() {
                              _selectedAttachments.toList()
                                ..sort((a, b) => b.compareTo(a))
                                ..forEach((i) => _attachments.removeAt(i));
                              _selectedAttachments.clear();
                            });
                          },
                        ),
                    ],
                  ),
                ),
                
                // Drawing layer
                if (_isDrawingMode)
                  Positioned.fill(
                    child: GestureDetector(
                      onPanUpdate: (details) => _addDrawingPoint(details.localPosition),
                      onPanEnd: (details) => _addDrawingNull(),
                      child: CustomPaint(
                        painter: DrawingPainter(_drawingPoints),
                        size: Size.infinite,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Fixed toolbar section
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Main toolbar
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: _isDrawingMode ? DrawingToolbar(
                    selectedColor: _selectedColor,
                    isErasing: _isErasing,
                    strokeWidth: _strokeWidth,
                    showColorPalette: _showColorPalette,
                    showBrushSizes: _showBrushSizes,
                    onToggleColorPalette: _toggleColorPalette,
                    onToggleBrushSizes: _toggleBrushSizes,
                    onToggleEraser: _toggleEraser,
                    onClearDrawing: _clearDrawing,
                  ) : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TodoToolbar(
                        onInsertTodo: () => TodoHelper.insertTodoCircle(_contentController),
                      ),
                      AttachmentToolbar(
                        onShowAttachmentOptions: _showAttachmentOptions,
                      ),
                      IconButton(
                        icon: const Icon(Icons.text_format, color: Colors.black, size: 28),
                        onPressed: () {
                          // Show text formatting options
                          showModalBottomSheet(
                            context: context,
                            builder: (context) => Container(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Text Formatting',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormattingToolbar(controller: _contentController),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.black, size: 28),
                        onPressed: _toggleDrawingMode,
                      ),
                    ],
                  ),
                ),

                // Color palette
                if (_isDrawingMode && _showColorPalette)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      border: Border(top: BorderSide(color: Colors.grey[200]!)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Select Color',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ColorPalette(
                          colors: _drawingColors,
                          selectedColor: _selectedColor,
                          isErasing: _isErasing,
                          onColorSelected: _selectColor,
                        ),
                      ],
                    ),
                  ),

                // Brush size selector
                if (_isDrawingMode && _showBrushSizes)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      border: Border(top: BorderSide(color: Colors.grey[200]!)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Brush Size',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        BrushSizeSelector(
                          brushSizes: _brushSizes,
                          selectedSize: _strokeWidth,
                          onSizeSelected: _selectBrushSize,
                        ),
                      ],
                    ),
                  ),

                // Bottom handle
                if (!_isDrawingMode)
                  SizedBox(
                    height: 20,
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}




