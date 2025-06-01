import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Task {
  final String id;
  final String title;
  final bool isCompleted;

  Task({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  Task copyWith({
    String? id,
    String? title,
    bool? isCompleted,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: map['title'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
    );
  }
}

// ✅ TASKITEM CLASS FOR UI REPRESENTATION
class TaskItem {
  String text;
  bool isDone;

  TaskItem({
    required this.text,
    this.isDone = false,
  });

  // Convert TaskItem to Task
  Task toTask() {
    return Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: text,
      isCompleted: isDone,
    );
  }

  // Create TaskItem from Task
  static TaskItem fromTask(Task task) {
    return TaskItem(
      text: task.title,
      isDone: task.isCompleted,
    );
  }

  TaskItem copyWith({String? text, bool? isDone}) {
    return TaskItem(
      text: text ?? this.text,
      isDone: isDone ?? this.isDone,
    );
  }
}

// ✅ COMPLETE TASK LIST CONTAINER WIDGET
class TaskListContainer extends StatefulWidget {
  final List<TaskItem> tasks;
  final Function(List<TaskItem>) onChanged;

  const TaskListContainer({
    super.key,
    required this.tasks,
    required this.onChanged,
  });

  @override
  State<TaskListContainer> createState() => TaskListContainerState();
}

class TaskListContainerState extends State<TaskListContainer> {
  List<TextEditingController> _controllers = [];
  List<FocusNode> _focusNodes = [];
  final bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _syncControllersWithTasks();
  }

  @override
  void didUpdateWidget(covariant TaskListContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tasks != widget.tasks) {
      _syncControllersWithTasks();
    }
  }

  void _syncControllersWithTasks() {
    // Dispose old controllers
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }

    // Create new controllers
    _controllers = widget.tasks.map((task) {
      return TextEditingController(text: task.text);
    }).toList();
    
    _focusNodes = widget.tasks.map((task) => FocusNode()).toList();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _toggleTask(int index) {
    if (index >= widget.tasks.length) return;
    
    final newTasks = List<TaskItem>.from(widget.tasks);
    newTasks[index].isDone = !newTasks[index].isDone;
    widget.onChanged(newTasks);
    setState(() {});
  }

  void _removeTask(int index) {
    if (index >= widget.tasks.length) return;
    
    final newTasks = List<TaskItem>.from(widget.tasks);
    newTasks.removeAt(index);
    widget.onChanged(newTasks);
  }

  void addEmptyTask() {
    final newTasks = List<TaskItem>.from(widget.tasks);
    newTasks.add(TaskItem(text: ''));
    widget.onChanged(newTasks);
  }

  @override
  Widget build(BuildContext context) {
    // ✅ ALWAYS ENSURE THERE'S AN EMPTY TASK AT THE END FOR NEW INPUT
    final tasks = List<TaskItem>.from(widget.tasks);
    if (tasks.isEmpty || tasks.last.text.trim().isNotEmpty) {
      tasks.add(TaskItem(text: '', isDone: false));
    }
    
    // ✅ ENSURE CONTROLLERS/FOCUSNODES MATCH TASKS LENGTH
    while (_controllers.length < tasks.length) {
      _controllers.add(TextEditingController());
      _focusNodes.add(FocusNode());
    }
    while (_controllers.length > tasks.length) {
      _controllers.removeLast().dispose();
      _focusNodes.removeLast().dispose();
    }
    
    // Update controller texts
    for (int i = 0; i < tasks.length; i++) {
      if (_controllers[i].text != tasks[i].text) {
        _controllers[i].text = tasks[i].text;
        _controllers[i].selection = TextSelection.collapsed(offset: _controllers[i].text.length);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            final controller = _controllers[index];
            final focusNode = _focusNodes[index];

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                // ✅ ONLY SHOW LEADING ICON IF TASK IS DONE OR HAS TEXT
                leading: task.isDone
                    ? IconButton(
                        icon: Icon(
                          Icons.check_circle,
                          color: Colors.green[600],
                          size: 26,
                        ),
                        onPressed: () => _toggleTask(index),
                      )
                    : (task.text.trim().isNotEmpty)
                        ? IconButton(
                            icon: Icon(
                              Icons.radio_button_unchecked,
                              color: Colors.grey[400],
                              size: 26,
                            ),
                            onPressed: () => _toggleTask(index),
                          )
                        : null, // ✅ NO ICON FOR EMPTY TASKS
                title: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: GoogleFonts.inter(
                    decoration: task.isDone ? TextDecoration.lineThrough : null,
                    color: task.isDone ? Colors.grey[500] : Colors.black87,
                    fontSize: 17,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onSubmitted: (newText) {
                    final trimmed = newText.trim();
                    if (trimmed.isNotEmpty) {
                      // ✅ UPDATE CURRENT TASK
                      final newTasks = List<TaskItem>.from(widget.tasks);
                      
                      // If this is the last (empty) task, add it to the real list
                      if (index >= newTasks.length) {
                        newTasks.add(TaskItem(text: trimmed, isDone: false));
                      } else {
                        newTasks[index].text = trimmed;
                      }
                      
                      widget.onChanged(newTasks);
                      
                      // ✅ FOCUS THE NEW FIELD
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_focusNodes.length > index + 1) {
                          _focusNodes[index + 1].requestFocus();
                        }
                      });
                    }
                  },
                  onChanged: (value) {
                    // ✅ UPDATE TASKS IN REAL TIME, BUT ONLY FOR EXISTING TASKS
                    if (index < widget.tasks.length) {
                      final newTasks = List<TaskItem>.from(widget.tasks);
                      newTasks[index].text = value;
                      widget.onChanged(newTasks);
                    }
                    // For the last empty task, we don't update the main list until submitted
                  },
                  autofocus: task.text.isEmpty && index == tasks.length - 1,
                ),
                trailing: _isEditMode && task.text.isNotEmpty && index < widget.tasks.length
                    ? IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeTask(index),
                      )
                    : null,
              ),
            );
          },
        ),
      ],
    );
  }
}