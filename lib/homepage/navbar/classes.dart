import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'dart:io';
import 'package:app/homepage/navbar/alarm.dart';

class ClassNotificationOverlay extends StatelessWidget {
  final Widget child;

  const ClassNotificationOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class Classes extends StatefulWidget {
  const Classes({super.key});

  @override
  State<Classes> createState() => _ClassesState();
}

class _ClassesState extends State<Classes> {
  final uid = FirebaseAuth.instance.currentUser!.uid;

  // Add class
  Future<void> _addClass(Map<String, dynamic> classData) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('Classes')
        .add(classData);
  }

  // Delete class
  Future<void> _deleteClass(String docId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('Classes')
        .doc(docId)
        .delete();
  }

  // Add or edit class dialog
  Future<void> _addOrEditClass({ClassModel? existing, String? docId}) async {
    final result = await showDialog<ClassModel>(
      context: context,
      builder: (context) => ClassFormDialog(existing: existing),
    );
    if (result != null) {
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
      if (docId != null) {
        // Edit existing
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('Classes')
            .doc(docId)
            .update(classData);
      } else {
        // Add new
        await _addClass(classData);
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Classes',
          style: GoogleFonts.dmSerifText(fontSize: 36, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: Icon(
              ClassNotificationService.notificationsEnabled
                  ? Icons.notifications_outlined
                  : Icons.notifications_off_outlined,
              color: ClassNotificationService.notificationsEnabled
                  ? Colors.black
                  : Colors.grey[600],
            ),
            tooltip: 'Notification Settings',
            onPressed: () => _showNotificationSettings(),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black),
            tooltip: 'Add Class',
            onPressed: () => _addOrEditClass(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('Classes')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No classes yet. Add some!',
                    style: GoogleFonts.dmSerifText(
                      fontSize: 20,
                      color: Colors.grey,
                    ),
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
                title: data['title'] ?? '',
                time: data['time'] ?? '',
                location: data['location'] ?? '',
                teacher: data['teacher'] ?? '',
                notes: data['notes'] ?? '',
                color: Color(data['color'] ?? Colors.white.value),
                days: List<String>.from(data['days'] ?? []),
                notify: data['notify'] ?? true,
              );
              return ExpandableClassCard(
                classModel: classModel,
                onEdit: () => _addOrEditClass(
                  existing: classModel,
                  docId: doc.id,
                ),
                onDelete: () => _deleteClass(doc.id),
                onToggleNotify: (notify) async {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('Classes')
                      .doc(doc.id)
                      .update({'notify': notify});
                  setState(() {});
                  _updateClassNotifications();
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showNotificationSettings() {
    Timer? dialogTimer;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (ClassNotificationService.isPlaying) {
            dialogTimer?.cancel();
            dialogTimer = Timer.periodic(
              const Duration(milliseconds: 100),
              (_) {
                setDialogState(() {});
              },
            );
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text(
              'Notification Settings',
              style: GoogleFonts.dmSerifText(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Notification toggle with description
                  Row(
                    children: [
                      Icon(
                        ClassNotificationService.notificationsEnabled
                            ? Icons.notifications_active
                            : Icons.notifications_off,
                        size: 28,
                        color: ClassNotificationService.notificationsEnabled
                            ? Colors.green[700]
                            : Colors.red[700],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Class Notifications',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: ClassNotificationService.notificationsEnabled
                                    ? Colors.green[700]
                                    : Colors.red[700],
                              ),
                            ),
                            Text(
                              ClassNotificationService.notificationsEnabled
                                  ? 'Notifications are enabled'
                                  : 'Notifications are silenced',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: ClassNotificationService.notificationsEnabled
                                    ? Colors.green[600]
                                    : Colors.red[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: ClassNotificationService.notificationsEnabled,
                        onChanged: (value) async {
                          await ClassNotificationService.setNotificationsEnabled(
                            value,
                          );
                          setDialogState(() {});
                          setState(() {});
                          _updateClassNotifications();
                        },
                        activeColor: Colors.green[700],
                        inactiveThumbColor: Colors.red[700],
                        inactiveTrackColor: Colors.red[200],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (ClassNotificationService.notificationsEnabled) ...[
                    Text(
                      'When enabled, you will receive:',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    buildNotificationFeature(
                      '⏰',
                      'Reminder 10 minutes before class starts',
                    ),
                    buildNotificationFeature(
                      '🚨',
                      Platform.isWindows
                          ? 'In-app alarm when class starts'
                          : 'System alarm when class starts',
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.purple[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AlarmSoundPicker(),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.purple[200]!,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  ClassNotificationService.currentSongTitle.isEmpty
                                      ? 'No song playing'
                                      : ClassNotificationService.currentSongTitle,
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.purple[700],
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        if (ClassNotificationService.isPlaying) {
                                          await ClassNotificationService.pauseCurrentTestSound();
                                        } else if (ClassNotificationService.currentSongTitle.isNotEmpty) {
                                          await ClassNotificationService.resumeCurrentTestSound();
                                        } else {
                                          await ClassNotificationService.testAlarmSound(
                                            ClassNotificationService.selectedAlarmSound,
                                            playOutLoud: true,
                                          );
                                        }
                                        setDialogState(() {});
                                      },
                                      icon: Icon(
                                        ClassNotificationService.isPlaying
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                        color: Colors.white,
                                      ),
                                      label: Text(
                                        ClassNotificationService.isPlaying
                                            ? 'Pause'
                                            : (ClassNotificationService.currentSongTitle.isNotEmpty
                                                ? 'Resume'
                                                : 'Play'),
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.purple[600],
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: 16,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        await ClassNotificationService.stopCurrentTestSound();
                                        setDialogState(() {});
                                      },
                                      icon: const Icon(
                                        Icons.stop,
                                        color: Colors.white,
                                      ),
                                      label: const Text(
                                        'Stop',
                                        style: TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange[600],
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              Platform.isWindows
                                  ? 'Windows: Notifications appear as overlay banners in the app'
                                  : 'Notifications only work for classes scheduled today',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_outlined,
                            color: Colors.orange[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'All class notifications and alarms are currently silenced.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.orange[700],
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
            actions: [
              TextButton(
                onPressed: () async {
                  await ClassNotificationService.stopCurrentTestSound();
                  Navigator.pop(context);
                },
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      dialogTimer?.cancel();
    });
  }

  Widget buildNotificationFeature(String emoji, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(description, style: GoogleFonts.inter(fontSize: 14)),
          ),
          Icon(Icons.check_circle, color: Colors.green[600], size: 16),
        ],
      ),
    );
  }

  void _updateClassNotifications() {
    // Implement your notification update logic here if needed
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
  bool notify;

  ClassModel({
    required this.title,
    required this.time,
    required this.location,
    required this.teacher,
    required this.notes,
    required this.color,
    required this.days,
    this.notify = true,
  });
}

class ExpandableClassCard extends StatefulWidget {
  final ClassModel classModel;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final ValueChanged<bool>? onToggleNotify;

  const ExpandableClassCard({
    super.key,
    required this.classModel,
    this.onEdit,
    this.onDelete,
    this.onToggleNotify,
  });

  @override
  State<ExpandableClassCard> createState() => _ExpandableClassCardState();
}

class _ExpandableClassCardState extends State<ExpandableClassCard> {
  bool _isExpanded = false;

  Color get _iconColor {
    if (widget.classModel.color.value == Colors.white.value ||
        widget.classModel.color.value ==
            const Color.fromARGB(255, 255, 255, 255).value) {
      return Colors.black;
    }
    if (widget.classModel.color.value == Colors.black.value ||
        widget.classModel.color.value ==
            const Color.fromARGB(255, 0, 0, 0).value) {
      return Colors.white;
    }
    return ThemeData.estimateBrightnessForColor(widget.classModel.color) ==
            Brightness.light
        ? Colors.black
        : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final isLight =
        ThemeData.estimateBrightnessForColor(widget.classModel.color) ==
        Brightness.light;
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: widget.classModel.color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isExpanded ? 0.18 : 0.10),
              blurRadius: _isExpanded ? 18 : 8,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    widget.classModel.title,
                    style: GoogleFonts.dmSerifText(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isLight ? Colors.black : Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
                Row(
                  children: [
                    // Per-class notification bell
                    IconButton(
                      icon: Icon(
                        widget.classModel.notify
                            ? Icons.notifications_active
                            : Icons.notifications_off,
                        color:
                            widget.classModel.notify
                                ? Colors.blue
                                : Colors.grey,
                      ),
                      tooltip:
                          widget.classModel.notify
                              ? 'Disable notifications for this class'
                              : 'Enable notifications for this class',
                      onPressed: () {
                        widget.onToggleNotify?.call(!widget.classModel.notify);
                      },
                    ),
                    if (widget.onEdit != null)
                      IconButton(
                        icon: const Icon(CupertinoIcons.pencil, size: 22),
                        color: _iconColor,
                        tooltip: 'Edit',
                        onPressed: widget.onEdit,
                      ),
                    if (widget.onDelete != null)
                      IconButton(
                        icon: const Icon(CupertinoIcons.trash, size: 22),
                        color: _iconColor,
                        tooltip: 'Delete',
                        onPressed: widget.onDelete,
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  CupertinoIcons.time,
                  size: 18,
                  color: isLight ? Colors.black54 : Colors.white70,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    widget.classModel.time,
                    style: GoogleFonts.roboto(
                      color: isLight ? Colors.black54 : Colors.white70,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  CupertinoIcons.person,
                  size: 18,
                  color: isLight ? Colors.black54 : Colors.white70,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    widget.classModel.teacher,
                    style: GoogleFonts.roboto(
                      color: isLight ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  CupertinoIcons.location,
                  size: 18,
                  color: isLight ? Colors.black54 : Colors.white70,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    widget.classModel.location,
                    style: GoogleFonts.roboto(
                      color: isLight ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (_isExpanded) ...[
              const SizedBox(height: 16),
              Divider(color: isLight ? Colors.black12 : Colors.white24),
              const SizedBox(height: 8),
              Text(
                widget.classModel.notes.isNotEmpty
                    ? widget.classModel.notes
                    : 'No notes for this class.',
                style: GoogleFonts.roboto(
                  color: isLight ? Colors.black87 : Colors.white70,
                  fontSize: 15,
                  fontStyle:
                      widget.classModel.notes.isEmpty
                          ? FontStyle.italic
                          : FontStyle.normal,
                ),
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
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
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _teacherController;
  late TextEditingController _notesController;
  late Color _selectedColor;

  late TimeOfDay? _startTime;
  late TimeOfDay? _endTime;

  bool _showTitleError = false;
  bool _showRoomError = false;
  bool _showTeacherError = false;
  bool _showStartTimeError = false;
  bool _showEndTimeError = false;

  List<String> _selectedDays = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existing?.title ?? '',
    );
    _locationController = TextEditingController(
      text: widget.existing?.location ?? '',
    );
    _teacherController = TextEditingController(
      text: widget.existing?.teacher ?? '',
    );
    _notesController = TextEditingController(
      text: widget.existing?.notes ?? '',
    );
    _selectedColor =
        widget.existing?.color ?? const Color.fromARGB(255, 255, 255, 255);

    // Parse times if editing
    String time = widget.existing?.time ?? '';
    List<String> times = time.split(' - ');
    _startTime =
        times.isNotEmpty && times[0].trim().isNotEmpty
            ? _parseTimeOfDay(times[0])
            : null;
    _endTime =
        times.length > 1 && times[1].trim().isNotEmpty
            ? _parseTimeOfDay(times[1])
            : null;

    // Initialize selected days
    _selectedDays = widget.existing?.days ?? [];
  }

  TimeOfDay? _parseTimeOfDay(String input) {
    final format = RegExp(r'(\d{1,2}):(\d{2})\s*([AP]M)', caseSensitive: false);
    final match = format.firstMatch(input.trim());
    if (match != null) {
      int hour = int.parse(match.group(1)!);
      final int minute = int.parse(match.group(2)!);
      final String period = match.group(3)!.toUpperCase();
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    }
    return null;
  }

  String _formatTimeOfDay(TimeOfDay? time) {
    if (time == null) return '';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  void _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          isStart
              ? (_startTime ?? TimeOfDay(hour: 8, minute: 0))
              : (_endTime ?? TimeOfDay(hour: 9, minute: 0)),
      helpText: isStart ? 'Select Start Time' : 'Select End Time',
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _submit() {
    setState(() {
      _showTitleError = _titleController.text.trim().isEmpty;
      _showRoomError = _locationController.text.trim().isEmpty;
      _showTeacherError = _teacherController.text.trim().isEmpty;
      _showStartTimeError = _startTime == null;
      _showEndTimeError = _endTime == null;
    });

    if (_showTitleError ||
        _showRoomError ||
        _showTeacherError ||
        _showStartTimeError ||
        _showEndTimeError) {
      return;
    }

    final newClass = ClassModel(
      title: _titleController.text,
      time: '${_formatTimeOfDay(_startTime)} - ${_formatTimeOfDay(_endTime)}',
      location: _locationController.text,
      teacher: _teacherController.text,
      notes: _notesController.text,
      color: _selectedColor,
      days: _selectedDays,
      notify:
          widget.existing?.notify ??
          true, // <-- ensure notify is always present
    );
    Navigator.of(context).pop(newClass);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _teacherController.dispose();
    _notesController.dispose();
    super.dispose();
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
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSerifText(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Subject ',
                  prefixIcon: const Icon(CupertinoIcons.book),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  errorText: _showTitleError ? 'Required' : null,
                ),
              ),
              const SizedBox(height: 16),
              // Modern, clear time pickers
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 8, bottom: 4),
                          child: Text(
                            'Start Time ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _pickTime(isStart: true),
                          child: AbsorbPointer(
                            child: TextField(
                              decoration: InputDecoration(
                                prefixIcon: const Icon(CupertinoIcons.clock),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                                hintText: 'e.g. 08:00 AM',
                                errorText:
                                    _showStartTimeError ? 'Required' : null,
                              ),
                              controller: TextEditingController(
                                text: _formatTimeOfDay(_startTime),
                              ),
                              readOnly: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 8, bottom: 4),
                          child: Text(
                            'End Time ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _pickTime(isStart: false),
                          child: AbsorbPointer(
                            child: TextField(
                              decoration: InputDecoration(
                                prefixIcon: const Icon(
                                  CupertinoIcons.clock_fill,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                                hintText: 'e.g. 09:30 AM',
                                errorText:
                                    _showEndTimeError ? 'Required' : null,
                              ),
                              controller: TextEditingController(
                                text: _formatTimeOfDay(_endTime),
                              ),
                              readOnly: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'Room ',
                  prefixIcon: const Icon(CupertinoIcons.location),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  errorText: _showRoomError ? 'Required' : null,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _teacherController,
                decoration: InputDecoration(
                  labelText: 'Teacher ',
                  prefixIcon: const Icon(CupertinoIcons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  errorText: _showTeacherError ? 'Required' : null,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'Notes',
                  prefixIcon: const Icon(CupertinoIcons.pencil_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'Days Held',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ),
              ),
              SizedBox(
                height: 100,
                child: GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.5,
                  children: [
                    for (final day in [
                      'Monday',
                      'Tuesday',
                      'Wednesday',
                      'Thursday',
                      'Friday',
                      'Saturday',
                    ])
                      SizedBox(
                        height: 44,
                        child: FilterChip(
                          showCheckmark: false,
                          label: SizedBox(
                            width: 56,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 13),
                                child: Text(
                                  day.substring(0, 3),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color:
                                        _selectedDays.contains(day)
                                            ? Colors.white
                                            : Colors.black,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          selected: _selectedDays.contains(day),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedDays.add(day);
                              } else {
                                _selectedDays.remove(day);
                              }
                            });
                          },
                          selectedColor: Colors.black,
                          backgroundColor: Colors.grey[100],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Card Color:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<Color>(
                    value:
                        colorOptions.contains(_selectedColor)
                            ? _selectedColor
                            : colorOptions.first,
                    borderRadius: BorderRadius.circular(12),
                    dropdownColor: Colors.white,
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
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.black,
                      size: 20,
                    ),
                    label: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      elevation: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(
                      Icons.check,
                      color: Colors.black,
                      size: 20,
                    ),
                    label: const Text(
                      'Save',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 12,
                      ),
                      elevation: 2,
                    ),
                    onPressed: _submit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  final colorOptions = <Color>[
    Colors.orangeAccent,
    Colors.blueAccent,
    Colors.greenAccent,
    Colors.purpleAccent,
    Colors.redAccent,
    Colors.yellowAccent,
    const Color.fromARGB(255, 135, 206, 235), // SkyBlue
    const Color.fromARGB(255, 255, 127, 249), // Pink
    const Color.fromARGB(255, 0, 0, 0), // Black
    const Color.fromARGB(255, 255, 255, 255), // White
  ];

  final colorNames = <String>[
    'Orange',
    'Blue',
    'Green',
    'Purple',
    'Red',
    'Yellow',
    'SkyBlue',
    'Pink',
    'Black',
    'White',
  ];
}
