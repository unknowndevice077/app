import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;
  static bool _permissionsRequested = false; // ✅ Track permission requests

  static Future<void> initialize() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Singapore'));

    await _createNotificationChannel();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);
    await _requestPermissions();
    _isInitialized = true;

    if (kDebugMode) print('✅ NotificationService initialized - DEFAULT SOUND SYSTEM');
  }

  // ✅ UPDATED: Initialize additional notification channels
  static Future<void> _createNotificationChannel() async {
    if (Platform.isAndroid) {
      final android = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      // Class notifications channel
      const classChannel = AndroidNotificationChannel(
        'class_notifications',
        'Class Notifications',
        description: 'Notifications for upcoming classes',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: Color.fromARGB(255, 0, 123, 255),
      );

      // Deadline notifications channel
      const deadlineChannel = AndroidNotificationChannel(
        'deadline_notifications',
        'Deadline Notifications',
        description: 'Reminders for upcoming assignment deadlines',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: Color.fromARGB(255, 255, 152, 0),
      );

      // Exam notifications channel
      const examChannel = AndroidNotificationChannel(
        'exam_notifications',
        'Exam Notifications',
        description: 'Reminders for upcoming exams',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: Color.fromARGB(255, 159, 122, 234),
      );

      await android?.createNotificationChannel(classChannel);
      await android?.createNotificationChannel(deadlineChannel);
      await android?.createNotificationChannel(examChannel);
      
      if (kDebugMode) print('✅ All notification channels created');
    }
  }

  // ✅ FIXED: Proper permission request handling
  static Future<void> _requestPermissions() async {
    if (_permissionsRequested) return; // Prevent duplicate requests
    
    try {
      _permissionsRequested = true;
      
      if (Platform.isAndroid) {
        // ✅ Request all permissions at once to avoid conflicts
        final Map<Permission, PermissionStatus> statuses = await [
          Permission.notification,
          Permission.scheduleExactAlarm,
          Permission.ignoreBatteryOptimizations,
        ].request();

        // ✅ Log permission results
        if (kDebugMode) {
          for (final entry in statuses.entries) {
            print('📋 ${entry.key}: ${entry.value}');
          }
        }

        // ✅ Handle notification permission specifically
        final notificationStatus = statuses[Permission.notification];
        if (notificationStatus != PermissionStatus.granted) {
          if (kDebugMode) print('⚠️ Notification permission not granted: $notificationStatus');
        } else {
          if (kDebugMode) print('✅ All permissions granted successfully');
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error requesting permissions: $e');
      _permissionsRequested = false; // Reset on error
    }
  }

  // ✅ NEW: Check if permissions are granted
  static Future<bool> hasNotificationPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      return status == PermissionStatus.granted;
    }
    return true; // iOS handles permissions differently
  }

  // ✅ NEW: Request permissions with better error handling
  static Future<bool> requestNotificationPermission() async {
    if (_permissionsRequested) {
      // Check current status instead of requesting again
      return await hasNotificationPermission();
    }

    try {
      _permissionsRequested = true;
      
      if (Platform.isAndroid) {
        final status = await Permission.notification.request();
        
        if (status == PermissionStatus.denied) {
          if (kDebugMode) print('🚫 Notification permission denied');
          return false;
        } else if (status == PermissionStatus.permanentlyDenied) {
          if (kDebugMode) print('🚫 Notification permission permanently denied - open settings');
          await openAppSettings();
          return false;
        }
        
        if (kDebugMode) print('✅ Notification permission granted');
        return true;
      }
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Error requesting notification permission: $e');
      _permissionsRequested = false;
      return false;
    }
  }

  // Update the scheduleDeadlineAndExamNotifications method:

  static Future<void> scheduleDeadlineAndExamNotifications() async {
    if (!_isInitialized) await initialize();
    
    // Check permissions before scheduling
    final hasPermission = await hasNotificationPermission();
    if (!hasPermission) {
      if (kDebugMode) print('❌ No notification permission - requesting...');
      final granted = await requestNotificationPermission();
      if (!granted) {
        if (kDebugMode) print('❌ Cannot schedule deadline/exam notifications without permission');
        return;
      }
    }
    
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      if (kDebugMode) print('❌ No user logged in');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

    if (!notificationsEnabled) {
      if (kDebugMode) print('🔕 Deadline/exam notifications disabled');
      return;
    }

    try {
      await _scheduleDeadlineNotifications(currentUserId);
      await _scheduleExamNotifications(currentUserId);
      
      if (kDebugMode) print('✅ Deadline and exam notifications scheduled successfully');
    } catch (e) {
      if (kDebugMode) print('❌ Error scheduling deadline/exam notifications: $e');
    }
  }

  // Update the deadline notifications to notify one day before AND on due day:

  static Future<void> _scheduleDeadlineNotifications(String userId) async {
    try {
      final classSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('Classes')
          .get();

      int scheduledCount = 0;

      for (final classDoc in classSnapshot.docs) {
        final className = classDoc.data()['title'] ?? 'Unknown Class';
        
        // Get deadlines for this class
        final deadlineSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('Classes')
            .doc(classDoc.id)
            .collection('deadlines')
            .where('date', isGreaterThan: DateTime.now())
            .get();

        for (final deadlineDoc in deadlineSnapshot.docs) {
          final deadlineData = deadlineDoc.data();
          final title = deadlineData['title'] ?? 'Assignment';
          final description = deadlineData['description'] ?? '';
          final dueDate = (deadlineData['date'] as Timestamp).toDate();
          final priority = deadlineData['priority'] ?? 'medium';
          
          // ✅ FIXED: Call with correct parameters
          final oneDayBeforeTime = DateTime(
            dueDate.year,
            dueDate.month,
            dueDate.day - 1,
            9, // 9 AM
            0,
          );

          if (oneDayBeforeTime.isAfter(DateTime.now())) {
            await _scheduleDeadlineNotification(
              deadlineId: '${deadlineDoc.id}_day_before',
              title: title,
              className: className,
              description: description,
              dueDate: dueDate,
              priority: priority,
              notificationTime: oneDayBeforeTime,
              isOnDueDay: false, // ✅ FIXED: Added missing parameter
            );
            scheduledCount++;
          }

          // ✅ FIXED: On due day notification
          final dueDayTime = DateTime(
            dueDate.year,
            dueDate.month,
            dueDate.day,
            8, // 8 AM
            0,
          );

          if (dueDayTime.isAfter(DateTime.now())) {
            await _scheduleDeadlineNotification(
              deadlineId: '${deadlineDoc.id}_due_day',
              title: title,
              className: className,
              description: description,
              dueDate: dueDate,
              priority: priority,
              notificationTime: dueDayTime,
              isOnDueDay: true, // ✅ FIXED: Added missing parameter
            );
            scheduledCount++;
          }
        }
      }

      if (kDebugMode) print('📋 Scheduled $scheduledCount deadline notifications');
    } catch (e) {
      if (kDebugMode) print('❌ Error scheduling deadline notifications: $e');
    }
  }

  // Update the exam notifications to notify one day before AND on exam day:

  static Future<void> _scheduleExamNotifications(String userId) async {
    try {
      // Get all classes to check for exams
      final classSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('Classes')
          .get();

      int scheduledCount = 0;

      for (final classDoc in classSnapshot.docs) {
        final className = classDoc.data()['title'] ?? 'Unknown Class';
        
        // Get exams for this class
        final examSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('Classes')
            .doc(classDoc.id)
            .collection('exams')
            .where('date', isGreaterThan: DateTime.now())
            .get();

        for (final examDoc in examSnapshot.docs) {
          final examData = examDoc.data();
          final title = examData['title'] ?? 'Exam';
          final description = examData['description'] ?? '';
          final examDate = (examData['date'] as Timestamp).toDate();
          final location = examData['location'] ?? '';
          final duration = examData['duration'] ?? '';
          
          // ✅ FIXED: One day before notification
          final oneDayBeforeTime = DateTime(
            examDate.year,
            examDate.month,
            examDate.day - 1,
            19, // 7 PM
            0,
          );

          if (oneDayBeforeTime.isAfter(DateTime.now())) {
            await _scheduleExamNotification(
              examId: '${examDoc.id}_day_before',
              title: title,
              className: className,
              description: description,
              examDate: examDate,
              location: location,
              duration: duration,
              notificationTime: oneDayBeforeTime,
              isOnExamDay: false, // ✅ FIXED: Added missing parameter
            );
            scheduledCount++;
          }

          // ✅ FIXED: On exam day notification
          final examDayTime = DateTime(
            examDate.year,
            examDate.month,
            examDate.day,
            7, // 7 AM
            0,
          );

          if (examDayTime.isAfter(DateTime.now())) {
            await _scheduleExamNotification(
              examId: '${examDoc.id}_exam_day',
              title: title,
              className: className,
              description: description,
              examDate: examDate,
              location: location,
              duration: duration,
              notificationTime: examDayTime,
              isOnExamDay: true, // ✅ FIXED: Added missing parameter
            );
            scheduledCount++;
          }
        }
      }

      if (kDebugMode) print('🎓 Scheduled $scheduledCount exam notifications');
    } catch (e) {
      if (kDebugMode) print('❌ Error scheduling exam notifications: $e');
    }
  }

  // Remove the duplicate _scheduleDeadlineNotification method and keep only this one:

  static Future<void> _scheduleDeadlineNotification({
    required String deadlineId,
    required String title,
    required String className,
    required String description,
    required DateTime dueDate,
    required String priority,
    required DateTime notificationTime,
    required bool isOnDueDay, // ✅ REQUIRED parameter
  }) async {
    final scheduledTime = tz.TZDateTime.from(notificationTime, tz.local);
    final notificationId = 'deadline_${deadlineId}_reminder'.hashCode;

    // Modern priority styling
    String priorityEmoji = '📝';
    Color priorityColor = const Color(0xFF059669);
    String priorityText = isOnDueDay ? 'Due Today!' : 'Due Tomorrow';
    
    switch (priority.toLowerCase()) {
      case 'high':
        priorityEmoji = '🚨';
        priorityColor = const Color(0xFFDC2626);
        priorityText = isOnDueDay ? 'URGENT - Due Today!' : 'Urgent - Due Tomorrow';
        break;
      case 'medium':
        priorityEmoji = '⚡';
        priorityColor = const Color(0xFFEA580C);
        priorityText = isOnDueDay ? 'Important - Due Today!' : 'Important - Due Tomorrow';
        break;
      case 'low':
        priorityEmoji = '📋';
        priorityColor = const Color(0xFF2563EB);
        priorityText = isOnDueDay ? 'Due Today' : 'Due Tomorrow';
        break;
    }

    final formattedDueDate = _formatDateTime(dueDate);
    
    String notificationTitle = '$priorityEmoji Assignment $priorityText';
    String notificationBody = '📚 $title\n'
        '🎓 Class: $className\n'
        '⏰ ${isOnDueDay ? "Due today" : "Due tomorrow"}: $formattedDueDate';
    
    if (description.isNotEmpty) {
      notificationBody += '\n📄 $description';
    }

    try {
      await _notifications.zonedSchedule(
        notificationId,
        notificationTitle,
        notificationBody,
        scheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'deadline_notifications',
            'Assignment Deadlines',
            channelDescription: 'Smart reminders for assignment deadlines',
            importance: Importance.max,
            priority: Priority.max,
            icon: '@mipmap/ic_launcher',
            largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            enableVibration: true,
            playSound: true,
            autoCancel: false,
            category: AndroidNotificationCategory.reminder,
            fullScreenIntent: isOnDueDay || priority.toLowerCase() == 'high',
            visibility: NotificationVisibility.public,
            color: priorityColor,
            colorized: true,
            showWhen: true,
            when: dueDate.millisecondsSinceEpoch,
            usesChronometer: false,
            styleInformation: BigTextStyleInformation(
              notificationBody,
              contentTitle: notificationTitle,
              summaryText: isOnDueDay ? 'Due today • $className' : 'Assignment reminder • $className',
              htmlFormatContent: true,
              htmlFormatTitle: true,
            ),
            actions: [
              AndroidNotificationAction(
                'start_work',
                isOnDueDay ? 'Work Now!' : 'Start Working',
                icon: DrawableResourceAndroidBitmap('@mipmap/ic_edit'),
                contextual: true,
                titleColor: priorityColor,
              ),
              AndroidNotificationAction(
                'mark_complete',
                'Mark Done',
                icon: DrawableResourceAndroidBitmap('@mipmap/ic_check'),
                titleColor: const Color(0xFF059669),
              ),
              AndroidNotificationAction(
                'set_reminder',
                isOnDueDay ? 'Remind in 1hr' : 'Remind Later',
                icon: DrawableResourceAndroidBitmap('@mipmap/ic_schedule'),
                titleColor: const Color(0xFF6B7280),
              ),
            ],
            groupKey: 'deadline_notifications',
            setAsGroupSummary: false,
            groupAlertBehavior: GroupAlertBehavior.children,
          ),
          iOS: DarwinNotificationDetails(
            categoryIdentifier: 'deadline_category',
            subtitle: '📚 $className',
            threadIdentifier: 'deadline_notifications',
            sound: 'default',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            badgeNumber: 1,
            interruptionLevel: (isOnDueDay || priority.toLowerCase() == 'high') 
                ? InterruptionLevel.critical 
                : InterruptionLevel.active,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );

      if (kDebugMode) {
        print('📋 Modern deadline notification: $title');
        print('   Timing: ${isOnDueDay ? "Due day" : "Day before"} ($priorityText)');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error scheduling modern deadline notification: $e');
    }
  }

  // Update the test methods to include the required parameters:

  static Future<void> testDeadlineNotification() async {
    if (!_isInitialized) await initialize();
    
    final hasPermission = await hasNotificationPermission();
    if (!hasPermission) {
      if (kDebugMode) print('❌ No notification permission for test');
      return;
    }
    
    final testTime = DateTime.now().add(const Duration(seconds: 5));
    final dueTime = DateTime.now().add(const Duration(days: 1));
    
    await _scheduleDeadlineNotification(
      deadlineId: 'test_deadline_modern',
      title: 'Modern UI Design Project',
      className: 'Advanced Flutter Development',
      description: 'Create a beautiful, responsive mobile app',
      dueDate: dueTime,
      priority: 'high',
      notificationTime: testTime,
      isOnDueDay: false, // ✅ FIXED: Added missing parameter
    );
    
    if (kDebugMode) print('🧪 Modern deadline notification test scheduled');
  }

  static Future<void> testExamNotification() async {
    if (!_isInitialized) await initialize();
    
    final hasPermission = await hasNotificationPermission();
    if (!hasPermission) {
      if (kDebugMode) print('❌ No notification permission for test');
      return;
    }
    
    final testTime = DateTime.now().add(const Duration(seconds: 10));
    final examTime = DateTime.now().add(const Duration(days: 1));
    
    await _scheduleExamNotification(
      examId: 'test_exam_modern',
      title: 'Advanced Mobile Development Final',
      className: 'Flutter & Dart Mastery',
      description: 'Comprehensive exam covering state management',
      examDate: examTime,
      location: 'Innovation Lab, Tech Building',
      duration: '3 hours',
      notificationTime: testTime,
      isOnExamDay: false, // ✅ FIXED: Added missing parameter
    );
    
    if (kDebugMode) print('🧪 Modern exam notification test scheduled');
  }

  // Helper method to format DateTime as a readable string
  static String _formatDateTime(DateTime dateTime) {
    // Example: "Wed, 24 Apr 2024, 5:30 PM"
    final weekDay = [
      'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
    ][dateTime.weekday - 1];
    final month = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ][dateTime.month - 1];
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final ampm = dateTime.hour >= 12 ? 'PM' : 'AM';
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$weekDay, ${dateTime.day} $month ${dateTime.year}, $hour:$minute $ampm';
  }

  // Define the missing _scheduleExamNotification method
  static Future<void> _scheduleExamNotification({
    required String examId,
    required String title,
    required String className,
    required String description,
    required DateTime examDate,
    required String location,
    required String duration,
    required DateTime notificationTime,
    required bool isOnExamDay,
  }) async {
    final scheduledTime = tz.TZDateTime.from(notificationTime, tz.local);
    final notificationId = 'exam_${examId}_reminder'.hashCode;

    String notificationTitle = isOnExamDay ? '🎓 Exam Today!' : '🕑 Exam Tomorrow';
    String notificationBody = '📚 $title\n'
        '🎓 Class: $className\n'
        '📍 Location: $location\n'
        '⏰ ${isOnExamDay ? "Today" : "Tomorrow"}: ${_formatDateTime(examDate)}\n'
        '🕒 Duration: $duration';
    if (description.isNotEmpty) {
      notificationBody += '\n📄 $description';
    }

    try {
      await _notifications.zonedSchedule(
        notificationId,
        notificationTitle,
        notificationBody,
        scheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'exam_notifications',
            'Exam Notifications',
            channelDescription: 'Reminders for upcoming exams',
            importance: Importance.max,
            priority: Priority.max,
            icon: '@mipmap/ic_launcher',
            largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            enableVibration: true,
            playSound: true,
            autoCancel: false,
            category: AndroidNotificationCategory.reminder,
            fullScreenIntent: isOnExamDay,
            visibility: NotificationVisibility.public,
            color: const Color(0xFF9F7AEA),
            colorized: true,
            showWhen: true,
            when: examDate.millisecondsSinceEpoch,
            usesChronometer: false,
            styleInformation: BigTextStyleInformation(
              notificationBody,
              contentTitle: notificationTitle,
              summaryText: isOnExamDay ? 'Exam today • $className' : 'Exam reminder • $className',
              htmlFormatContent: true,
              htmlFormatTitle: true,
            ),
            actions: [
              AndroidNotificationAction(
                'view_details',
                'View Details',
                icon: DrawableResourceAndroidBitmap('@mipmap/ic_info'),
                titleColor: const Color(0xFF9F7AEA),
              ),
              AndroidNotificationAction(
                'set_reminder',
                isOnExamDay ? 'Remind in 1hr' : 'Remind Later',
                icon: DrawableResourceAndroidBitmap('@mipmap/ic_schedule'),
                titleColor: const Color(0xFF6B7280),
              ),
            ],
            groupKey: 'exam_notifications',
            setAsGroupSummary: false,
            groupAlertBehavior: GroupAlertBehavior.children,
          ),
          iOS: DarwinNotificationDetails(
            categoryIdentifier: 'exam_category',
            subtitle: '📚 $className',
            threadIdentifier: 'exam_notifications',
            sound: 'default',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            badgeNumber: 1,
            interruptionLevel: isOnExamDay
                ? InterruptionLevel.critical
                : InterruptionLevel.active,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );

      if (kDebugMode) {
        print('🎓 Exam notification: $title');
        print('   Timing: ${isOnExamDay ? "Exam day" : "Day before"}');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error scheduling exam notification: $e');
    }
  }

  // Add these methods to the NotificationService class:

  // ✅ Master method to schedule all notification types
  static Future<void> scheduleAllNotifications() async {
    if (!_isInitialized) await initialize();
    
    // Check permissions before scheduling
    final hasPermission = await hasNotificationPermission();
    if (!hasPermission) {
      if (kDebugMode) print('❌ No notification permission - requesting...');
      final granted = await requestNotificationPermission();
      if (!granted) {
        if (kDebugMode) print('❌ Cannot schedule notifications without permission');
        return;
      }
    }

    // Cancel all existing notifications first
    await _notifications.cancelAll();
    
    try {
      // Schedule all types of notifications
      await scheduleAllClassNotifications();
      await scheduleDeadlineAndExamNotifications();
      
      if (kDebugMode) print('✅ All notification types scheduled successfully');
    } catch (e) {
      if (kDebugMode) print('❌ Error scheduling all notifications: $e');
    }
  }

  // ✅ Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
      if (kDebugMode) print('✅ All notifications cancelled');
    } catch (e) {
      if (kDebugMode) print('❌ Error canceling notifications: $e');
    }
  }

  // ✅ Check if notifications are enabled in SharedPreferences
  static Future<bool> areNotificationsEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('notifications_enabled') ?? true;
    } catch (e) {
      if (kDebugMode) print('❌ Error checking notification settings: $e');
      return true; // Default to enabled
    }
  }

  // ✅ Update the existing scheduleAllClassNotifications to check settings
  static Future<void> scheduleAllClassNotifications() async {
    if (!_isInitialized) await initialize();
    
    // Check if notifications are enabled
    final notificationsEnabled = await areNotificationsEnabled();
    if (!notificationsEnabled) {
      if (kDebugMode) print('🔕 Class notifications disabled in settings');
      return;
    }
    
    // Check permissions before scheduling
    final hasPermission = await hasNotificationPermission();
    if (!hasPermission) {
      if (kDebugMode) print('❌ No notification permission - requesting...');
      final granted = await requestNotificationPermission();
      if (!granted) {
        if (kDebugMode) print('❌ Cannot schedule notifications without permission');
        return;
      }
    }
    
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      if (kDebugMode) print('❌ No user logged in');
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('Classes')
          .where('notify', isEqualTo: true)
          .get();

      int scheduledCount = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final className = data['title'] ?? 'Unknown Class';
        final time = data['time'] ?? '';
        final teacher = data['teacher'] ?? '';
        final location = data['location'] ?? '';
        final days = List<String>.from(data['days'] ?? []);

        for (final day in days) {
          final classDateTime = _getNextClassDateTime(day, time);
          if (classDateTime != null && classDateTime.isAfter(DateTime.now())) {
            
            // ✅ 10-minute reminder (ONLY for classes)
            final reminderTime = classDateTime.subtract(const Duration(minutes: 10));
            if (reminderTime.isAfter(DateTime.now())) {
              await _scheduleNotification(
                className: className,
                classDateTime: reminderTime,
                isReminder: true,
                teacher: teacher,
                location: location,
              );
              scheduledCount++;
            }

            // ✅ Start notification (ONLY for classes)
            await _scheduleNotification(
              className: className,
              classDateTime: classDateTime,
              isReminder: false,
              teacher: teacher,
              location: location,
            );
            scheduledCount++;
          }
        }
      }

      if (kDebugMode) print('✅ Scheduled $scheduledCount class notifications (10min before + during)');
    } catch (e) {
      if (kDebugMode) print('❌ Error scheduling class notifications: $e');
    }
  }

  // Add these missing methods to the NotificationService class:

  // Helper method to get next class date/time
  static DateTime? _getNextClassDateTime(String day, String time) {
    if (time.isEmpty) return null;
    
    try {
      // Parse time (e.g., "9:00 AM" or "14:30")
      final timeParts = time.toLowerCase().replaceAll(' ', '');
      bool isPM = timeParts.contains('pm');
      bool isAM = timeParts.contains('am');
      
      String timeOnly = timeParts.replaceAll('am', '').replaceAll('pm', '');
      final parts = timeOnly.split(':');
      
      if (parts.length != 2) return null;
      
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);
      
      // Convert to 24-hour format
      if (isPM && hour != 12) hour += 12;
      if (isAM && hour == 12) hour = 0;
      
      // Get next occurrence of this day
      final now = DateTime.now();
      final dayIndex = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']
          .indexOf(day.toLowerCase());
      
      if (dayIndex == -1) return null;
      
      // Calculate days until next occurrence
      final currentDayIndex = now.weekday - 1; // Monday = 0
      int daysUntil = (dayIndex - currentDayIndex) % 7;
      
      if (daysUntil == 0) {
        // Same day - check if time has passed
        final todayClassTime = DateTime(now.year, now.month, now.day, hour, minute);
        if (todayClassTime.isBefore(now)) {
          daysUntil = 7; // Next week
        }
      }
      
      final classDate = now.add(Duration(days: daysUntil));
      return DateTime(classDate.year, classDate.month, classDate.day, hour, minute);
    } catch (e) {
      if (kDebugMode) print('❌ Error parsing class time: $e');
      return null;
    }
  }

  // Schedule individual class notification
  static Future<void> _scheduleNotification({
    required String className,
    required DateTime classDateTime,
    required bool isReminder,
    required String teacher,
    required String location,
  }) async {
    final scheduledTime = tz.TZDateTime.from(classDateTime, tz.local);
    final notificationId = isReminder 
        ? '${className}_${classDateTime.day}_reminder'.hashCode 
        : '${className}_${classDateTime.day}_start'.hashCode;

    String title = isReminder ? '🔔 Class Reminder' : '🎓 Class Starting';
    String body = isReminder 
        ? '$className starts in 10 minutes!' 
        : '$className is starting now!';
    
    if (teacher.isNotEmpty) body += '\n👨‍🏫 $teacher';
    if (location.isNotEmpty) body += '\n📍 $location';

    try {
      await _notifications.zonedSchedule(
        notificationId,
        title,
        body,
        scheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'class_notifications',
            'Class Notifications',
            channelDescription: 'Smart reminders for your classes',
            importance: Importance.max,
            priority: Priority.max,
            icon: '@mipmap/ic_launcher',
            largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            enableVibration: true,
            playSound: true,
            autoCancel: false,
            category: AndroidNotificationCategory.alarm,
            fullScreenIntent: isReminder ? false : true,
            visibility: NotificationVisibility.public,
            color: const Color(0xFF4F46E5),
            colorized: true,
            showWhen: true,
            when: classDateTime.millisecondsSinceEpoch,
            usesChronometer: false,
            styleInformation: BigTextStyleInformation(
              body,
              contentTitle: title,
              summaryText: isReminder ? 'Upcoming class' : 'Class in session',
              htmlFormatContent: true,
              htmlFormatTitle: true,
            ),
          ),
          iOS: DarwinNotificationDetails(
            categoryIdentifier: 'class_category',
            subtitle: '📚 $className',
            threadIdentifier: 'class_notifications',
            sound: 'default',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            badgeNumber: 1,
            interruptionLevel: isReminder 
                ? InterruptionLevel.active 
                : InterruptionLevel.timeSensitive,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );

      if (kDebugMode) {
        print('📅 ${isReminder ? 'Reminder' : 'Start'} notification for $className');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error scheduling notification: $e');
    }
  }

  // Test background notification
  static Future<void> testBackgroundNotification() async {
    if (!_isInitialized) await initialize();
    
    final hasPermission = await hasNotificationPermission();
    if (!hasPermission) {
      if (kDebugMode) print('❌ No notification permission for test');
      final granted = await requestNotificationPermission();
      if (!granted) {
        if (kDebugMode) print('❌ Test cancelled - no permission');
        return;
      }
    }
    
    final testTime = DateTime.now().add(const Duration(seconds: 10));
    final scheduledTime = tz.TZDateTime.from(testTime, tz.local);

    if (kDebugMode) {
      print('🧪 TEST NOTIFICATION:');
      print('   Scheduled for: $scheduledTime');
    }

    try {
      await _notifications.zonedSchedule(
        99999,
        '🎨 Test Notification',
        '✨ This is a test notification!\n\nIf you see this, notifications are working perfectly!',
        scheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'class_notifications',
            'Test Notifications',
            importance: Importance.max,
            priority: Priority.max,
            icon: '@mipmap/ic_launcher',
            largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            enableVibration: true,
            playSound: true,
            autoCancel: false,
            category: AndroidNotificationCategory.status,
            fullScreenIntent: false,
            visibility: NotificationVisibility.public,
            color: const Color(0xFF06B6D4),
            colorized: true,
            showWhen: true,
            usesChronometer: false,
            styleInformation: BigTextStyleInformation(
              '✨ This is a test notification!\n\n'
              '🎯 Features:\n'
              '• Beautiful colors\n'
              '• Interactive design\n'
              '• Smart content styling\n'
              '• Perfect timing\n\n'
              '🚀 Your notifications are working!',
              contentTitle: '🎨 Test Notification',
              summaryText: 'Test successful',
              htmlFormatContent: true,
              htmlFormatTitle: true,
            ),
          ),
          iOS: DarwinNotificationDetails(
            categoryIdentifier: 'test_category',
            subtitle: '🧪 Testing',
            threadIdentifier: 'test_notifications',
            sound: 'default',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            badgeNumber: 1,
            interruptionLevel: InterruptionLevel.active,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );

      if (kDebugMode) print('✅ Test notification scheduled successfully');
    } catch (e) {
      if (kDebugMode) print('❌ Test notification failed: $e');
    }
  }
}