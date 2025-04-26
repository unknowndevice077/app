import 'package:flutter/material.dart';
import 'classes.dart';

class ClassFormDialog extends StatefulWidget {
  final ClassModel? existing;

  const ClassFormDialog({super.key, this.existing});

  @override
  State<ClassFormDialog> createState() => _ClassFormDialogState();
}

class _ClassFormDialogState extends State<ClassFormDialog> {
  late TextEditingController _titleController;
  late TextEditingController _timeController;
  late TextEditingController _locationController;
  late TextEditingController _teacherController;
  late TextEditingController _notesController; // Controller for notes
  late Color _selectedColor; // Controller for the selected color

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existing?.title ?? '');
    _timeController = TextEditingController(text: widget.existing?.time ?? '');
    _locationController = TextEditingController(text: widget.existing?.location ?? '');
    _teacherController = TextEditingController(text: widget.existing?.teacher ?? '');
    _notesController = TextEditingController(text: widget.existing?.notes ?? ''); // Initialize notes
    _selectedColor = widget.existing?.color ?? Colors.orangeAccent; // Initialize color
  }

  void _submit() {
    final newClass = ClassModel(
      title: _titleController.text,
      time: _timeController.text,
      location: _locationController.text,
      teacher: _teacherController.text,
      notes: _notesController.text, // Include notes
      color: _selectedColor, // Pass the selected color
    );
    Navigator.of(context).pop(newClass);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Class' : 'Edit Class'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Subject')),
            TextField(controller: _timeController, decoration: const InputDecoration(labelText: 'Time')),
            TextField(controller: _locationController, decoration: const InputDecoration(labelText: 'Room')),
            TextField(controller: _teacherController, decoration: const InputDecoration(labelText: 'Teacher')),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes'), // New TextField for notes
              maxLines: 3, // Allow multiple lines for notes
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Card Color:'),
                DropdownButton<Color>(
                  value: _selectedColor,
                  items: [
                    {'color': Colors.orangeAccent, 'name': 'Orange'},
                    {'color': Colors.blueAccent, 'name': 'Blue'},
                    {'color': Colors.greenAccent, 'name': 'Green'},
                    {'color': Colors.purpleAccent, 'name': 'Purple'},
                    {'color': Colors.redAccent, 'name': 'Red'},
                  ].map((entry) {
                    return DropdownMenuItem<Color>(
                      value: entry['color'] as Color,
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            color: entry['color'] as Color,
                          ),
                          const SizedBox(width: 8),
                          Text(entry['name'] as String), // Display the color name
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (color) {
                    setState(() {
                      _selectedColor = color!;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
