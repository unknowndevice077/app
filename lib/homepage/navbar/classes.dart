import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/services/notification_service.dart';
import 'alarm.dart';
import 'package:flutter/foundation.dart';

class DayHelper {
  static const List<String> weekdayOrder = [
    'Monday',
    'Tuesday', 
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  /// Sorts a list of weekday names in chronological order (Mon-Sun)
  static List<String> sortDays(List<String> days) {
    List<String> sortedDays = [];
    for (String day in weekdayOrder) {
      if (days.contains(day)) {
        sortedDays.add(day);
      }
    }
    return sortedDays;
  }

  /// Gets the abbreviated name for a day (e.g., "Monday" -> "Mon")
  static String getAbbreviation(String day) {
    return day.substring(0, 3);
  }

  /// Formats a list of days for display (e.g., "Mon, Wed, Fri")
  static String formatDaysForDisplay(List<String> days) {
    final sortedDays = sortDays(days);
    return sortedDays.map(getAbbreviation).join(', ');
  }
}

class ClassModel {
  final String title;
  final String time;
  final String location;
  final String teacher;
  final String notes;
  final Color color;
  final List<String> days;
  final bool notify;

  ClassModel({
    required this.title,
    required this.time,
    required this.location,
    required this.teacher,
    required this.notes,
    required this.color,
    required this.days,
    required this.notify,
  });
}

class Classes extends StatefulWidget {
  const Classes({super.key});
  @override
  State<Classes> createState() => _ClassesState();
}

class _ClassesState extends State<Classes> {
  final uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  // ✅ FIXED: Proper initialization
  Future<void> _initializeServices() async {
    try {
      await NotificationService.initialize();
      await _updateClassNotifications();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing services: $e');
      }
    }
  }

