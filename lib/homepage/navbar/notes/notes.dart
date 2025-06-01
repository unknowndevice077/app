import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'note_toolbar.dart';
import 'task_components.dart';
import 'image_widget.dart';
import 'todo.dart';
import 'attachments.dart';

class NotesScreen extends StatefulWidget {
  final Function(bool)? onNoteEditingChanged;

  const NotesScreen({super.key, this.onNoteEditingChanged});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  bool _showingAddNote = false;

  void _toggleAddNote() {
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
      body:
          _showingAddNote
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
  final bool _showTodoFilter = false; // Keep this for the button state
  bool _editMode = false;

  Future<void> _deleteNote(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('Notes')
          .doc(docId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note deleted'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting note: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // Remove _loadTodoTasks() call
  }

  void _onPlusPressed() {
    // Remove todo logic, only handle notes
    widget.onAddNote();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "Notes", // Always show "Notes"
          style: GoogleFonts.dmSerifText(
            fontSize: 26,
            color: Colors.blueGrey[900],
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          // Add plus icon at the top
          IconButton(
            icon: Icon(
              Icons.add,
              color: Colors.blue,
              size: 28,
            ),
            tooltip: "Add Note",
            onPressed: widget.onAddNote,
          ),
          IconButton(
            icon: Icon(
              _editMode ? Icons.close : Icons.edit,
              color: Colors.blueGrey,
              size: 24,
            ),
            tooltip: "Edit Notes",
            onPressed: () {
              setState(() {
                _editMode = !_editMode;
              });
            },
          ),
          // Keep the todo button but navigate to QuickTaskManager
          IconButton(
            icon: Icon(Icons.checklist, color: Colors.blueGrey[400]),
            onPressed: () {
              try {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      backgroundColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black
                          : Colors.white,
                      appBar: AppBar(
                        backgroundColor: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black
                            : Colors.white,
                        elevation: 0,
                        title: Text(
                          'Todo Tasks',
                          style: GoogleFonts.dmSerifText(
                            fontSize: 20,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.blueGrey[900],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        iconTheme: IconThemeData(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                      body: const TodoManager(), // Use TodoManager instead of QuickTaskManager
                    ),
                  ),
                );
              } catch (e) {
                print('Error navigating to TodoManager: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error opening Todo Tasks: $e')),
                );
              }
            },
            tooltip: "Todo Tasks",
          ),
        ],
      ),
      body: Container(
        color: Colors.white,
        child: _buildNotesList(), // Always show notes list
      ),
      // Remove floatingActionButton completely - no longer needed
    );
  }

  Widget _buildNotesList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please log in to view notes'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('Notes')
              .orderBy('updatedAt', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.note_add, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No notes yet',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap + to create your first note',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final title = data['title'] ?? 'Untitled';
            final content = data['content'] ?? '';
            final subject = data['subject'] ?? '';
            final updatedAt =
                (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now();

            return FutureBuilder<Color>(
              future:
                  subject.isNotEmpty
                      ? _getClassColor(subject)
                      : Future.value(_getDefaultColor()),
              builder: (context, colorSnapshot) {
                // Always get a color - either from class or default
                final classColor = colorSnapshot.data ?? _getDefaultColor();

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: classColor, // Always use a color
                      width: 2.5, // Always use thick border
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: classColor.withOpacity(
                          0.15,
                        ), // Always match the border color
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => AddNoteScreen(
                                  onBack: () => Navigator.pop(context),
                                  docId: doc.id,
                                  initialTitle: title,
                                  initialSubject: subject,
                                ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Always show color indicator
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: classColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: GoogleFonts.dmSerifText(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey[900],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_editMode)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    onPressed: () => _deleteNote(doc.id),
                                  ),
                              ],
                            ),

                            // Always show subject badge if subject exists
                            if (subject.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: classColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: classColor.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.book,
                                      color: classColor,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      subject,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: classColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            if (content.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                content,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.blueGrey[600],
                                  height: 1.4,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],

                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDateTime(updatedAt),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                const Spacer(),
                                if (data['tasks'] != null &&
                                    (data['tasks'] as List).isNotEmpty) ...[
                                  Icon(
                                    Icons.check_circle_outline,
                                    size: 14,
                                    color: classColor, // Always use class color
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${(data['tasks'] as List).length} tasks',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color:
                                          classColor, // Always use class color
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ));
              },
            );
          },
        );
      },
    );
  }

  // Add this method to get the actual class color from Firestore:
  Future<Color> _getClassColor(String className) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return _getSubjectColor(className);

      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('Classes')
              .where('title', isEqualTo: className)
              .limit(1)
              .get();

      if (snapshot.docs.isNotEmpty) {
        final classData = snapshot.docs.first.data();
        final colorValue = classData['color'] as int?;
        if (colorValue != null) {
          return Color(colorValue);
        }
      }

      // Always fallback to generated color
      return _getSubjectColor(className);
    } catch (e) {
      // Always fallback to generated color on error
      return _getSubjectColor(className);
    }
  }

  // Add method to get default color for notes without subjects:
  Color _getDefaultColor() {
    return Colors.blueGrey[400]!; // Default color for notes without subjects
  }

  // Update the _getSubjectColor method to ensure it always returns a color:
  Color _getSubjectColor(String subject) {
    if (subject.isEmpty) return _getDefaultColor();

    final hash = subject.toLowerCase().hashCode;
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.amber,
      Colors.cyan,
      Colors.deepOrange,
      Colors.lightGreen,
    ];
    return colors[hash.abs() % colors.length];
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      final hour =
          dateTime.hour == 0
              ? 12
              : dateTime.hour > 12
              ? dateTime.hour - 12
              : dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = dateTime.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[dateTime.weekday - 1];
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}

