import 'package:flutter/material.dart';

class ClassModel {
  String title;
  String time;
  String location;
  String teacher;
  String notes;
  Color color; // New field for card color

  ClassModel({
    required this.title,
    required this.time,
    required this.location,
    required this.teacher,
    this.notes = '',
    this.color = Colors.orangeAccent, // Default color
  });
}

class ExpandableClassCard extends StatefulWidget {
  final ClassModel classModel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ExpandableClassCard({
    super.key,
    required this.classModel,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<ExpandableClassCard> createState() => _ExpandableClassCardState();
}

class _ExpandableClassCardState extends State<ExpandableClassCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: widget.classModel.color, // Use the color from the model
          borderRadius: BorderRadius.circular(20),
          boxShadow: _isExpanded
              ? [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.classModel.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: widget.onEdit,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final shouldDelete = await showDialog<bool>(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('Confirm Delete'),
                              content: const Text('Are you sure you want to delete this class?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false), // Cancel
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.of(context).pop(true), // Confirm
                                  child: const Text('Delete'),
                                ),
                              ],
                            );
                          },
                        );

                        if (shouldDelete == true) {
                          widget.onDelete(); // Call the delete callback
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.classModel.time,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              widget.classModel.teacher,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              widget.classModel.location,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            if (_isExpanded) ...[
              const SizedBox(height: 16),
              const Divider(color: Colors.white54),

              const SizedBox(height: 8),
              Text(
                "Notes: ${widget.classModel.notes}", // Display notes
                style: const TextStyle(color: Color.fromARGB(179, 255, 255, 255)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}