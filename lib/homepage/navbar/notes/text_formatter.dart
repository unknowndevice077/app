import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

// Upper Case Text Formatter
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

// Text Formatting Helper
class TextFormattingHelper {
  static void insertBulletPoint(TextEditingController controller) {
    final text = controller.text;
    final selection = controller.selection;
    const bullet = '• ';
    
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
    
    final bulletString = prefix + bullet;
    final newText = text.replaceRange(start, end, bulletString);
    controller.text = newText;
    
    final newCursorPosition = start + bulletString.length;
    controller.selection = TextSelection.collapsed(
      offset: newCursorPosition.clamp(0, newText.length),
    );
  }

  static void insertNumberedList(TextEditingController controller) {
    final text = controller.text;
    final selection = controller.selection;
    
    int start = selection.start;
    int end = selection.end;
    
    if (start < 0 || end < 0 || start > text.length || end > text.length) {
      start = text.length;
      end = text.length;
    }
    
    // Count existing numbered items
    final lines = text.split('\n');
    int numberCount = 1;
    for (final line in lines) {
      if (RegExp(r'^\d+\.\s').hasMatch(line)) {
        numberCount++;
      }
    }
    
    String prefix = '';
    if (start > 0 && text[start - 1] != '\n') {
      prefix = '\n';
    }
    
    final numberedString = '$prefix$numberCount. ';
    final newText = text.replaceRange(start, end, numberedString);
    controller.text = newText;
    
    final newCursorPosition = start + numberedString.length;
    controller.selection = TextSelection.collapsed(
      offset: newCursorPosition.clamp(0, newText.length),
    );
  }

  static void formatSelectedText(
    TextEditingController controller,
    String startTag,
    String endTag,
  ) {
    final text = controller.text;
    final selection = controller.selection;
    
    if (selection.start == selection.end) return;
    
    final selectedText = text.substring(selection.start, selection.end);
    final formattedText = '$startTag$selectedText$endTag';
    
    final newText = text.replaceRange(selection.start, selection.end, formattedText);
    controller.text = newText;
    
    controller.selection = TextSelection(
      baseOffset: selection.start + startTag.length,
      extentOffset: selection.start + startTag.length + selectedText.length,
    );
  }

  static void makeBold(TextEditingController controller) {
    formatSelectedText(controller, '**', '**');
  }

  static void makeItalic(TextEditingController controller) {
    formatSelectedText(controller, '*', '*');
  }

  static void makeUnderline(TextEditingController controller) {
    formatSelectedText(controller, '_', '_');
  }

  static void insertHorizontalLine(TextEditingController controller) {
    final text = controller.text;
    final selection = controller.selection;
    
    int start = selection.start;
    if (start < 0 || start > text.length) {
      start = text.length;
    }
    
    String prefix = '';
    String suffix = '';
    
    if (start > 0 && text[start - 1] != '\n') {
      prefix = '\n';
    }
    if (start < text.length && text[start] != '\n') {
      suffix = '\n';
    }
    
    final lineString = '$prefix---$suffix';
    final newText = text.replaceRange(start, start, lineString);
    controller.text = newText;
    
    final newCursorPosition = start + lineString.length;
    controller.selection = TextSelection.collapsed(
      offset: newCursorPosition.clamp(0, newText.length),
    );
  }

  static int getWordCount(String text) {
    if (text.isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  static int getCharacterCount(String text) {
    return text.length;
  }

  static int getParagraphCount(String text) {
    if (text.isEmpty) return 0;
    return text.split('\n').where((line) => line.trim().isNotEmpty).length;
  }
}

// Text Statistics Widget
class TextStatistics extends StatelessWidget {
  final String text;

  const TextStatistics({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final wordCount = TextFormattingHelper.getWordCount(text);
    final charCount = TextFormattingHelper.getCharacterCount(text);
    final paragraphCount = TextFormattingHelper.getParagraphCount(text);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.text_fields,
            size: 16,
            color: Colors.blue[700],
          ),
          const SizedBox(width: 4),
          Text(
            '$wordCount words • $charCount chars • $paragraphCount ¶',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }
}

// Text Formatting Toolbar
class TextFormattingToolbar extends StatelessWidget {
  final TextEditingController controller;

  const TextFormattingToolbar({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: const Icon(Icons.format_bold, size: 20),
          onPressed: () => TextFormattingHelper.makeBold(controller),
          tooltip: 'Bold',
        ),
        IconButton(
          icon: const Icon(Icons.format_italic, size: 20),
          onPressed: () => TextFormattingHelper.makeItalic(controller),
          tooltip: 'Italic',
        ),
        IconButton(
          icon: const Icon(Icons.format_underlined, size: 20),
          onPressed: () => TextFormattingHelper.makeUnderline(controller),
          tooltip: 'Underline',
        ),
        IconButton(
          icon: const Icon(Icons.format_list_bulleted, size: 20),
          onPressed: () => TextFormattingHelper.insertBulletPoint(controller),
          tooltip: 'Bullet List',
        ),
        IconButton(
          icon: const Icon(Icons.format_list_numbered, size: 20),
          onPressed: () => TextFormattingHelper.insertNumberedList(controller),
          tooltip: 'Numbered List',
        ),
        IconButton(
          icon: const Icon(Icons.horizontal_rule, size: 20),
          onPressed: () => TextFormattingHelper.insertHorizontalLine(controller),
          tooltip: 'Horizontal Line',
        ),
      ],
    );
  }
}