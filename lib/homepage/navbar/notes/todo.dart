import 'package:flutter/material.dart';

// Todo Helper Class
class TodoHelper {
  static void insertTodoCircle(TextEditingController controller) {
    final text = controller.text;
    final selection = controller.selection;
    const todoCircle = '⬭ ';
    
    int start = selection.start;
    int end = selection.end;
    
    if (start < 0 || end < 0 || start > text.length || end > text.length) {
      start = text.length;
      end = text.length;
    }
    
    String prefix = '';
    if (start > 0 && text[start - 1] != '\n') {
      prefix = '\n';
    }
    
    final todoString = prefix + todoCircle;
    final newText = text.replaceRange(start, end, todoString);
    controller.text = newText;
    
    final newCursorPosition = start + todoString.length;
    controller.selection = TextSelection.collapsed(
      offset: newCursorPosition.clamp(0, newText.length),
    );
  }

  static void handleTextChange(TextEditingController controller, String value) {
    // Auto-format todos on text change
    final lines = value.split('\n');
    bool hasChanges = false;
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      // Auto-complete todo format
      if (line.startsWith('- ') && !line.startsWith('⬭ ') && !line.startsWith('✅ ')) {
        lines[i] = line.replaceFirst('- ', '⬭ ');
        hasChanges = true;
      }
      
      // Convert completed todos
      if (line.startsWith('⬭ ') && line.contains('[x]')) {
        lines[i] = line.replaceFirst('⬭ ', '✅ ').replaceFirst('[x]', '');
        hasChanges = true;
      }
    }
    
    if (hasChanges) {
      final newText = lines.join('\n');
      final currentPosition = controller.selection.baseOffset;
      controller.text = newText;
      controller.selection = TextSelection.collapsed(
        offset: currentPosition.clamp(0, newText.length),
      );
    }
  }

  static void toggleTodoCompletion(
    TextEditingController controller,
    TapDownDetails details,
    TextStyle style,
  ) {
    final text = controller.text;
    final lines = text.split('\n');
    
    // Calculate which line was tapped
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    final position = textPainter.getPositionForOffset(details.localPosition);
    final lineIndex = text.substring(0, position.offset).split('\n').length - 1;
    
    if (lineIndex < lines.length) {
      final line = lines[lineIndex];
      
      // Toggle todo completion
      if (line.startsWith('⬭ ')) {
        lines[lineIndex] = line.replaceFirst('⬭ ', '✅ ');
      } else if (line.startsWith('✅ ')) {
        lines[lineIndex] = line.replaceFirst('✅ ', '⬭ ');
      }
      
      controller.text = lines.join('\n');
    }
  }

  static List<String> extractTodos(String text) {
    final lines = text.split('\n');
    final todos = <String>[];
    
    for (final line in lines) {
      if (line.startsWith('⬭ ') || line.startsWith('✅ ')) {
        todos.add(line);
      }
    }
    
    return todos;
  }

  static int getCompletedTodoCount(String text) {
    final todos = extractTodos(text);
    return todos.where((todo) => todo.startsWith('✅ ')).length;
  }

  static int getTotalTodoCount(String text) {
    return extractTodos(text).length;
  }
}

// Todo Toolbar Widget
class TodoToolbar extends StatelessWidget {
  final VoidCallback onInsertTodo;

  const TodoToolbar({
    super.key,
    required this.onInsertTodo,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.checklist, color: Colors.black, size: 28),
      onPressed: onInsertTodo,
      tooltip: 'Add Todo',
    );
  }
}

// Todo Statistics Widget
class TodoStatistics extends StatelessWidget {
  final String text;

  const TodoStatistics({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final completed = TodoHelper.getCompletedTodoCount(text);
    final total = TodoHelper.getTotalTodoCount(text);
    
    if (total == 0) return const SizedBox.shrink();
    
    final percentage = (completed / total * 100).round();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.checklist,
            size: 16,
            color: Colors.green[700],
          ),
          const SizedBox(width: 4),
          Text(
            '$completed/$total ($percentage%)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.green[700],
            ),
          ),
        ],
      ),
    );
  }
}