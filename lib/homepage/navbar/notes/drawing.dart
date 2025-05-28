import 'package:flutter/material.dart';

// Drawing Point class
class DrawingPoint {
  final Offset? offset;
  final Color color;
  final double strokeWidth;
  final bool isEraser;

  DrawingPoint({
    this.offset,
    required this.color,
    required this.strokeWidth,
    required this.isEraser,
  });
}

// Drawing Painter class
class DrawingPainter extends CustomPainter {
  final List<DrawingPoint> points;

  DrawingPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i].offset != null && points[i + 1].offset != null) {
        Paint paint = Paint()
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

        if (points[i].isEraser) {
          paint
            ..color = Colors.white
            ..strokeWidth = points[i].strokeWidth * 2;
        } else {
          paint
            ..color = points[i].color
            ..strokeWidth = points[i].strokeWidth;
        }

        canvas.drawLine(points[i].offset!, points[i + 1].offset!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

// Drawing Toolbar Widget
class DrawingToolbar extends StatelessWidget {
  final Color selectedColor;
  final bool isErasing;
  final double strokeWidth;
  final bool showColorPalette;
  final bool showBrushSizes;
  final VoidCallback onToggleColorPalette;
  final VoidCallback onToggleBrushSizes;
  final VoidCallback onToggleEraser;
  final VoidCallback onClearDrawing;

  const DrawingToolbar({
    super.key,
    required this.selectedColor,
    required this.isErasing,
    required this.strokeWidth,
    required this.showColorPalette,
    required this.showBrushSizes,
    required this.onToggleColorPalette,
    required this.onToggleBrushSizes,
    required this.onToggleEraser,
    required this.onClearDrawing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: Icon(Icons.palette, color: selectedColor),
          onPressed: onToggleColorPalette,
          tooltip: 'Color Palette',
        ),
        IconButton(
          icon: const Icon(Icons.brush, color: Colors.black),
          onPressed: onToggleBrushSizes,
          tooltip: 'Brush Size',
        ),
        IconButton(
          icon: Icon(
            Icons.auto_fix_normal, 
            color: isErasing ? Colors.pink : Colors.grey,
          ),
          onPressed: onToggleEraser,
          tooltip: isErasing ? 'Stop Erasing' : 'Eraser',
        ),
        IconButton(
          icon: const Icon(Icons.clear, color: Colors.red),
          onPressed: onClearDrawing,
          tooltip: 'Clear Drawing',
        ),
      ],
    );
  }
}

// Color Palette Widget
class ColorPalette extends StatelessWidget {
  final List<Color> colors;
  final Color selectedColor;
  final bool isErasing;
  final ValueChanged<Color> onColorSelected;

  const ColorPalette({
    super.key,
    required this.colors,
    required this.selectedColor,
    required this.isErasing,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: colors.map((color) {
        final isSelected = selectedColor == color && !isErasing;
        return GestureDetector(
          onTap: () => onColorSelected(color),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.grey,
                width: isSelected ? 3 : 1,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ] : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// Brush Size Selector Widget
class BrushSizeSelector extends StatelessWidget {
  final List<double> brushSizes;
  final double selectedSize;
  final ValueChanged<double> onSizeSelected;

  const BrushSizeSelector({
    super.key,
    required this.brushSizes,
    required this.selectedSize,
    required this.onSizeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: brushSizes.map((size) {
        final isSelected = selectedSize == size;
        return GestureDetector(
          onTap: () => onSizeSelected(size),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.grey,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Center(
              child: Container(
                width: size.clamp(2, 16),
                height: size.clamp(2, 16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(size.clamp(2, 16)),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// Drawing Helper Class
class DrawingHelper {
  static List<Color> getDefaultColors() {
    return [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.black,
      Colors.brown,
      Colors.pink,
      Colors.teal,
      Colors.indigo,
      Colors.grey,
      Colors.cyan,
      Colors.amber,
      Colors.lime,
      Colors.deepOrange,
    ];
  }

  static List<double> getDefaultBrushSizes() {
    return [1.0, 3.0, 5.0, 8.0, 12.0, 16.0];
  }

  static void saveToHistory(
    List<List<DrawingPoint>> history,
    List<DrawingPoint> currentPoints,
    int historyIndex,
    Function(List<List<DrawingPoint>>, int) onHistoryUpdate,
  ) {
    // Remove any history after current index if we're not at the end
    if (historyIndex < history.length - 1) {
      history.removeRange(historyIndex + 1, history.length);
    }
    
    // Add current state to history
    history.add(List<DrawingPoint>.from(currentPoints));
    int newHistoryIndex = history.length - 1;
    
    // Limit history size to prevent memory issues
    if (history.length > 50) {
      history.removeAt(0);
      newHistoryIndex--;
    }
    
    onHistoryUpdate(history, newHistoryIndex);
  }
}