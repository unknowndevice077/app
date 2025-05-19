import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

// --- Class Model ---
class ClassModel {
  String title;
  String time;
  String location;
  String teacher;
  String notes;
  Color color;

  ClassModel({
    required this.title,
    required this.time,
    required this.location,
    required this.teacher,
    this.notes = '',
    this.color = const Color.fromARGB(255, 255, 255, 255),
  });
}

// --- Expandable Class Card ---
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
          color: widget.classModel.color,
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
                      icon: const Icon(Icons.edit, color: Color.fromARGB(255, 0, 0, 0)),
                      onPressed: widget.onEdit,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Color.fromARGB(255, 0, 0, 0)),
                      onPressed: () async {
                        final shouldDelete = await showDialog<bool>(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('Confirm Delete'),
                              content: const Text('Are you sure you want to delete this class?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            );
                          },
                        );
                        if (shouldDelete == true) {
                          widget.onDelete();
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
                "Notes: ${widget.classModel.notes}",
                style: const TextStyle(color: Color.fromARGB(179, 255, 255, 255)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// --- Classes Page ---
class Classes extends StatefulWidget {
  const Classes({super.key});

  @override
  State<Classes> createState() => _ClassesState();
}

class _ClassesState extends State<Classes> {
  void _addOrEditClass({ClassModel? existing, String? docId}) async {
    final result = await showDialog<ClassModel>(
      context: context,
      builder: (_) => ClassFormDialog(existing: existing),
    );

    if (result != null) {
      if (docId != null) {
        await FirebaseFirestore.instance.collection('Classes').doc(docId).update({
          'title': result.title,
          'time': result.time,
          'location': result.location,
          'teacher': result.teacher,
          'notes': result.notes,
          'color': result.color.value,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await FirebaseFirestore.instance.collection('Classes').add({
          'title': result.title,
          'time': result.time,
          'location': result.location,
          'teacher': result.teacher,
          'notes': result.notes,
          'color': result.color.value,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  void _deleteClass(String docId) async {
    await FirebaseFirestore.instance.collection('Classes').doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Classes', style: GoogleFonts.dmSerifText(fontSize: 40)),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Classes')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'No classes yet. Add some!',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            );
          }
          final docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final classModel = ClassModel(
                title: data['title'] ?? '',
                time: data['time'] ?? '',
                location: data['location'] ?? '',
                teacher: data['teacher'] ?? '',
                notes: data['notes'] ?? '',
                color: Color(data['color'] ?? Colors.orangeAccent.value),
              );
              return ExpandableClassCard(
                classModel: classModel,
                onEdit: () => _addOrEditClass(existing: classModel, docId: doc.id),
                onDelete: () => _deleteClass(doc.id),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditClass(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// --- Class Form Dialog ---
class ClassFormDialog extends StatefulWidget {
  final ClassModel? existing;

  const ClassFormDialog({super.key, this.existing});

  @override
  State<ClassFormDialog> createState() => _ClassFormDialogState();
}

class _ClassFormDialogState extends State<ClassFormDialog> {
  late TextEditingController _titleController;
  late TextEditingController _timeFromController;
  late TextEditingController _timeToController;
  late TextEditingController _locationController;
  late TextEditingController _teacherController;
  late TextEditingController _notesController;
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existing?.title ?? '');
    // Split the time string if it exists, otherwise empty
    String time = widget.existing?.time ?? '';
    List<String> times = time.split(' - ');
    _timeFromController = TextEditingController(text: times.isNotEmpty ? times[0] : '');
    _timeToController = TextEditingController(text: times.length > 1 ? times[1] : '');
    _locationController = TextEditingController(text: widget.existing?.location ?? '');
    _teacherController = TextEditingController(text: widget.existing?.teacher ?? '');
    _notesController = TextEditingController(text: widget.existing?.notes ?? '');
    _selectedColor = widget.existing?.color ?? Colors.orangeAccent;
  }

  void _submit() {
    // Validate required fields
    if (_titleController.text.trim().isEmpty ||
        _timeFromController.text.trim().isEmpty ||
        _timeToController.text.trim().isEmpty ||
        _locationController.text.trim().isEmpty ||
        _teacherController.text.trim().isEmpty) {
      // Optionally show a SnackBar or error message here
      setState(() {}); // To update error visuals if you add them
      return;
    }

    final newClass = ClassModel(
      title: _titleController.text,
      time: '${_timeFromController.text} - ${_timeToController.text}',
      location: _locationController.text,
      teacher: _teacherController.text,
      notes: _notesController.text,
      color: _selectedColor,
    );
    Navigator.of(context).pop(newClass);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.existing == null ? 'Add Class' : 'Edit Class',
                style: GoogleFonts.dmSerifText(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Subject *', // Required
                  prefixIcon: const Icon(Icons.book_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            _timeFromController.text = picked.format(context);
                          });
                        }
                      },
                      child: AbsorbPointer(
                        child: TextField(
                          controller: _timeFromController,
                          decoration: InputDecoration(
                            labelText: 'Time From *', // Required
                            prefixIcon: const Icon(Icons.access_time),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey[100],
                          ),
                          readOnly: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            _timeToController.text = picked.format(context);
                          });
                        }
                      },
                      child: AbsorbPointer(
                        child: TextField(
                          controller: _timeToController,
                          decoration: InputDecoration(
                            labelText: 'Time To *', // Required
                            prefixIcon: const Icon(Icons.access_time),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey[100],
                          ),
                          readOnly: true,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'Room *', // Required
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _teacherController,
                decoration: InputDecoration(
                  labelText: 'Teacher *', // Required
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'Notes',
                  prefixIcon: const Icon(Icons.notes_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text('Card Color:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 16),
                  DropdownButton<Color>(
                    value: colorOptions.contains(_selectedColor) ? _selectedColor : colorOptions.first,
                    borderRadius: BorderRadius.circular(12),
                    items: List.generate(colorOptions.length, (i) {
                      return DropdownMenuItem<Color>(
                        value: colorOptions[i],
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: colorOptions[i],
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade400),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(colorNames[i]),
                          ],
                        ),
                      );
                    }),
                    onChanged: (color) {
                      setState(() {
                        _selectedColor = color!;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    ),
                    onPressed: _submit,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final colorOptions = <Color>[
  Colors.orangeAccent,
  Colors.blueAccent,
  Colors.greenAccent,
  Colors.purpleAccent,
  Colors.redAccent,
  const Color.fromARGB(255, 0, 0, 0),
  const Color.fromARGB(255, 255, 255, 255),
];

final colorNames = <String>[
  'Orange',
  'Blue',
  'Green',
  'Purple',
  'Red',
  'Black',
  'White',
];