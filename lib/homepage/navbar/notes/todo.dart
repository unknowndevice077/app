import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TodoTask {
  final String id;
  String text;
  bool isCompleted;
  final DateTime createdAt;
  bool isEditing;

  TodoTask({
    required this.id,
    required this.text,
    required this.isCompleted,
    required this.createdAt,
    this.isEditing = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'isCompleted': isCompleted,
      'createdAt': createdAt,
      'updatedAt': DateTime.now(),
    };
  }

  static TodoTask fromMap(Map<String, dynamic> map) {
    return TodoTask(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      text: map['text'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      isEditing: false,
    );
  }
}

class TodoManager extends StatefulWidget {
  final VoidCallback? onTodoSaved;

  const TodoManager({
    super.key,
    this.onTodoSaved,
  });

  @override
  State<TodoManager> createState() => _TodoManagerState();
}

class _TodoManagerState extends State<TodoManager> {
  List<TodoTask> _todoTasks = [];
  final TextEditingController _todoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTodoTasks();
  }

  @override
  void dispose() {
    _todoController.dispose();
    super.dispose();
  }

  Future<void> _loadTodoTasks() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('TodoTasks')
          .orderBy('createdAt', descending: true)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          _todoTasks = querySnapshot.docs
              .map((doc) => TodoTask.fromMap(doc.data()))
              .toList();
        });
      }
    } catch (e) {
      print('Error loading todo tasks: $e');
    }
  }

  Future<void> _createTodoTask(String taskText) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final now = DateTime.now();

      final newTask = TodoTask(
        id: now.millisecondsSinceEpoch.toString(),
        text: taskText.trim(),
        isCompleted: false,
        createdAt: now,
        isEditing: false,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('TodoTasks')
          .doc(newTask.id)
          .set(newTask.toMap());

      setState(() {
        _todoTasks.insert(0, newTask);
      });

    
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating todo: $e'),
            backgroundColor: const Color(0xFFE53E3E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _addTodoTask(String taskText) {
    if (taskText.trim().isNotEmpty) {
      _createTodoTask(taskText);
      _todoController.clear();
    }
  }

  Future<void> _updateTodoTask(TodoTask task) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('TodoTasks')
          .doc(task.id)
          .update({
        'text': task.text,
        'isCompleted': task.isCompleted,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating todo task: $e');
    }
  }

  void _toggleTodoTask(int index) {
    setState(() {
      _todoTasks[index].isCompleted = !_todoTasks[index].isCompleted;
    });
    _updateTodoTask(_todoTasks[index]);
  }

  Future<void> _deleteTodoTask(String taskId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('TodoTasks')
          .doc(taskId)
          .delete();
    } catch (e) {
      print('Error deleting todo task: $e');
    }
  }

  void _removeTodoTask(int index) {
    final task = _todoTasks[index];
    setState(() {
      _todoTasks.removeAt(index);
    });
    _deleteTodoTask(task.id);
  }

  void _clearCompletedTasks() async {
    final completedTasks = _todoTasks.where((task) => task.isCompleted).toList();
    setState(() {
      _todoTasks.removeWhere((task) => task.isCompleted);
    });
    for (final task in completedTasks) {
      _deleteTodoTask(task.id);
    }
  }

  int get _completedCount => _todoTasks.where((task) => task.isCompleted).length;
  int get _totalCount => _todoTasks.length;
  double get _progressPercentage => _totalCount == 0 ? 0.0 : _completedCount / _totalCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 400;
    final isVerySmallScreen = size.width < 350;
    
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
              ? [const Color(0xFF1A1A1A), const Color(0xFF2D2D2D)]
              : [const Color(0xFFF8FAFC), const Color(0xFFFFFFFF)],
          ),
        ),
        child: Column(
          children: [
            // ✅ Responsive Header with Progress
            Container(
              margin: EdgeInsets.all(isVerySmallScreen ? 12 : (isSmallScreen ? 16 : 20)),
              padding: EdgeInsets.all(isVerySmallScreen ? 16 : (isSmallScreen ? 20 : 24)),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                    blurRadius: isSmallScreen ? 15 : 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isVerySmallScreen ? 8 : 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                          ),
                          borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
                        ),
                        child: Icon(
                          Icons.checklist,
                          color: Colors.white,
                          size: isVerySmallScreen ? 20 : 24,
                        ),
                      ),
                      SizedBox(width: isVerySmallScreen ? 12 : 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Today\'s To-Do',
                              style: GoogleFonts.inter(
                                fontSize: isVerySmallScreen ? 16 : (isSmallScreen ? 18 : 20),
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF1A202C),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: isVerySmallScreen ? 2 : 4),
                            Text(
                              '$_completedCount of $_totalCount completed',
                              style: GoogleFonts.inter(
                                fontSize: isVerySmallScreen ? 12 : 14,
                                color: isDark ? Colors.grey[400] : const Color(0xFF718096),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (_totalCount > 0)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isVerySmallScreen ? 8 : 12,
                            vertical: isVerySmallScreen ? 4 : 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF48BB78).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
                          ),
                          child: Text(
                            '${(_progressPercentage * 100).toInt()}%',
                            style: GoogleFonts.inter(
                              fontSize: isVerySmallScreen ? 10 : 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF48BB78),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (_totalCount > 0) ...[
                    SizedBox(height: isVerySmallScreen ? 12 : 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _progressPercentage,
                        backgroundColor: isDark ? Colors.grey[700] : const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF667EEA)),
                        minHeight: isVerySmallScreen ? 6 : 8,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ✅ Responsive Input Section
            Container(
              margin: EdgeInsets.symmetric(horizontal: isVerySmallScreen ? 12 : (isSmallScreen ? 16 : 20)),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                    blurRadius: isSmallScreen ? 8 : 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TodoInput(
                controller: _todoController,
                onTaskCreated: _addTodoTask,
                isDark: isDark,
                isSmallScreen: isSmallScreen,
                isVerySmallScreen: isVerySmallScreen,
              ),
            ),

            SizedBox(height: isVerySmallScreen ? 12 : 20),

            // ✅ Responsive Todo List
            Expanded(
              child: _todoTasks.isEmpty
                  ? _buildEmptyState(isDark, isSmallScreen, isVerySmallScreen)
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: isVerySmallScreen ? 12 : (isSmallScreen ? 16 : 20)),
                      itemCount: _todoTasks.length,
                      itemBuilder: (context, index) {
                        final task = _todoTasks[index];
                        return TodoTile(
                          task: task,
                          index: index,
                          onToggle: () => _toggleTodoTask(index),
                          onDelete: () => _removeTodoTask(index),
                          onEdit: (newText) {
                            setState(() {
                              task.text = newText;
                              task.isEditing = false;
                            });
                            _updateTodoTask(task);
                          },
                          isDark: isDark,
                          isSmallScreen: isSmallScreen,
                          isVerySmallScreen: isVerySmallScreen,
                        );
                      },
                    ),
            ),

            // ✅ Responsive Bottom Actions
            if (_todoTasks.any((task) => task.isCompleted))
              Container(
                margin: EdgeInsets.all(isVerySmallScreen ? 12 : (isSmallScreen ? 16 : 20)),
                child: ElevatedButton.icon(
                  onPressed: _clearCompletedTasks,
                  icon: Icon(Icons.cleaning_services, size: isVerySmallScreen ? 16 : 18),
                  label: Text(
                    'Clear Completed',
                    style: TextStyle(fontSize: isVerySmallScreen ? 13 : 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53E3E),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isVerySmallScreen ? 16 : 24,
                      vertical: isVerySmallScreen ? 8 : 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, bool isSmallScreen, bool isVerySmallScreen) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isVerySmallScreen ? 16 : 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isVerySmallScreen ? 24 : 32),
              decoration: BoxDecoration(
                color: const Color(0xFF667EEA).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.checklist,
                size: isVerySmallScreen ? 48 : 64,
                color: const Color(0xFF667EEA),
              ),
            ),
            SizedBox(height: isVerySmallScreen ? 16 : 24),
            Text(
              'No todos yet',
              style: GoogleFonts.inter(
                fontSize: isVerySmallScreen ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1A202C),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isVerySmallScreen ? 4 : 8),
            Text(
              'Add your first todo to get started',
              style: GoogleFonts.inter(
                fontSize: isVerySmallScreen ? 14 : 16,
                color: isDark ? Colors.grey[400] : const Color(0xFF718096),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Todo Input Widget
class TodoInput extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onTaskCreated;
  final bool isDark;
  final bool isSmallScreen;
  final bool isVerySmallScreen;

  const TodoInput({
    super.key,
    required this.controller,
    required this.onTaskCreated,
    required this.isDark,
    this.isSmallScreen = false,
    this.isVerySmallScreen = false,
  });

  @override
  State<TodoInput> createState() => _TodoInputState();
}

class _TodoInputState extends State<TodoInput> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _submitTask() {
    final taskText = widget.controller.text.trim();
    if (taskText.isNotEmpty) {
      widget.onTaskCreated(taskText);
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(widget.isVerySmallScreen ? 6 : 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(widget.isVerySmallScreen ? 6 : 8),
            child: Icon(
              Icons.add_circle_outline,
              color: _isFocused ? const Color(0xFF667EEA) : Colors.grey[400],
              size: widget.isVerySmallScreen ? 20 : 24,
            ),
          ),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              style: GoogleFonts.inter(
                fontSize: widget.isVerySmallScreen ? 14 : 16,
                color: widget.isDark ? Colors.white : const Color(0xFF1A202C),
              ),
              decoration: InputDecoration(
                hintText: 'Add a new todo...',
                hintStyle: GoogleFonts.inter(
                  color: Colors.grey[400],
                  fontSize: widget.isVerySmallScreen ? 14 : 16,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  vertical: widget.isVerySmallScreen ? 8 : 12,
                ),
              ),
              onSubmitted: (_) => _submitTask(),
              textInputAction: TextInputAction.done,
              maxLines: 1,
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: IconButton(
              onPressed: _submitTask,
              icon: Container(
                padding: EdgeInsets.all(widget.isVerySmallScreen ? 6 : 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  ),
                  borderRadius: BorderRadius.circular(widget.isSmallScreen ? 10 : 12),
                ),
                child: Icon(
                  Icons.arrow_upward,
                  color: Colors.white,
                  size: widget.isVerySmallScreen ? 16 : 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Todo Tile Widget
class TodoTile extends StatefulWidget {
  final TodoTask task;
  final int index;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final Function(String) onEdit;
  final bool isDark;
  final bool isSmallScreen;
  final bool isVerySmallScreen;

  const TodoTile({
    super.key,
    required this.task,
    required this.index,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
    required this.isDark,
    this.isSmallScreen = false,
    this.isVerySmallScreen = false,
  });

  @override
  State<TodoTile> createState() => _TodoTileState();
}

class _TodoTileState extends State<TodoTile> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isEditing = false;
  late TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _editController = TextEditingController(text: widget.task.text);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            margin: EdgeInsets.only(bottom: widget.isVerySmallScreen ? 8 : 12),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF2D2D2D) : Colors.white,
              borderRadius: BorderRadius.circular(widget.isSmallScreen ? 12 : 16),
              border: Border.all(
                color: widget.task.isCompleted 
                    ? const Color(0xFF48BB78).withOpacity(0.3)
                    : Colors.transparent,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(widget.isDark ? 0.2 : 0.05),
                  blurRadius: widget.isSmallScreen ? 8 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(widget.isSmallScreen ? 12 : 16),
                onTap: () {
                  _animationController.forward().then((_) {
                    _animationController.reverse();
                  });
                },
                child: Padding(
                  padding: EdgeInsets.all(widget.isVerySmallScreen ? 12 : 16),
                  child: Row(
                    children: [
                      // ✅ Responsive Custom Checkbox
                      GestureDetector(
                        onTap: widget.onToggle,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: widget.isVerySmallScreen ? 20 : 24,
                          height: widget.isVerySmallScreen ? 20 : 24,
                          decoration: BoxDecoration(
                            color: widget.task.isCompleted 
                                ? const Color(0xFF48BB78)
                                : Colors.transparent,
                            border: Border.all(
                              color: widget.task.isCompleted 
                                  ? const Color(0xFF48BB78)
                                  : Colors.grey[400]!,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: widget.task.isCompleted
                              ? Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: widget.isVerySmallScreen ? 12 : 16,
                                )
                              : null,
                        ),
                      ),
                      SizedBox(width: widget.isVerySmallScreen ? 12 : 16),
                      
                      // ✅ Responsive Todo Text with Overflow Protection
                      Expanded(
                        child: _isEditing
                            ? TextField(
                                controller: _editController,
                                style: GoogleFonts.inter(
                                  fontSize: widget.isVerySmallScreen ? 14 : 16,
                                  color: widget.isDark ? Colors.white : const Color(0xFF1A202C),
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onSubmitted: (value) {
                                  setState(() {
                                    _isEditing = false;
                                  });
                                  widget.onEdit(value);
                                },
                                autofocus: true,
                                maxLines: null,
                              )
                            : GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isEditing = true;
                                  });
                                },
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: GoogleFonts.inter(
                                    fontSize: widget.isVerySmallScreen ? 14 : 16,
                                    color: widget.task.isCompleted 
                                        ? Colors.grey[500]
                                        : (widget.isDark ? Colors.white : const Color(0xFF1A202C)),
                                    decoration: widget.task.isCompleted 
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                  ),
                                  child: Text(
                                    widget.task.text.isEmpty ? 'Tap to edit...' : widget.task.text,
                                    maxLines: widget.isVerySmallScreen ? 2 : 3,
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: true,
                                  ),
                                ),
                              ),
                      ),
                      
                      // ✅ Responsive Delete Button
                      IconButton(
                        onPressed: widget.onDelete,
                        icon: Icon(
                          Icons.delete_outline,
                          color: const Color(0xFFE53E3E).withOpacity(0.7),
                          size: widget.isVerySmallScreen ? 18 : 20,
                        ),
                        padding: EdgeInsets.all(widget.isVerySmallScreen ? 4 : 8),
                        constraints: BoxConstraints(
                          minWidth: widget.isVerySmallScreen ? 32 : 40,
                          minHeight: widget.isVerySmallScreen ? 32 : 40,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}