// ✅ AddNoteScreen
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

  List<String> _uploadedImageIds = [];
  bool _isLoadingImages = false;
  List<Map<String, dynamic>> attachments = [];
  String? selectedSubject;
  List<String> subjects = [];
  bool subjectsLoading = true;
  List<Task> _tasks = [];
  final Set<int> selectedAttachments = {};
  
  // Add these variables for autosave functionality
  Timer? _autosaveTimer;
  bool _hasUnsavedChanges = false;
  String _lastSavedTitle = '';
  String _lastSavedContent = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Add lifecycle observer

    if (widget.initialTitle != null) {
      titleController.text = widget.initialTitle!;
      _lastSavedTitle = widget.initialTitle!;
    }

    selectedSubject = widget.initialSubject;
    attachments = [];

    fetchSubjects();
    _loadExistingTasks();
    _loadExistingImages();

    // Add listeners to detect changes
    titleController.addListener(_onContentChanged);
    contentController.addListener(_onContentChanged);

    // Set up autosave timer
    _setupAutosave();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.docId == null) {
        titleFocusNode.requestFocus();
      }
    });
  }

  // Fetch the list of subjects from Firestore
  Future<void> fetchSubjects() async {
    setState(() {
      subjectsLoading = true;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          subjects = [];
          subjectsLoading = false;
        });
        return;
      }
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('Classes')
          .get();
      setState(() {
        subjects = snapshot.docs.map((doc) => doc['title'] as String).toList();
        subjectsLoading = false;
      });
    } catch (e) {
      setState(() {
        subjects = [];
        subjectsLoading = false;
      });
    }
  }

  // Load existing tasks for editing a note
  Future<void> _loadExistingTasks() async {
    if (widget.docId == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('Notes')
        .doc(widget.docId)
        .get();
    if (doc.exists) {
      final data = doc.data();
      if (data != null && data['tasks'] != null) {
        setState(() {
          _tasks = (data['tasks'] as List)
              .map((task) => Task(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: task['title'] ?? '',
                    isCompleted: task['isCompleted'] ?? false,
                  ))
              .toList();
        });
      }
    }
  }

  // Load existing images for editing a note
  Future<void> _loadExistingImages() async {
    if (widget.docId == null) return;
    setState(() {
      _isLoadingImages = true;
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoadingImages = false;
      });
      return;
    }
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('Notes')
        .doc(widget.docId)
        .get();
    if (doc.exists) {
      final data = doc.data();
      if (data != null && data['imageIds'] != null) {
        setState(() {
          _uploadedImageIds = List<String>.from(data['imageIds']);
        });
      }
    }
    setState(() {
      _isLoadingImages = false;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Remove lifecycle observer
    
    // Save before disposing if there are unsaved changes
    if (_hasUnsavedChanges) {
      _saveNoteQuietly();
    }
    
    _autosaveTimer?.cancel();
    titleController.removeListener(_onContentChanged);
    contentController.removeListener(_onContentChanged);
    titleController.dispose();
    contentController.dispose();
    titleFocusNode.dispose();
    contentFocusNode.dispose();
    super.dispose();
  }

  // Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.inactive || 
        state == AppLifecycleState.detached) {
      // App is being paused/minimized/closed - save progress
      if (_hasUnsavedChanges) {
        _saveNoteQuietly();
      }
    }
  }

  // Set up autosave functionality
  void _setupAutosave() {
    _autosaveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_hasUnsavedChanges) {
        _saveNoteQuietly();
      }
    });
  }

  // Detect content changes
  void _onContentChanged() {
    final currentTitle = titleController.text.trim();
    final currentContent = contentController.text.trim();
    
    if (currentTitle != _lastSavedTitle || currentContent != _lastSavedContent) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  // Silent save without user feedback
  Future<void> _saveNoteQuietly() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final currentTitle = titleController.text.trim();
      final currentContent = contentController.text.trim();

      // Don't save if both title and content are empty
      if (currentTitle.isEmpty && currentContent.isEmpty && _tasks.isEmpty && _uploadedImageIds.isEmpty) {
        return;
      }

      final noteData = {
        'title': currentTitle.isEmpty ? 'Untitled' : currentTitle,
        'content': currentContent,
        'subject': selectedSubject,
        'tasks': _tasks.map((task) => {
          'title': task.title,
          'isCompleted': task.isCompleted,
        }).toList(),
        'attachments': attachments,
        'imageIds': _uploadedImageIds,
        'updatedAt': FieldValue.serverTimestamp(),
        'userId': user.uid,
      };

      if (widget.docId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('Notes')
            .doc(widget.docId)
            .update(noteData);
      } else {
        noteData['createdAt'] = FieldValue.serverTimestamp();
        final docRef = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('Notes')
            .add(noteData);

        // Update image references with the new note ID
        for (final imageId in _uploadedImageIds) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('images')
              .doc(imageId)
              .update({'noteId': docRef.id});
        }
      }

      // Update tracking variables
      _lastSavedTitle = currentTitle;
      _lastSavedContent = currentContent;
      setState(() {
        _hasUnsavedChanges = false;
      });

      print('Note autosaved successfully'); // Debug log
    } catch (e) {
      print('Error during autosave: $e'); // Debug log
    }
  }

  // Enhanced save method with user feedback
  Future<void> saveNoteWithImages() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final currentTitle = titleController.text.trim();
      final currentContent = contentController.text.trim();

      final noteData = {
        'title': currentTitle.isEmpty ? 'Untitled' : currentTitle,
        'content': currentContent,
        'subject': selectedSubject,
        'tasks': _tasks.map((task) => {
          'title': task.title,
          'isCompleted': task.isCompleted,
        }).toList(),
        'attachments': attachments,
        'imageIds': _uploadedImageIds,
        'updatedAt': FieldValue.serverTimestamp(),
        'userId': user.uid,
      };

      if (widget.docId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('Notes')
            .doc(widget.docId)
            .update(noteData);
      } else {
        noteData['createdAt'] = FieldValue.serverTimestamp();
        final docRef = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('Notes')
            .add(noteData);

        for (final imageId in _uploadedImageIds) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('images')
              .doc(imageId)
              .update({'noteId': docRef.id});
        }
      }

      // Update tracking variables
      _lastSavedTitle = currentTitle;
      _lastSavedContent = currentContent;
      setState(() {
        _hasUnsavedChanges = false;
      });

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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving note: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Handle back button press with autosave
  Future<bool> _onWillPop() async {
    if (_hasUnsavedChanges) {
      // Show save dialog
      final shouldSave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.save, color: Colors.orange, size: 24),
              SizedBox(width: 12),
              Text(
                'Save Changes?',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: Text(
            'You have unsaved changes. Do you want to save them before leaving?',
            style: GoogleFonts.inter(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Discard',
                style: GoogleFonts.inter(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'Save',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );

      if (shouldSave == true) {
        await _saveNoteQuietly();
        return true;
      } else if (shouldSave == false) {
        return true; // Discard changes and leave
      } else {
        return false; // Cancel - stay on page
      }
    }
    return true; // No unsaved changes, allow back
  }

  // Update the AddNoteScreen class to include autosave functionality:

  // Rest of your existing methods remain the same...
  // (fetchSubjects, showSubjectSelection, etc.)

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop, // Handle back button
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.black),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop) {
                widget.onBack();
              }
            },
          ),
          title: Row(
            children: [
              // Existing title logic...
              widget.docId == null
                  ? Row(
                      children: [
                        if (selectedSubject != null && selectedSubject!.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: getSubjectColor(selectedSubject!).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: getSubjectColor(selectedSubject!).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: getSubjectColor(selectedSubject!),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.book,
                                  color: getSubjectColor(selectedSubject!),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  selectedSubject!,
                                  style: GoogleFonts.roboto(
                                    fontSize: 14,
                                    color: getSubjectColor(selectedSubject!),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Text(
                          'Add Note',
                          style: GoogleFonts.dmSerifText(
                            fontSize: 28,
                            color: Colors.black,
                          ),
                        ),
                        // Show unsaved indicator
                        if (_hasUnsavedChanges)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.circle,
                              color: Colors.orange,
                              size: 8,
                            ),
                          ),
                      ],
                    )
                  : Row(
                      children: [
                        if (selectedSubject != null && selectedSubject!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: getSubjectColor(selectedSubject!).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: getSubjectColor(selectedSubject!).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: getSubjectColor(selectedSubject!),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.book,
                                  color: getSubjectColor(selectedSubject!),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  selectedSubject!,
                                  style: GoogleFonts.roboto(
                                    fontSize: 14,
                                    color: getSubjectColor(selectedSubject!),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Show unsaved indicator for existing notes too
                        if (_hasUnsavedChanges)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.circle,
                              color: Colors.orange,
                              size: 8,
                            ),
                          ),
                      ],
                    ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.menu_book, color: Colors.black, size: 28),
              tooltip: 'Select Subject',
              onPressed: showSubjectSelection,
            ),
            IconButton(
              icon: Icon(
                Icons.check,
                color: _hasUnsavedChanges ? Colors.orange : Colors.black,
              ),
              tooltip: 'Save',
              onPressed: saveNoteWithImages,
            ),
            if (_uploadedImageIds.isNotEmpty || attachments.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                tooltip: 'Delete All Attachments',
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete all attachments?'),
                      content: const Text(
                        'Are you sure you want to delete all images and files from this note?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    setState(() {
                      _uploadedImageIds.clear();
                      attachments.clear();
                      _hasUnsavedChanges = true; // Mark as changed
                    });
                  }
                },
              ),
          ],
        ),
        body: Column(
          children: [
            // Show autosave status indicator
            if (_hasUnsavedChanges)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                color: Colors.orange[50],
                child: Row(
                  children: [
                    Icon(Icons.edit, color: Colors.orange[700], size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Unsaved changes - will auto-save in 30 seconds',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _saveNoteQuietly(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        minimumSize: Size.zero,
                      ),
                      child: Text(
                        'Save now',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // Title TextField
                    TextField(
                      controller: titleController,
                      focusNode: titleFocusNode,
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
                      onEditingComplete: () {
                        contentFocusNode.requestFocus();
                      },
                    ),
                    const SizedBox(height: 20),

                    // Content TextField
                    TextField(
                      controller: contentController,
                      focusNode: contentFocusNode,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                      maxLines: null,
                      minLines: 5,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Start writing your note...',
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 16,
                        ),
                        contentPadding: const EdgeInsets.all(16),
                        filled: false,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                      ),
                      cursorColor: selectedSubject != null && selectedSubject!.isNotEmpty
                          ? getSubjectColor(selectedSubject!)
                          : Colors.blue,
                      enableInteractiveSelection: true,
                    ),

                    // Images Section
                    if (_uploadedImageIds.isNotEmpty || _isLoadingImages)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          Text(
                            'Images',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_isLoadingImages)
                            const Center(child: CircularProgressIndicator())
                          else
                            SizedBox(
                              height: 180,
                              child: ReorderableListView(
                                scrollDirection: Axis.horizontal,
                                onReorder: (oldIndex, newIndex) {
                                  setState(() {
                                    if (newIndex > oldIndex) newIndex -= 1;
                                    final item = _uploadedImageIds.removeAt(
                                      oldIndex,
                                    );
                                    _uploadedImageIds.insert(newIndex, item);
                                  });
                                },
                                children: [
                                  for (final imageId in _uploadedImageIds)
                                    Container(
                                      key: ValueKey(imageId),
                                      margin: const EdgeInsets.only(right: 12),
                                      child: FirestoreImageWidget(
                                        imageId: imageId,
                                        width: 150,
                                        height: 150,
                                        showDeleteButton: true,
                                        onDelete: () => _removeImage(imageId),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    if (attachments.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Attachments',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: ReorderableListView(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              onReorder: (oldIndex, newIndex) {
                                setState(() {
                                  if (newIndex > oldIndex) newIndex -= 1;
                                  final item = attachments.removeAt(oldIndex);
                                  attachments.insert(newIndex, item);
                                });
                              },
                              children: [
                                for (int i = 0; i < attachments.length; i++)
                                  Container(
                                    key: ValueKey(attachments[i]['path']),
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: ListTile(
                                      leading: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: Colors.blue[50],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          attachments[i]['type'] == 'image'
                                              ? Icons.image
                                              : Icons.attach_file,
                                          color: Colors.blue[600],
                                          size: 20,
                                        ),
                                      ),
                                      title: Text(
                                        attachments[i]['path'].split('/').last,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      subtitle: Text(
                                        attachments[i]['type'].toUpperCase(),
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.drag_handle,
                                            color: Colors.grey[400],
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                              size: 20,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                attachments.removeAt(i);
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                      onTap:
                                          () =>
                                            AttachmentManager.openFileAttachment(
                                              context,
                                              attachments[i],
                                            ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            NoteToolbar(
              taskCount: _tasks.length,
              onShowAttachmentOptions: showAttachmentOptions,
              onShowImagePicker: _showImagePicker,
            ),
          ],
        ),
      ),
    );
  }

  void _removeImage(String imageId) {
    setState(() {
      _uploadedImageIds.remove(imageId);
    });

    // Optionally, show a confirmation snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text('Image removed from note'),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 2),
      ),
    );

    // Optional: If you want to actually delete the image from Firestore/Storage
    // Uncomment the following line:
    // ImageHandler.deleteImage(imageId);
  }

  void _addTask(String taskTitle) {
    if (taskTitle.trim().isNotEmpty) {
      setState(() {
        _tasks.add(
          Task(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: taskTitle.trim(),
            isCompleted: false,
          ),
        );
      });
    }
  }

  void _toggleTask(int index) {
    setState(() {
      _tasks[index] = Task(
        id: _tasks[index].id,
        title: _tasks[index].title,
        isCompleted: !_tasks[index].isCompleted,
      );
    });
  }

  void _removeTask(int index) {
    setState(() {
      _tasks.removeAt(index);
    });
  }

  void _editTask(int index, String newTitle) {
    if (newTitle.trim().isNotEmpty) {
      setState(() {
        _tasks[index] = Task(
          id: _tasks[index].id,
          title: newTitle.trim(),
          isCompleted: _tasks[index].isCompleted,
        );
      });
    }
  }

  // Update the getSubjectColor method to fetch from Firestore for consistency:
  Future<Color> getClassColor(String subject) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return getSubjectColor(subject);

      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('Classes')
              .where('title', isEqualTo: subject)
              .limit(1)
              .get();

      if (snapshot.docs.isNotEmpty) {
        final classData = snapshot.docs.first.data();
        final colorValue = classData['color'] as int?;
        if (colorValue != null) {
          return Color(colorValue);
        }
      }

      return getSubjectColor(subject);
    } catch (e) {
      return getSubjectColor(subject);
    }
  }

  Color getSubjectColor(String subject) {
  if (subject.isEmpty) return Colors.blueGrey[400]!;

  final hash = subject.toLowerCase().hashCode;
  final colors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.indigo,
    Colors.pink,
    Colors.amber,
    Colors.cyan,
    Colors.deepOrange,
    Colors.lightGreen,
  ];
  return colors[hash.abs() % colors.length];
}

  void showSubjectSelection() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Select Subject',
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: subjectsLoading
            ? const Center(child: CircularProgressIndicator())
            : subjects.isEmpty
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.school_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No subjects found',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Create classes first to add subjects',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: subjects.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return ListTile(
                          leading: Icon(Icons.clear, color: Colors.grey[600]),
                          title: Text(
                            'No Subject',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          onTap: () {
                            setState(() {
                              selectedSubject = null;
                            });
                            Navigator.pop(context);
                          },
                        );
                      }
                      
                      final subject = subjects[index - 1];
                      final color = getSubjectColor(subject); // Now this method exists
                      
                      return ListTile(
                        leading: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(
                          subject,
                          style: GoogleFonts.inter(fontSize: 16),
                        ),
                        trailing: selectedSubject == subject
                            ? Icon(Icons.check, color: color)
                            : null,
                        onTap: () {
                          setState(() {
                            selectedSubject = subject;
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

void showAttachmentOptions() {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                'Add Attachment',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // File option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.attach_file,
                  color: Colors.purple[600],
                  size: 24,
                ),
              ),
              title: Text(
                'Attach File',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                'Select files from device storage',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('File picker not implemented yet'),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}

void _showImagePicker() {
  try {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(
                  'Add Image',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Gallery option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.photo_library,
                    color: Colors.blue[600],
                    size: 24,
                  ),
                ),
                title: Text(
                  'Choose from Gallery',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Gallery picker not implemented yet'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
              ),
              
              // Camera option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    color: Colors.green[600],
                    size: 24,
                  ),
                ),
                title: Text(
                  'Take Photo',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Camera not implemented yet'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  } catch (e) {
    print('Error showing image picker: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error opening image picker: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
}