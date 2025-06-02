import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'package:flutter/services.dart'; // ✅ ADD: For Clipboard functionality
// import 'package:app/debug/notification_service_debug_page.dart'; // ✅ ADD: If using debug page option
import 'package:app/services/notification_test_page.dart'; // ✅ ADD: Import the test page

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

class _ClassesState extends State<Classes> with WidgetsBindingObserver {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  Timer? _notificationRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationRefreshTimer?.cancel();
    super.dispose();
  }

  // ✅ ENHANCED: Better notification initialization
  Future<void> _initializeNotifications() async {
    try {
      // Initialize the notification service
      await NotificationService.initialize();
      
      // Schedule all notifications
      await NotificationService.scheduleAllNotifications();
      
      if (kDebugMode) {
        print('✅ Classes page: Notifications initialized and scheduled');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Classes page: Error initializing notifications: $e');
      }
    }
  }

  // ✅ ENHANCED: Handle app lifecycle changes for background notifications
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        // App came to foreground - refresh notifications
        _updateClassNotifications();
        break;
      case AppLifecycleState.paused:
        // App going to background - ensure notifications are scheduled
        _updateClassNotifications();
        break;
      case AppLifecycleState.detached:
        // App is being terminated - final notification update
        _updateClassNotifications();
        break;
      default:
        break;
    }
  }

  // ✅ ENHANCED: Better notification updating
  Future<void> _updateClassNotifications() async {
    try {
      // Always reschedule all notifications to ensure they're up to date
      await NotificationService.scheduleAllNotifications();
      
      if (kDebugMode) {
        print('✅ Class notifications updated successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating notifications: $e');
      }
    }
  }

  // Add class
  Future<void> _addClass(Map<String, dynamic> classData) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('Classes')
          .add(classData);
      
      if (kDebugMode) {
        print('✅ Class added successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error adding class: $e');
      }
      rethrow; // Re-throw to handle in calling method
    }
  }

  // Delete class
  Future<void> _deleteClass(String docId) async {
    // Show confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Class',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete this class? This will also remove all associated notifications.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Delete from Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('Classes')
          .doc(docId)
          .delete();
      
      // ✅ IMMEDIATE: Update notifications after deletion
      await Future.delayed(const Duration(milliseconds: 300)); // Small delay for Firestore sync
      await _updateClassNotifications();
      
      if (mounted) {
        setState(() {});
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.delete_forever, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Class deleted successfully',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Notifications cancelled',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting class: $e');
      }
      
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
      
      try {
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
        
        // ✅ IMMEDIATE: Update notifications right after saving
        await Future.delayed(const Duration(milliseconds: 500)); // Small delay for Firestore sync
        await _updateClassNotifications();
        
        if (mounted) {
          setState(() {});
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          docId != null 
                              ? 'Class updated successfully'
                              : 'Class added successfully',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Notifications scheduled',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error saving class: $e');
        }
        
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

  // ✅ KEEP: Notification settings method
  void _showNotificationSettings() async {
    try {
      final isEnabled = await NotificationService.areNotificationsEnabled();

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Notification Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Enable Class Notifications'),
                subtitle: const Text('Get notified before your classes start'),
                value: isEnabled,
                onChanged: (value) async {
                  try {
                    // Only schedule notifications if enabling
                    if (value) {
                      await NotificationService.scheduleAllNotifications();
                    }
                    if (mounted) {
                      Navigator.pop(context);
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            value
                                ? 'Notifications enabled successfully'
                                : 'Notifications disabled (disable not implemented)',
                          ),
                          backgroundColor: value ? Colors.green : Colors.orange,
                        ),
                      );
                    }
                  } catch (e) {
                    if (kDebugMode) {
                      print('❌ Error toggling notifications: $e');
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await NotificationService.testClassStartingNotification();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Test notification sent!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (kDebugMode) {
                      print('❌ Error sending test notification: $e');
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Test failed: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Test Notification'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error showing notification settings: $e');
      }
    }
  }

  // Handler for toggling notification for a class
  Future<void> _handleNotificationToggle(String docId, bool notify) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('Classes')
          .doc(docId)
          .update({'notify': notify});
      await Future.delayed(const Duration(milliseconds: 300));
      await _updateClassNotifications();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  notify ? Icons.notifications_active : Icons.notifications_off,
                  color: Colors.white,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    notify
                        ? 'Notifications enabled for this class'
                        : 'Notifications disabled for this class',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: notify ? Colors.green.shade600 : Colors.orange.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error toggling notification: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error toggling notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
          // ✅ FIXED: Navigate to notification_service.dart when bell icon is clicked
          FutureBuilder<bool>(
            future: NotificationService.areNotificationsEnabled(),
            builder: (context, snapshot) {
              final isEnabled = snapshot.data ?? true;
              return IconButton(
                icon: Icon(
                  isEnabled
                      ? Icons.notifications_outlined
                      : Icons.notifications_off_outlined,
                  color: isEnabled ? Colors.black : Colors.grey[600],
                ),
                tooltip: 'Notifications & Background Test',
                onPressed: () {
                  // ✅ Navigate to the background test page
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationTestPage(),
                    ),
                  );
                },
              );
            },
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

          // ✅ UPDATE: Use the new notification toggle handler
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
                onToggleNotify: (notify) => _handleNotificationToggle(doc.id, notify),
              );
            },
          );
        },
      ),
    );
  }

  // ✅ FIXED: Navigate to notification_service.dart when bell icon is clicked
  void _openNotificationServiceFile() {
    // This will open the file in VS Code if you're running in debug mode
    if (kDebugMode) {
      print('📁 Opening notification_service.dart...');
      print('🔧 File path: lib/services/notification_service.dart');
      
      // Show a dialog with file navigation options
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.code, color: Colors.blue.shade600),
              const SizedBox(width: 12),
              Text(
                'Open File',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Navigate to notification_service.dart',
                style: GoogleFonts.inter(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SelectableText(
                  'lib/services/notification_service.dart',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'VS Code Commands:',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              _buildCommandItem('Ctrl+P', 'Quick Open'),
              _buildCommandItem('Ctrl+Shift+E', 'File Explorer'),
              _buildCommandItem('Ctrl+T', 'Go to Symbol'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: GoogleFonts.inter(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                // Copy file path to clipboard
                Clipboard.setData(const ClipboardData(
                  text: 'lib/services/notification_service.dart'
                ));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.copy, color: Colors.white),
                        const SizedBox(width: 12),
                        Text(
                          'File path copied to clipboard!',
                          style: GoogleFonts.inter(color: Colors.white),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.green.shade600,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.copy, size: 16),
              label: Text(
                'Copy Path',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }
  }

  // ✅ ADD: Helper method for command items
  Widget _buildCommandItem(String shortcut, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: Text(
              shortcut,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            description,
            style: GoogleFonts.inter(fontSize: 13),
          ),
        ],
      ),
    );
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

  // ✅ UPDATED: Better color logic for white/black cards
  Color get _textColor {
    // Handle pure white
    if (widget.classModel.color.value == Colors.white.value ||
        widget.classModel.color.value == const Color.fromARGB(255, 255, 255, 255).value) {
      return Colors.black;
    }
    // Handle pure black
    if (widget.classModel.color.value == Colors.black.value ||
        widget.classModel.color.value == const Color.fromARGB(255, 0, 0, 0).value) {
      return Colors.white;
    }
    // For other colors, use brightness detection
    return ThemeData.estimateBrightnessForColor(widget.classModel.color) == Brightness.light
        ? Colors.black
        : Colors.white;
  }

  Color get _iconColor {
    // Same logic as text color
    return _textColor;
  }

  @override
  Widget build(BuildContext context) {
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
                      color: _textColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
                Row(
                  children: [
                    // Notification bell
                    IconButton(
                      icon: Icon(
                        widget.classModel.notify
                            ? Icons.notifications_active
                            : Icons.notifications_off,
                        color: _iconColor,
                      ),
                      tooltip: widget.classModel.notify
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
            
            // ✅ NEW: Days of the week display
            if (widget.classModel.days.isNotEmpty) ...[
              Row(
                children: [
                  Icon(
                    CupertinoIcons.calendar,
                    size: 18,
                    color: _iconColor.withOpacity(0.7),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: DayHelper.sortDays(widget.classModel.days).map((day) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _textColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _textColor.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            DayHelper.getAbbreviation(day),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _textColor,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            
            // Time display
            Row(
              children: [
                Icon(
                  CupertinoIcons.time,
                  size: 18,
                  color: _iconColor.withOpacity(0.7),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    widget.classModel.time,
                    style: GoogleFonts.roboto(
                      color: _textColor.withOpacity(0.7),
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            // Teacher display
            Row(
              children: [
                Icon(
                  CupertinoIcons.person,
                  size: 18,
                  color: _iconColor.withOpacity(0.7),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    widget.classModel.teacher,
                    style: GoogleFonts.roboto(
                      color: _textColor,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            // Location display
            Row(
              children: [
                Icon(
                  CupertinoIcons.location,
                  size: 18,
                  color: _iconColor.withOpacity(0.7),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    widget.classModel.location,
                    style: GoogleFonts.roboto(
                      color: _textColor,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            // Expanded content (notes)
            if (_isExpanded) ...[
              const SizedBox(height: 16),
              Divider(
                color: _textColor.withOpacity(0.2),
              ),
              const SizedBox(height: 8),
              Text(
                widget.classModel.notes.isNotEmpty
                    ? widget.classModel.notes
                    : 'No notes for this class.',
                style: GoogleFonts.roboto(
                  color: _textColor.withOpacity(0.8),
                  fontSize: 15,
                  fontStyle: widget.classModel.notes.isEmpty
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
  
  // ✅ ADD: ScrollController for auto-scrolling to errors
  final ScrollController _scrollController = ScrollController();
  
  // ✅ ADD: Global keys for error navigation
  final GlobalKey _titleKey = GlobalKey();
  final GlobalKey _timeKey = GlobalKey();
  final GlobalKey _locationKey = GlobalKey();
  final GlobalKey _teacherKey = GlobalKey();

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
    
    // ✅ FIXED: Proper color initialization with persistence
    _selectedColor = widget.existing?.color ?? colorOptions[0]; // Default to first color if new

    // Parse times if editing
    String time = widget.existing?.time ?? '';
    List<String> times = time.split(' - ');
    _startTime = times.isNotEmpty && times[0].trim().isNotEmpty
        ? _parseTimeOfDay(times[0])
        : null;
    _endTime = times.length > 1 && times[1].trim().isNotEmpty
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

  // ✅ ADD: Method to scroll to first error
  void _scrollToError() {
    GlobalKey? errorKey;
    
    // Find the first error in order
    if (_showTitleError) {
      errorKey = _titleKey;
    } else if (_showStartTimeError || _showEndTimeError) {
      errorKey = _timeKey;
    } else if (_showRoomError) {
      errorKey = _locationKey;
    } else if (_showTeacherError) {
      errorKey = _teacherKey;
    }
    
    // Scroll to the error if found
    if (errorKey != null && errorKey.currentContext != null) {
      Scrollable.ensureVisible(
        errorKey.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.1, // Show error near top of viewport
      );
    }
  }

  // ✅ UPDATED: Enhanced submit method with error navigation
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
      
      // ✅ ADD: Show error message and scroll to first error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Please fill in all required fields',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      
      // ✅ ADD: Auto-scroll to first error after a short delay
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollToError();
      });
      
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
      notify: widget.existing?.notify ?? true,
    );
    Navigator.of(context).pop(newClass);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _teacherController.dispose();
    _notesController.dispose();
    _scrollController.dispose(); // ✅ ADD: Dispose scroll controller
    super.dispose();
  }

  // ✅ UPDATED: Build method with scroll controller and error keys
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.95,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            controller: _scrollController, // ✅ ADD: Attach scroll controller
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ✅ Enhanced Header (kept same)
                Container(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.existing == null ? Icons.add_circle_outline : Icons.edit_outlined,
                          size: 32,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.existing == null ? 'Add New Class' : 'Edit Class',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSerifText(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.existing == null 
                            ? 'Fill in the details for your new class'
                            : 'Update your class information',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // ✅ Enhanced Subject Field with error key
                Container(
                  key: _titleKey, // ✅ ADD: Key for error navigation
                  child: _buildEnhancedTextField(
                    controller: _titleController,
                    label: 'Subject',
                    hint: 'e.g. Advanced Mathematics',
                    icon: CupertinoIcons.book_solid,
                    errorText: _showTitleError ? 'Subject is required' : null,
                    iconColor: Colors.orange.shade600,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // ✅ IMPROVED: Enhanced Time Pickers Section with error key
                Container(
                  key: _timeKey, // ✅ ADD: Key for error navigation
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      // ✅ ADD: Red border if time errors
                      color: (_showStartTimeError || _showEndTimeError) 
                          ? Colors.red.shade300 
                          : Colors.grey.shade200,
                      width: (_showStartTimeError || _showEndTimeError) ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.clock_solid, 
                            color: (_showStartTimeError || _showEndTimeError) 
                                ? Colors.red.shade600 
                                : Colors.blue.shade600, 
                            size: 20
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Class Schedule',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: (_showStartTimeError || _showEndTimeError) 
                                  ? Colors.red.shade800 
                                  : Colors.grey.shade800,
                            ),
                          ),
                          // ✅ ADD: Error indicator for time section
                          if (_showStartTimeError || _showEndTimeError) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade600,
                              size: 18,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (_showStartTimeError || _showEndTimeError)
                            ? 'Both start and end times are required'
                            : 'Set the start and end times for this class',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: (_showStartTimeError || _showEndTimeError) 
                              ? Colors.red.shade600 
                              : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Time pickers (rest stays the same)
                      Column(
                        children: [
                          // Start Time
                          _buildTimePickerCard(
                            label: 'Start Time',
                            time: _startTime,
                            hint: '8:00 AM',
                            isStart: true,
                            hasError: _showStartTimeError,
                            icon: CupertinoIcons.play_circle,
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Arrow/Divider
                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.grey.shade300)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Icon(
                                  Icons.arrow_downward,
                                  color: Colors.grey.shade400,
                                  size: 20,
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.grey.shade300)),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // End Time
                          _buildTimePickerCard(
                            label: 'End Time',
                            time: _endTime,
                            hint: '9:30 AM',
                            isStart: false,
                            hasError: _showEndTimeError,
                            icon: CupertinoIcons.stop_circle,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // ✅ Enhanced Location Field with error key
                Container(
                  key: _locationKey, // ✅ ADD: Key for error navigation
                  child: _buildEnhancedTextField(
                    controller: _locationController,
                    label: 'Room/Location',
                    hint: 'e.g. Room 302, Science Building',
                    icon: CupertinoIcons.location_solid,
                    errorText: _showRoomError ? 'Room is required' : null,
                    iconColor: Colors.green.shade600,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // ✅ Enhanced Teacher Field with error key
                Container(
                  key: _teacherKey, // ✅ ADD: Key for error navigation
                  child: _buildEnhancedTextField(
                    controller: _teacherController,
                    label: 'Teacher/Instructor',
                    hint: 'e.g. Dr. Smith',
                    icon: CupertinoIcons.person_solid,
                    errorText: _showTeacherError ? 'Teacher is required' : null,
                    iconColor: Colors.purple.shade600,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // ✅ Enhanced Notes Field (no error key needed - optional field)
                _buildEnhancedTextField(
                  controller: _notesController,
                  label: 'Notes (Optional)',
                  hint: 'Additional information about this class...',
                  icon: CupertinoIcons.doc_text,
                  maxLines: 3,
                  iconColor: Colors.grey.shade600,
                ),
                
                const SizedBox(height: 24),
                
                // Days Section (rest stays the same)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(CupertinoIcons.calendar, color: Colors.blue.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Class Days',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Select the days when this class is held',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.blue.shade600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final day in [
                            'Monday',
                            'Tuesday',
                            'Wednesday',
                            'Thursday',
                            'Friday',
                            'Saturday',
                            'Sunday',
                          ])
                            _buildDayChip(day),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // ✅ IMPROVED: Enhanced Color Picker with better persistence
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.palette, color: Colors.grey.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Class Color',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose a color to identify this class',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildColorPicker(),
                    ],
                  ),
                ),
                
                const SizedBox(height: 28),
                
                // Action Buttons (stays the same)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(CupertinoIcons.xmark, size: 16),
                        label: Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          foregroundColor: Colors.grey.shade600,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _submit,
                        icon: const Icon(CupertinoIcons.check_mark, size: 16),
                        label: Text(
                          widget.existing == null ? 'Add Class' : 'Update',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ));
  }

  // Helper for enhanced text fields with icon, error, etc.
  Widget _buildEnhancedTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? errorText,
    int maxLines = 1,
    Color? iconColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.grey.shade800,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (iconColor ?? Colors.blue).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: iconColor ?? Colors.blue.shade600,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blue.shade500, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.red.shade400, width: 2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.red.shade400, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              errorText: errorText,
              errorStyle: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.red.shade600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Helper for building the time picker card
  Widget _buildTimePickerCard({
    required String label,
    required TimeOfDay? time,
    required String hint,
    required bool isStart,
    required bool hasError,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showScrollableTimePicker(isStart: isStart),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasError ? Colors.red.shade400 : Colors.grey.shade300,
                width: hasError ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: Colors.blue.shade600,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _formatTimeOfDay(time).isEmpty ? hint : _formatTimeOfDay(time),
                    style: GoogleFonts.inter(
                      fontSize: _formatTimeOfDay(time).isEmpty ? 14 : 18,
                      color: _formatTimeOfDay(time).isEmpty 
                          ? Colors.grey.shade500 
                          : Colors.grey.shade800,
                      fontWeight: _formatTimeOfDay(time).isEmpty 
                          ? FontWeight.normal 
                          : FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.access_time,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Text(
              'Required',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.red.shade600,
              ),
            ),
          ),
      ],
    );
  }

  // ✅ ADD: Missing scrollable time picker method
  void _showScrollableTimePicker({required bool isStart}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    isStart ? 'Start Time' : 'End Time',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Done',
                      style: GoogleFonts.inter(
                        color: Colors.blue.shade600,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Time Picker
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: false,
                initialDateTime: DateTime(
                  2024, 1, 1,
                  (isStart ? _startTime : _endTime)?.hour ?? 8,
                  _roundToNearestInterval((isStart ? _startTime : _endTime)?.minute ?? 0, 10),
                ),
                minuteInterval: 10,
                onDateTimeChanged: (DateTime newDateTime) {
                  final newTime = TimeOfDay.fromDateTime(newDateTime);
                  setState(() {
                    if (isStart) {
                      _startTime = newTime;
                    } else {
                      _endTime = newTime;
                    }
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add this helper method to round minutes to the nearest interval
  int _roundToNearestInterval(int minutes, int interval) {
    return (minutes / interval).round() * interval;
  }

  // ✅ IMPROVED: Updated day chip with better sizing
  Widget _buildDayChip(String day) {
    final isSelected = _selectedDays.contains(day);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedDays.remove(day);
          } else {
            _selectedDays.add(day);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade600 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue.shade600 : Colors.blue.shade300,
            width: 1.5,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Text(
          day.substring(0, 3),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.blue.shade700,
          ),
        ),
      ),
    );
  }

  // ✅ IMPROVED: Updated color picker with better selection logic
  Widget _buildColorPicker() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: List.generate(colorOptions.length, (index) {
        final color = colorOptions[index];
        final isSelected = _selectedColor.value == color.value;
        
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedColor = color;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.grey.shade800 : Colors.grey.shade300,
                width: isSelected ? 3 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: isSelected ? 12 : 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isSelected
                ? Icon(
                    CupertinoIcons.checkmark,
                    color: color.value == Colors.white.value || 
                           color.value == const Color.fromARGB(255, 255, 255, 255).value
                        ? Colors.black
                        : Colors.white,
                    size: 20,
                  )
                : null,
          ),
        );
      }),
    );
  }
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
