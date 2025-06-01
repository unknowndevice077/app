import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class Events extends StatefulWidget {
  const Events({super.key});

  @override
  State<Events> createState() => _EventsState();
}

class _EventsState extends State<Events> {
  Map<DateTime, List<Map<String, dynamic>>> _classEvents = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _editMode = false;

  static const double titleFontSize = 28.0;

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _fetchClasses();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchClasses() async {
    if (currentUserId == null || !mounted) return;

    try {
      // Fetch classes for regular class days
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('Classes')
          .get();

      if (!mounted) return;

      Map<DateTime, List<Map<String, dynamic>>> events = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final List days = data['days'] ?? [];
        final String time = data['time'] ?? '';
        final String title = data['title'] ?? '';

        for (var day in days) {
          int weekday = _weekdayFromString(day);
          if (weekday != -1) {
            DateTime date = _getNextWeekday(DateTime.now(), weekday);
            events.putIfAbsent(date, () => []);
            events[date]!.add({'title': title, 'time': time, 'type': 'class'});
          }
        }
      }

      // Fetch Events from Events collection
      final eventsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('Events')
          .get();

      if (!mounted) return;

      for (var doc in eventsSnapshot.docs) {
        final data = doc.data();
        final DateTime? eventDate = (data['date'] as Timestamp?)?.toDate();
        if (eventDate != null) {
          final dateKey = DateTime(eventDate.year, eventDate.month, eventDate.day);
          events.putIfAbsent(dateKey, () => []);
          events[dateKey]!.add({
            'id': doc.id, // <-- Add this line
            'title': data['title'] ?? 'Event',
            'time': data['time'] ?? '',
            'type': data['type'] ?? 'event',
            'classTitle': data['classTitle'] ?? '',
            'date': eventDate,
          });
        }
      }

      // Fetch events under each class
      final classesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('Classes')
          .get();

      for (var classDoc in classesSnapshot.docs) {
        final classTitle = classDoc['title'] ?? '';
        final eventsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('Classes')
            .doc(classDoc.id)
            .collection('events')
            .get();

        for (var eventDoc in eventsSnapshot.docs) {
          final data = eventDoc.data();
          final DateTime? eventDate = (data['date'] as Timestamp?)?.toDate();
          if (eventDate != null) {
            final dateKey = DateTime(eventDate.year, eventDate.month, eventDate.day);
            events.putIfAbsent(dateKey, () => []);
            events[dateKey]!.add({
              'title': data['title'] ?? 'Event',
              'time': data['time'] ?? '',
              'type': data['type'] ?? 'event',
              'classTitle': classTitle,
              'date': eventDate,
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _classEvents = events;
        });
      }
    } catch (e) {
      print('Error fetching classes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading events: $e')),
        );
      }
    }
  }

  Future<void> _deleteEvent(String eventType, String classTitle, DateTime eventDate) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || !mounted) return;

    try {
      // Delete from Events collection using 'type'
      final eventsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('Events')
          .where('type', isEqualTo: eventType) // <-- use 'type'
          .where('classTitle', isEqualTo: classTitle)
          .get();

      if (!mounted) return;

      for (var doc in eventsSnapshot.docs) {
        final docDate = (doc.data()['date'] as Timestamp?)?.toDate();
        if (docDate != null) {
          final docDateKey = DateTime(docDate.year, docDate.month, docDate.day);
          final eventDateKey = DateTime(eventDate.year, eventDate.month, eventDate.day);

          if (docDateKey == eventDateKey) {
            await doc.reference.delete();
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error deleting event: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting event: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteEventById(String docId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || !mounted) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('Events')
          .doc(docId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error deleting event: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting event: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  int _weekdayFromString(String day) {
    switch (day) {
      case 'Monday':
        return DateTime.monday;
      case 'Tuesday':
        return DateTime.tuesday;
      case 'Wednesday':
        return DateTime.wednesday;
      case 'Thursday':
        return DateTime.thursday;
      case 'Friday':
        return DateTime.friday;
      case 'Saturday':
        return DateTime.saturday;
      case 'Sunday':
        return DateTime.sunday;
      default:
        return -1;
    }
  }

  DateTime _getNextWeekday(DateTime from, int weekday) {
    int daysToAdd = (weekday - from.weekday) % 7;
    return DateTime(from.year, from.month, from.day + daysToAdd);
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return _classEvents[DateTime(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        title: Text(
          'Events',
          style: GoogleFonts.dmSerifText(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_editMode ? Icons.check : Icons.edit),
            tooltip: _editMode ? 'Done Editing' : 'Edit Events',
            onPressed: () {
              if (mounted) setState(() => _editMode = !_editMode);
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Event',
            onPressed: () async {
              await showDialog(
                context: context,
                builder: (context) => AddEventDialog(
                  initialDate: _selectedDay ?? DateTime.now(),
                ),
              );
              if (mounted) _fetchClasses();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2100, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: CalendarFormat.month,
            availableCalendarFormats: const {
              CalendarFormat.month: 'Month',
            },
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: _getEventsForDay,
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold),
              leftChevronIcon: const Icon(Icons.chevron_left, size: 28),
              rightChevronIcon: const Icon(Icons.chevron_right, size: 28),
            ),
            onDaySelected: (selectedDay, focusedDay) {
              if (mounted) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              }
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return const SizedBox.shrink();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(events.length, (index) {
                    final event = events[index] as Map<String, dynamic>;
                    Color dotColor;
                    switch (event['type']) {
                      case 'exam':
                        dotColor = Colors.red;
                        break;
                      case 'deadline':
                        dotColor = Colors.orange;
                        break;
                      case 'class':
                        dotColor = Colors.blue;
                        break;
                      default:
                        dotColor = Colors.grey;
                    }
                    return Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 0.5),
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _selectedDay == null
                ? Center(
                    child: Text(
                      'Select a day to see your events.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                : _getEventsForDay(_selectedDay!).isEmpty
                    ? Center(
                        child: Text(
                          'No events for this day.',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: _getEventsForDay(_selectedDay!).length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final event = _getEventsForDay(_selectedDay!)[idx];
                          final isExam = event['type'] == 'exam';
                          final isDeadline = event['type'] == 'deadline';
                          final iconData = isExam
                              ? Icons.school
                              : isDeadline
                                  ? Icons.event_note
                                  : Icons.event;
                          final iconColor = isExam
                              ? Colors.red
                              : isDeadline
                                  ? Colors.yellow[700]
                                  : Colors.blue;
                          final cardColor = Theme.of(context).cardColor;
                          final textColor = Theme.of(context).textTheme.bodyLarge?.color;

                          return Card(
                            color: cardColor,
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: iconColor!.withOpacity(0.15),
                                child: Icon(iconData, color: iconColor),
                              ),
                              title: Text(
                                event['title'] ?? '',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                event['classTitle'] ?? '',
                                style: TextStyle(
                                  color: textColor?.withOpacity(0.7),
                                ),
                              ),
                              trailing: (_editMode && event['type'] != 'class')
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue),
                                          tooltip: 'Edit Event',
                                          onPressed: () async {
                                            await showDialog(
                                              context: context,
                                              builder: (context) => EditEventDialog(event: event),
                                            );
                                            if (mounted) _fetchClasses();
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          tooltip: 'Delete Event',
                                          onPressed: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text('Delete Event'),
                                                content: const Text('Are you sure you want to delete this event?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context, false),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context, true),
                                                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true && mounted) {
                                              await _deleteEventById(event['id']);
                                              _fetchClasses();
                                            }
                                          },
                                        ),
                                      ],
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ✅ FIXED: Add mounted checks to AddEventDialog
class AddEventDialog extends StatefulWidget {
  final DateTime? initialDate;
  const AddEventDialog({super.key, this.initialDate});

  @override
  State<AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<AddEventDialog> {
  String? _selectedClassId;
  String _selectedClassTitle = '';
  String _eventType = '';
  String _eventTitle = '';
  DateTime _selectedDate = DateTime.now();
  
  // ✅ Get current user
  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    // ✅ Use the initialDate if provided, otherwise use today
    _selectedDate = widget.initialDate ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Event'),
      content: SingleChildScrollView(
        child: Form(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ Subject Selection
              FutureBuilder<QuerySnapshot>(
                future: currentUserId != null 
                    ? FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUserId)
                        .collection('Classes')
                        .get()
                    : null,
                builder: (context, snapshot) {
                  if (currentUserId == null) {
                    return const Text('Please log in to add events');
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Text('No classes found');
                  }
                  
                  return DropdownButtonFormField<String>(
                    value: _selectedClassId,
                    decoration: const InputDecoration(
                      labelText: 'Select Subject',
                      prefixIcon: Icon(Icons.book),
                      border: OutlineInputBorder(),
                    ),
                    items: snapshot.data!.docs.map((doc) {
                      final title = doc['title'] ?? '';
                      return DropdownMenuItem(
                        value: doc.id,
                        child: Text(title),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedClassId = value;
                        final doc = snapshot.data!.docs.firstWhere((doc) => doc.id == value);
                        _selectedClassTitle = doc['title'] ?? '';
                      });
                    },
                    validator: (val) => val == null ? 'Please select a subject' : null,
                  );
                },
              ),
              const SizedBox(height: 16),

              // ✅ Event Type Selection
              DropdownButtonFormField<String>(
                value: _eventType.isEmpty ? null : _eventType,
                decoration: const InputDecoration(
                  labelText: 'Event Type',
                  prefixIcon: Icon(Icons.category),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'exam', child: Text('Exam')),
                  DropdownMenuItem(value: 'deadline', child: Text('Deadline')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (val) {
                  setState(() {
                    _eventType = val!;
                    _resetTitle();
                  });
                },
                validator: (val) => val == null || val.isEmpty ? 'Please select an event type' : null,
              ),
              const SizedBox(height: 16),

              // ✅ Custom Title Field (only for 'other' events)
              if (_eventType == 'other')
                Column(
                  children: [
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Event Title',
                        prefixIcon: Icon(Icons.edit),
                        border: OutlineInputBorder(),
                        hintText: 'Enter custom event name...',
                      ),
                      onChanged: (val) => _eventTitle = val,
                      validator: (val) => (_eventType == 'other' && (val == null || val.isEmpty))
                          ? 'Please enter the event title'
                          : null,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),

              // ✅ Date Selection ONLY (removed time picker)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: const Icon(Icons.calendar_today, color: Colors.blue),
                  title: Text(
                    'Date: ${_formatDate(_selectedDate)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  trailing: OutlinedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                        helpText: 'Select ${_eventType.isEmpty ? 'Event' : _eventType.toUpperCase()} Date',
                        confirmText: 'SELECT',
                        cancelText: 'CANCEL',
                      );
                      if (picked != null && picked != _selectedDate) {
                        setState(() {
                          _selectedDate = picked;
                        });
                      }
                    },
                    child: const Text('CHANGE'),
                  ),
                ),
              ),

              // ✅ Updated info text (removed time reference)
              if (_eventType.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getEventColor(_eventType).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getEventColor(_eventType).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getEventIcon(_eventType),
                        color: _getEventColor(_eventType),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getEventDescription(_eventType),
                          style: TextStyle(
                            color: _getEventColor(_eventType),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedClassId != null && _eventType.isNotEmpty
              ? _saveEvent
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedClassId != null && _eventType.isNotEmpty
                ? Colors.blue
                : Colors.grey,
          ),
          child: const Text('Save Event'),
        ),
      ],
    );
  }

  // ✅ Helper methods - removed time formatting
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // ✅ REMOVED: String _formatTime(TimeOfDay time) method

  Color _getEventColor(String eventType) {
    switch (eventType) {
      case 'exam':
        return Colors.red;
      case 'deadline':
        return Colors.orange;
      case 'other':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getEventIcon(String eventType) {
    switch (eventType) {
      case 'exam':
        return Icons.school;
      case 'deadline':
        return Icons.event_note;
      case 'other':
        return Icons.event;
      default:
        return Icons.event;
    }
  }

  // ✅ Updated descriptions (removed time references)
  String _getEventDescription(String eventType) {
    switch (eventType) {
      case 'exam':
        return 'Exam scheduled for ${_formatDate(_selectedDate)}';
      case 'deadline':
        return 'Deadline set for ${_formatDate(_selectedDate)}';
      case 'other':
        return 'Custom event scheduled for ${_formatDate(_selectedDate)}';
      default:
        return '';
    }
  }

  // ✅ Updated save method (removed time field)
  void _saveEvent() async {
    if (currentUserId == null) return;
    
    try {
      final eventTitle = _eventType == 'other' ? _eventTitle : _eventType;
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('Events')
          .add({
            'title': eventTitle,
            'type': _eventType,
            'classId': _selectedClassId,
            'classTitle': _selectedClassTitle,
            'date': Timestamp.fromDate(_selectedDate),
            // ✅ REMOVED: 'time': _formatTime(_selectedTime),
            'createdAt': FieldValue.serverTimestamp(),
            'completed': false,
          });
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_eventType.toUpperCase()} scheduled for ${_formatDate(_selectedDate)}!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding event: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _resetTitle() {
    setState(() {
      _eventTitle = '';
    });
  }
}

class EditEventDialog extends StatefulWidget {
  final Map<String, dynamic> event;
  const EditEventDialog({super.key, required this.event});

  @override
  State<EditEventDialog> createState() => _EditEventDialogState();
}

class _EditEventDialogState extends State<EditEventDialog> {
  late String _eventTitle;
  late String _eventType;
  late DateTime _selectedDate;
  late TextEditingController _titleController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _eventTitle = widget.event['title'] ?? '';
    _eventType = widget.event['type'] ?? '';
    _selectedDate = widget.event['date'] ?? DateTime.now();
    _titleController = TextEditingController(text: _eventTitle);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Event'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _eventType.isEmpty ? null : _eventType,
                decoration: const InputDecoration(
                  labelText: 'Event Type',
                  prefixIcon: Icon(Icons.category),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'exam', child: Text('Exam')),
                  DropdownMenuItem(value: 'deadline', child: Text('Deadline')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (val) {
                  setState(() {
                    _eventType = val!;
                    _resetTitle();
                  });
                },
                validator: (val) => val == null || val.isEmpty ? 'Please select an event type' : null,
              ),
              const SizedBox(height: 16),
              if (_eventType == 'other')
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Other Event Type',
                    prefixIcon: Icon(Icons.edit),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => _eventTitle = val,
                  validator: (val) => (_eventType == 'other' && (val == null || val.isEmpty))
                      ? 'Please enter the event type'
                      : null,
                ),
              const SizedBox(height: 16),
              // ✅ Date picker only (removed time)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text('Date: ${_selectedDate.toLocal().toString().split(' ')[0]}'),
                trailing: OutlinedButton(
                  child: const Text('Pick'),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _selectedDate = picked);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              await _updateEvent();
              if (mounted) {
                Navigator.pop(context);
              }
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  // ✅ Updated _updateEvent method (removed time field)
  Future<void> _updateEvent() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || !mounted) return;

    try {
      final eventTitle = _eventType == 'other' ? _eventTitle : _eventType;
      final classTitle = widget.event['classTitle'] ?? '';
      final oldTitle = widget.event['title'] ?? '';
      final oldDate = widget.event['date'] ?? DateTime.now();

      final eventsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('Events')
          .where('type', isEqualTo: widget.event['type']) // <-- use 'type'
          .where('classTitle', isEqualTo: classTitle)
          .get();

      if (!mounted) return;

      for (var doc in eventsSnapshot.docs) {
        final docDate = (doc.data()['date'] as Timestamp?)?.toDate();
        if (docDate != null) {
          final docDateKey = DateTime(docDate.year, docDate.month, docDate.day);
          final oldDateKey = DateTime(oldDate.year, oldDate.month, oldDate.day);
          
          if (docDateKey == oldDateKey) {
            await doc.reference.update({
              'title': eventTitle,
              'type': _eventType,
              'date': Timestamp.fromDate(_selectedDate),
              // ✅ REMOVED: time field update
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error updating event: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating event: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _resetTitle() {
    setState(() {
      _eventTitle = '';
      _titleController.text = '';
    });
  }
}