  // ✅ FIXED: Navigate to the alarm.dart notification settings
  void _showNotificationSettings() {
    if (!mounted) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ClassNotificationPage(), // This comes from alarm.dart
      ),
    );
  }

  // ✅ FIXED: Use the master scheduling method
  Future<void> _addOrEditClass({ClassModel? existing, String? docId}) async {
    if (!mounted) return;

    final result = await showDialog<ClassModel>(
      context: context,
      builder: (context) => ClassFormDialog(existing: existing),
    );

    if (result != null && mounted) {
      final classData = {
        'title': result.title,
        'time': result.time,
        'location': result.location,
        'teacher': result.teacher,
        'notes': result.notes,
        'color': result.color.value,
        'days': result.days,
        'notify': result.notify,
      };

      try {
        if (docId != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('Classes')
              .doc(docId)
              .update(classData);
        } else {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('Classes')
              .add(classData);
        }

        // ✅ FIXED: Use the master scheduling method
        await NotificationService.scheduleAllNotifications();

        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving class: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // ✅ FIXED: Use the master scheduling method
  Future<void> _deleteClass(String docId) async {
    if (!mounted) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('Classes')
          .doc(docId)
          .delete();

      // ✅ FIXED: Use the master scheduling method
      await NotificationService.scheduleAllNotifications();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting class: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅ FIXED: Use the master scheduling method
  Future<void> _updateClassNotifications() async {
    try {
      await NotificationService.scheduleAllNotifications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating notifications: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser == null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Please log in to view classes',
            style: GoogleFonts.inter(fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Classes',
          style: GoogleFonts.dmSerifText(
            fontSize: 24.0,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        actions: [
          // ✅ FIXED: Show notification settings from alarm.dart
          IconButton(
            icon: FutureBuilder<bool>(
              future: NotificationService.areNotificationsEnabled(),
              builder: (context, snapshot) {
                final enabled = snapshot.data ?? true;
                return Icon(
                  enabled
                      ? Icons.notifications_outlined
                      : Icons.notifications_off_outlined,
                  color: Colors.blue,
                );
              },
            ),
            tooltip: 'Notification Settings',
            onPressed: _showNotificationSettings,
          ),
          IconButton(
            icon: Icon(
              Icons.add,
              color: isDark ? Colors.white : Colors.black,
            ),
            tooltip: 'Add Class',
            onPressed: () => _addOrEditClass(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('Classes')
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
                  Icon(Icons.error, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Error loading classes',
                    style: GoogleFonts.inter(fontSize: 18, color: Colors.red),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Please check your connection and try again',
                    style: GoogleFonts.inter(color: Colors.grey[600]),
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
                  Icon(Icons.school_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No classes yet. Add some!',
                    style: GoogleFonts.dmSerifText(fontSize: 20, color: Colors.grey),
                  ),
                ],
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
                title: data['title']?.toString() ?? 'Untitled Class',
                time: data['time']?.toString() ?? '',
                location: data['location']?.toString() ?? '',
                teacher: data['teacher']?.toString() ?? '',
                notes: data['notes']?.toString() ?? '',
                color: Color(data['color'] ?? Colors.blue.value),
                days: (data['days'] as List<dynamic>?)?.cast<String>() ?? [],
                notify: data['notify'] ?? true,
              );
              
              return ExpandableClassCard(
                classModel: classModel,
                onEdit: () => _addOrEditClass(existing: classModel, docId: doc.id),
                onDelete: () => _deleteClass(doc.id),
                onToggleNotify: (notify) async {
                  if (!mounted) return;

                  try {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser.uid)
                        .collection('Classes')
                        .doc(doc.id)
                        .update({'notify': notify});

                    // ✅ FIXED: Use the master scheduling method
                    await NotificationService.scheduleAllNotifications();

                    if (mounted) {
                      setState(() {});
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error updating notification setting: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class ClassFormDialog extends StatefulWidget {
  final ClassModel? existing;

  const ClassFormDialog({super.key, this.existing});

  @override
  State<ClassFormDialog> createState() => _ClassFormDialogState();
}

class _ClassFormDialogState extends State<ClassFormDialog> {
  final _titleController = TextEditingController();
  final _timeController = TextEditingController();
  final _locationController = TextEditingController();
  final _teacherController = TextEditingController();
  final _notesController = TextEditingController();
  
  Color _selectedColor = Colors.blue;
  List<String> _selectedDays = [];
  bool _notify = true;

  final List<Color> _availableColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.indigo,
    Colors.pink,
  ];

  final List<String> _weekDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _titleController.text = widget.existing!.title;
      _timeController.text = widget.existing!.time;
      _locationController.text = widget.existing!.location;
      _teacherController.text = widget.existing!.teacher;
      _notesController.text = widget.existing!.notes;
      _selectedColor = widget.existing!.color;
      _selectedDays = List.from(widget.existing!.days);
      _notify = widget.existing!.notify;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _timeController.dispose();
    _locationController.dispose();
    _teacherController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              widget.existing != null ? 'Edit Class' : 'Add New Class',
              style: GoogleFonts.dmSerifText(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            // Form fields
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Title field
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Class Title',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Time field
                    TextField(
                      controller: _timeController,
                      decoration: InputDecoration(
                        labelText: 'Time (e.g., 9:00 AM)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Location field
                    TextField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        labelText: 'Location',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Teacher field
                    TextField(
                      controller: _teacherController,
                      decoration: InputDecoration(
                        labelText: 'Teacher',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Notes field
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Notes',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Color selection
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Color',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: _availableColors.map((color) {
                            return GestureDetector(
                              onTap: () => setState(() => _selectedColor = color),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: _selectedColor == color
                                      ? Border.all(color: Colors.black, width: 3)
                                      : null,
                                ),
                                child: _selectedColor == color
                                    ? const Icon(Icons.check, color: Colors.white)
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Days selection
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Days',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: _weekDays.map((day) {
                            final isSelected = _selectedDays.contains(day);
                            return FilterChip(
                              label: Text(DayHelper.getAbbreviation(day)),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedDays.add(day);
                                  } else {
                                    _selectedDays.remove(day);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Notification toggle
                    SwitchListTile(
                      title: Text('Enable Notifications'),
                      subtitle: Text('Get notified before this class starts'),
                      value: _notify,
                      onChanged: (value) => setState(() => _notify = value),
                    ),
                  ],
                ),
              ),
            ),
            
            // Action buttons
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _saveClass,
                  child: Text(widget.existing != null ? 'Update' : 'Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _saveClass() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a class title')),
      );
      return;
    }

    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one day')),
      );
      return;
    }

    final classModel = ClassModel(
      title: _titleController.text.trim(),
      time: _timeController.text.trim(),
      location: _locationController.text.trim(),
      teacher: _teacherController.text.trim(),
      notes: _notesController.text.trim(),
      color: _selectedColor,
      days: _selectedDays,
      notify: _notify,
    );

    Navigator.pop(context, classModel);
  }
}

class ExpandableClassCard extends StatefulWidget {
  final ClassModel classModel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(bool) onToggleNotify;

  const ExpandableClassCard({
    super.key,
    required this.classModel,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleNotify,
  });

  @override
  State<ExpandableClassCard> createState() => _ExpandableClassCardState();
}

class _ExpandableClassCardState extends State<ExpandableClassCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Main card content
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: widget.classModel.color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.school,
                color: Colors.white,
                size: 24,
              ),
            ),
            title: Text(
              widget.classModel.title,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.classModel.time.isNotEmpty)
                  Text(
                    widget.classModel.time,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                if (widget.classModel.days.isNotEmpty)
                  Text(
                    DayHelper.formatDaysForDisplay(widget.classModel.days),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: widget.classModel.color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.classModel.notify 
                      ? Icons.notifications_active 
                      : Icons.notifications_off,
                  color: widget.classModel.notify 
                      ? widget.classModel.color 
                      : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    _isExpanded 
                        ? Icons.expand_less 
                        : Icons.expand_more,
                  ),
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                ),
              ],
            ),
          ),
          
          // Expanded content
          if (_isExpanded)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.classModel.color.withOpacity(0.05),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.classModel.teacher.isNotEmpty)
                    _buildDetailRow(Icons.person, 'Teacher', widget.classModel.teacher),
                  if (widget.classModel.location.isNotEmpty)
                    _buildDetailRow(Icons.location_on, 'Location', widget.classModel.location),
                  if (widget.classModel.notes.isNotEmpty)
                    _buildDetailRow(Icons.note, 'Notes', widget.classModel.notes),
                  
                  const SizedBox(height: 16),
                  
                  // Notification toggle
                  SwitchListTile(
                    title: Text('Notifications'),
                    subtitle: Text('Get notified before this class'),
                    value: widget.classModel.notify,
                    onChanged: widget.onToggleNotify,
                    activeColor: widget.classModel.color,
                    contentPadding: EdgeInsets.zero,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: widget.onEdit,
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit'),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => _showDeleteConfirmation(context),
                        icon: const Icon(Icons.delete),
                        label: const Text('Delete'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Class'),
        content: Text('Are you sure you want to delete "${widget.classModel.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
