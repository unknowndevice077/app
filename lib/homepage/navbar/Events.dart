import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchClasses();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now(); // <-- Highlight today by default
  }

  Future<void> _fetchClasses() async {
    final snapshot = await FirebaseFirestore.instance.collection('Classes').get();
    Map<DateTime, List<Map<String, dynamic>>> events = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final List days = data['days'] ?? [];
      final String time = data['time'] ?? '';
      final String title = data['title'] ?? '';

      // Regular class days
      for (var day in days) {
        int weekday = _weekdayFromString(day);
        if (weekday != -1) {
          DateTime date = _getNextWeekday(DateTime.now(), weekday);
          events.putIfAbsent(date, () => []);
          events[date]!.add({'title': title, 'time': time, 'type': 'class'});
        }
      }

      // Custom events
      final eventsSnapshot = await doc.reference.collection('events').get();
      for (var eventDoc in eventsSnapshot.docs) {
        final eventData = eventDoc.data();
        final DateTime eventDate = (eventData['date'] as Timestamp).toDate();
        final eventTitle = eventData['title'] ?? '';
        final eventType = eventData['type'] ?? 'other';
        events.putIfAbsent(DateTime(eventDate.year, eventDate.month, eventDate.day), () => []);
        events[DateTime(eventDate.year, eventDate.month, eventDate.day)]!.add({
          'title': eventTitle,
          'type': eventType,
          'date': eventDate,
          'classTitle': data['title'] ?? '',
          'time': '', // or eventData['time'] if you add it
        });
      }
    }

    if (mounted) {
      setState(() {
        _classEvents = events;
      });
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: Icon(_editMode ? Icons.check : Icons.edit),
            tooltip: 'Edit Events',
            onPressed: () {
              setState(() {
                _editMode = !_editMode;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Event',
            onPressed: () async {
              await showDialog(
                context: context,
                builder: (context) => AddEventDialog(
                  initialDate: _selectedDay ?? DateTime.now(), // Use selected date or today
                ),
              );
              _fetchClasses();
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
                color: Colors.blueAccent.withOpacity(0.4),
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
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
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
          const SizedBox(height: 16),
          Expanded(
            child: _selectedDay == null
                ? const Center(child: Text('Select a day to see your classes.'))
                : ListView(
                    children: _getEventsForDay(_selectedDay!).map((event) {
                      return ListTile(
                        leading: Icon(
                          event['type'] == 'exam'
                              ? Icons.school
                              : event['type'] == 'deadline'
                                  ? Icons.event_note
                                  : Icons.event,
                          color: event['type'] == 'exam'
                              ? Colors.red
                              : event['type'] == 'deadline'
                                  ? Colors.orange
                                  : Colors.blue,
                        ),
                        title: Text(event['title'] ?? ''),
                        subtitle: Text(
                          [
                            if (event['classTitle'] != null && event['classTitle'] != '')
                              event['classTitle'],
                            if (event['time'] != null && event['time'] != '')
                              event['time'],
                          ].join(' • '),
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
                                      _fetchClasses();
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
                                      if (confirm == true) {
                                        final classTitle = event['classTitle'];
                                        final eventTitle = event['title'];
                                        final eventDate = event['date'];
                                        // Remove from Firestore
                                        final classSnap = await FirebaseFirestore.instance
                                            .collection('Classes')
                                            .where('title', isEqualTo: classTitle)
                                            .get();
                                        if (classSnap.docs.isNotEmpty) {
                                          final classDoc = classSnap.docs.first;
                                          final eventsSnap = await classDoc.reference.collection('events')
                                              .where('title', isEqualTo: eventTitle)
                                              .where('date', isEqualTo: Timestamp.fromDate(eventDate))
                                              .get();
                                          for (var doc in eventsSnap.docs) {
                                            await doc.reference.delete();
                                          }
                                        }
                                        // Remove from local state for instant UI update
                                        setState(() {
                                          final key = DateTime(eventDate.year, eventDate.month, eventDate.day);
                                          _classEvents[key]?.removeWhere((e) =>
                                            e['title'] == eventTitle &&
                                            (e['date'] == null || e['date'] == eventDate)
                                          );
                                        });
                                        _fetchClasses();
                                      }
                                    },
                                  ),
                                ],
                              )
                            : null,
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class AddEventDialog extends StatefulWidget {
  final DateTime? initialDate;
  const AddEventDialog({super.key, this.initialDate});

  @override
  State<AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<AddEventDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedClassId;
  String? _selectedClassTitle;
  String _eventTitle = '';
  String _eventType = '';
  late DateTime _selectedDate;
  final TextEditingController _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Use the passed initial date or default to today
    _selectedDate = widget.initialDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _resetTitle() {
    _eventTitle = '';
    _titleController.text = '';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialDate != null 
          ? 'Add Event for ${_selectedDate.toLocal().toString().split(' ')[0]}'
          : 'Add Event'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance.collection('Classes').get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();
                  return DropdownButtonFormField<String>(
                    value: _selectedClassId,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
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
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text('Date: ${_selectedDate.toLocal().toString().split(' ')[0]}'),
                trailing: OutlinedButton(
                  child: const Text('Change'),
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
              if (_eventType == 'other' && _eventTitle.isEmpty) return;
              await FirebaseFirestore.instance
                  .collection('Classes')
                  .doc(_selectedClassId)
                  .collection('events')
                  .add({
                'title': _eventType == 'other' ? _eventTitle : _eventType,
                'type': _eventType,
                'date': Timestamp.fromDate(_selectedDate),
                'classTitle': _selectedClassTitle ?? '',
              });
              Navigator.pop(context);
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
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
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _resetTitle() {
    _eventTitle = '';
    _titleController.text = '';
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
              // Find and update the event in Firestore
              final classTitle = widget.event['classTitle'];
              final oldTitle = widget.event['title'];
              final oldDate = widget.event['date'];
              final classSnap = await FirebaseFirestore.instance
                  .collection('Classes')
                  .where('title', isEqualTo: classTitle)
                  .get();
              if (classSnap.docs.isNotEmpty) {
                final classDoc = classSnap.docs.first;
                final eventsSnap = await classDoc.reference.collection('events')
                    .where('title', isEqualTo: oldTitle)
                    .where('date', isEqualTo: Timestamp.fromDate(oldDate))
                    .get();
                for (var doc in eventsSnap.docs) {
                  await doc.reference.update({
                    'title': _eventType == 'other' ? _eventTitle : _eventType,
                    'type': _eventType,
                    'date': Timestamp.fromDate(_selectedDate),
                  });
                }
              }
              Navigator.pop(context);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
