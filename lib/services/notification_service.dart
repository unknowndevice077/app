import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// ✅ ADD: Import to access the global navigator
import 'package:app/main.dart' show navigatorKey;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  
  static bool _isInitialized = false;
  static bool _backgroundModeEnabled = false;
  
  // ✅ Real-time monitoring variables
  static Timer? _classMonitorTimer;
  static bool _isMonitoring = false;
  static Set<String> _notifiedClasses = <String>{};
  
  // ✅ COMPLETE: Initialize method
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Initialize timezone
      tz_data.initializeTimeZones();
      
      // Android initialization settings
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // iOS initialization settings
      const iosSettings = DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );
      
      // Combined initialization settings
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      
      // Initialize notifications plugin
      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );
      
      // Create notification channels
      await _createNotificationChannels();
      
      // Request permissions
      await _requestPermissions();
      
      _isInitialized = true;
      _backgroundModeEnabled = true;
      
      if (kDebugMode) {
        print('✅ NotificationService initialized successfully');
      }
      
    } catch (e) {
      if (kDebugMode) print('❌ NotificationService initialization failed: $e');
      throw Exception('Failed to initialize notifications: $e');
    }
  }
  
  // ✅ Notification response handler
  static void _onNotificationResponse(NotificationResponse response) {
    if (kDebugMode) {
      print('🔔 Notification tapped: ${response.payload}');
      print('🔔 Action ID: ${response.actionId}');
    }
    
    // Handle notification actions
    if (response.actionId == 'mark_attending') {
      _handleImGoingAction(response.payload);
    } else if (response.actionId == 'view_schedule') {
      _handleViewScheduleAction(response.payload);
    } else {
      // Regular notification tap (not action button)
      _handleNotificationTap(response.payload);
    }
  }
  
  // ✅ ADD: Handle "I'm Going" action
  static void _handleImGoingAction(String? payload) {
    if (kDebugMode) print('✅ User clicked "I\'m Going" - Opening app...');
    
    // Open the app to the home screen or classes page
    _openApp(targetPage: 'classes');
  }
  
  // ✅ ADD: Handle "View Schedule" action  
  static void _handleViewScheduleAction(String? payload) {
    if (kDebugMode) print('📅 User clicked "View Schedule" - Opening app...');
    
    // Open the app to the schedule/classes page
    _openApp(targetPage: 'schedule');
  }
  
  // ✅ ADD: Handle regular notification tap
  static void _handleNotificationTap(String? payload) {
    if (kDebugMode) print('📱 Notification tapped - Opening app...');
    
    // Open the app to the main page
    _openApp(targetPage: 'home');
  }
  
  // ✅ ADD: Open app with navigation
  static void _openApp({String targetPage = 'home'}) {
    try {
      // Get the global navigator key from main.dart
      final navigator = navigatorKey.currentState;
      
      if (navigator != null) {
        // Navigate to the target page
        switch (targetPage) {
          case 'classes':
            navigator.pushNamed('/classes');
            break;
          case 'schedule':
            navigator.pushNamed('/schedule');
            break;
          case 'home':
          default:
            navigator.pushNamedAndRemoveUntil('/', (route) => false);
            break;
        }
        
        if (kDebugMode) print('🚀 App opened and navigated to $targetPage');
      } else {
        if (kDebugMode) print('⚠️ Navigator not available - app may not be running');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error opening app: $e');
    }
  }
  
  // ✅ Create notification channels
  static Future<void> _createNotificationChannels() async {
    if (Platform.isAndroid) {
      final android = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      
      if (android != null) {
        const classChannel = AndroidNotificationChannel(
          'class_notifications_critical',
          'Class Starting Notifications',
          description: 'Real-time notifications when classes start',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          ledColor: Color(0xFF059669),
          showBadge: true,
        );
        
        await android.createNotificationChannel(classChannel);
        
        if (kDebugMode) print('✅ Notification channels created');
      }
    }
  }
  
  // ✅ Request permissions
  static Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final android = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      
      if (android != null) {
        await android.requestNotificationsPermission();
      }
    }
  }
  
  // ✅ Check notification permission
  static Future<bool> hasNotificationPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      return status == PermissionStatus.granted;
    }
    return true;
  }

  // ✅ ADD: Missing areNotificationsEnabled method
  static Future<bool> areNotificationsEnabled() async {
    try {
      return await hasNotificationPermission();
    } catch (e) {
      if (kDebugMode) print('❌ Error checking notification status: $e');
      return false;
    }
  }

  // ✅ Start real-time class monitoring
  static Future<void> startClassTimeMonitoring() async {
    if (!_isInitialized) await initialize();
    
    if (_isMonitoring) {
      if (kDebugMode) print('📊 Class monitoring already running');
      return;
    }
    
    try {
      _isMonitoring = true;
      
      // Check every 30 seconds for precise timing
      _classMonitorTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
        await _checkClassTimes();
      });
      
      // Initial check
      await _checkClassTimes();
      
      if (kDebugMode) {
        print('🎯 Real-time class monitoring STARTED');
        print('⏰ Checking every 30 seconds for class start times');
        print('📊 Monitoring Firestore: users/{uid}/Classes collection');
      }
      
    } catch (e) {
      _isMonitoring = false;
      if (kDebugMode) print('❌ Failed to start class monitoring: $e');
      throw Exception('Class monitoring failed to start: $e');
    }
  }
  
  // ✅ Stop monitoring
  static Future<void> stopClassTimeMonitoring() async {
    _classMonitorTimer?.cancel();
    _classMonitorTimer = null;
    _isMonitoring = false;
    _notifiedClasses.clear();
    
    if (kDebugMode) print('🛑 Class time monitoring stopped');
  }
  
  // ✅ Core monitoring function - UPDATED for Firestore
  static Future<void> _checkClassTimes() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (kDebugMode) print('⚠️ No authenticated user for class monitoring');
      return;
    }

    try {
      final now = DateTime.now();
      final currentDay = _getDayOfWeek(now.weekday);

      // Get all classes for today
      final classesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('Classes')
          .where('days', arrayContains: currentDay)
          .get();

      for (final classDoc in classesSnapshot.docs) {
        final classData = classDoc.data();
        final classTimeStr = classData['time'] as String? ?? '';
        // Example: "3:30 PM - 4:00 PM"
        final startTimeStr = classTimeStr.split('-').first.trim(); // "3:30 PM"
        final startTime = _parseTimeOfDay(startTimeStr, now);

        if (startTime == null) continue;

        final classDateTime = DateTime(
          now.year,
          now.month,
          now.day,
          startTime.hour,
          startTime.minute,
        );

        // Extract required fields
        final classId = classDoc.id;
        final className = classData['title'] as String? ?? 'Unknown Class';
        final teacher = classData['teacher'] as String? ?? ''; 
        final location = classData['location'] as String? ?? '';

        // 10-minute window before class
        final windowStart = classDateTime.subtract(const Duration(minutes: 10));
        final windowEnd = classDateTime;

        // If now is in the window, and we haven't notified for this class instance yet
        final classInstanceId = '${classId}_${now.year}${now.month}${now.day}';
        if (now.isAfter(windowStart) &&
            now.isBefore(windowEnd) &&
            !_notifiedClasses.contains(classInstanceId)) {
          _notifiedClasses.add(classInstanceId);

          await _sendClassStartingNotification(
            className: className,
            teacher: teacher,
            location: location,
            classTime: classTimeStr,
            classId: classId,
            now: now,
          );

          if (kDebugMode) {
            print('🔔 Notification sent for $className at $classTimeStr');
          }
        }
      }

      _cleanupOldNotifications(now);
    } catch (e) {
      if (kDebugMode) print('❌ Error checking class times: $e');
    }
  }
  
  // ✅ Process class starting
  static Future<void> _processClassStarting(Map<String, dynamic> classData, DateTime now) async {
    try {
      final className = classData['title'] as String? ?? 'Unknown Class';
      final classTime = classData['time'] as String? ?? '';
      final teacher = classData['teacher'] as String? ?? '';
      final location = classData['location'] as String? ?? '';
      final classId = classData['id']?.toString() ?? '';
      
      final classInstanceId = '${className}_${classTime}_${now.day}${now.month}${now.year}';
      
      if (_notifiedClasses.contains(classInstanceId)) {
        return;
      }
      
      _notifiedClasses.add(classInstanceId);
      
      await _sendClassStartingNotification(
        className: className,
        teacher: teacher,
        location: location,
        classTime: classTime,
        classId: classId,
        now: now,
      );
      
      if (kDebugMode) {
        print('🎓 NOTIFICATION SENT: $className is starting now!');
        print('   Time: $classTime');
        print('   Teacher: $teacher');
        print('   Location: $location');
      }
      
    } catch (e) {
      if (kDebugMode) print('❌ Error processing class start: $e');
    }
  }
  
  // ✅ Send notification - ENHANCED for background delivery
  static Future<void> _sendClassStartingNotification({
    required String className,
    required String teacher,
    required String location,
    required String classTime,
    required String classId,
    required DateTime now,
  }) async {
    try {
      final notificationId = 'class_starting_$classId${now.millisecondsSinceEpoch}'.hashCode;
      
      String title = '🎓 Class Starting NOW!';
      String body = '📚 $className is starting right now';
      
      if (teacher.isNotEmpty) body += '\n👨‍🏫 Teacher: $teacher';
      if (location.isNotEmpty) body += '\n📍 Location: $location';
      body += '\n⏰ Time: $classTime';
      body += '\n\n🏃‍♂️ Don\'t be late!';
      
      await _notifications.show(
        notificationId,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'class_notifications_critical',
            'Class Starting Notifications',
            channelDescription: 'Real-time notifications when classes start',
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            enableVibration: true,
            autoCancel: false,
            ongoing: false,
            category: AndroidNotificationCategory.alarm,
            fullScreenIntent: true,
            visibility: NotificationVisibility.public,
            color: Color(0xFF059669),
            colorized: true,
            showWhen: true,
            icon: '@mipmap/ic_launcher',
            largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            styleInformation: BigTextStyleInformation(
              '',
              contentTitle: '',
              summaryText: '',
              htmlFormatContent: true,
              htmlFormatTitle: true,
            ),
            actions: [
              AndroidNotificationAction(
                'mark_attending',
                '✅ I\'m Going',
                titleColor: Color(0xFF059669),
              ),
              AndroidNotificationAction(
                'view_schedule',
                '📅 View Schedule',
                titleColor: Color(0xFF3B82F6),
              ),
            ],
            groupKey: 'class_starting_notifications',
            setAsGroupSummary: false,
            ticker: 'Class starting now',
            timeoutAfter: 5 * 60 * 1000,
          ),
        ),
        payload: 'class_starting_$classId',
      );
      
    } catch (e) {
      if (kDebugMode) print('❌ Failed to send class starting notification: $e');
    }
  }

  // ✅ Schedule background notifications for all classes
  static Future<void> scheduleAllNotifications() async {
    if (!_isInitialized) await initialize();
    
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (kDebugMode) print('⚠️ No authenticated user for scheduling notifications');
      return;
    }

    try {
      // Cancel all existing scheduled notifications
      await _notifications.cancelAll();
      
      // Get all user's classes
      final classesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('Classes')
          .where('notify', isEqualTo: true) // Only classes with notifications enabled
          .get();

      int scheduledCount = 0;
      
      for (final classDoc in classesSnapshot.docs) {
        final classData = classDoc.data();
        final List<String> days = List<String>.from(classData['days'] ?? []);
        final String timeString = classData['time'] ?? '';
        final String className = classData['title'] ?? '';
        
        if (timeString.isEmpty || days.isEmpty) continue;
        
        final timeParts = timeString.split(':');
        if (timeParts.length != 2) continue;
        
        final hour = int.tryParse(timeParts[0]);
        final minute = int.tryParse(timeParts[1]);
        
        if (hour == null || minute == null) continue;
        
        // Schedule for each day of the week for the next month
        for (String day in days) {
          final weekday = _getWeekdayNumber(day);
          if (weekday == -1) continue;
          
          for (int week = 0; week < 4; week++) {
            final scheduleDate = _getNextDateForWeekday(weekday, week);
            final scheduledTime = DateTime(
              scheduleDate.year,
              scheduleDate.month,
              scheduleDate.day,
              hour,
              minute,
            );
            
            // Only schedule future notifications
            if (scheduledTime.isAfter(DateTime.now())) {
              await _scheduleClassNotification(
                scheduledTime: scheduledTime,
                className: className,
                teacher: classData['teacher'] ?? '',
                location: classData['location'] ?? '',
                classId: classDoc.id,
                day: day,
              );
              scheduledCount++;
            }
          }
        }
      }
      
      if (kDebugMode) {
        print('✅ Scheduled $scheduledCount background notifications');
      }
      
    } catch (e) {
      if (kDebugMode) print('❌ Error scheduling notifications: $e');
    }
  }
  
  // ✅ Schedule individual class notification
  static Future<void> _scheduleClassNotification({
    required DateTime scheduledTime,
    required String className,
    required String teacher,
    required String location,
    required String classId,
    required String day,
  }) async {
    try {
      final notificationId = '${classId}_${scheduledTime.millisecondsSinceEpoch}'.hashCode;
      
      String title = '🎓 Class Starting NOW!';
      String body = '📚 $className is starting right now';
      
      if (teacher.isNotEmpty) body += '\n👨‍🏫 Teacher: $teacher';
      if (location.isNotEmpty) body += '\n📍 Location: $location';
      body += '\n⏰ Time: ${_formatTime(scheduledTime)}';
      body += '\n\n🏃‍♂️ Don\'t be late!';
      
      await _notifications.zonedSchedule(
        notificationId,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'class_notifications_critical',
            'Class Starting Notifications',
            channelDescription: 'Background notifications when classes start',
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            enableVibration: true,
            category: AndroidNotificationCategory.alarm,
            fullScreenIntent: true,
            visibility: NotificationVisibility.public,
            color: Color(0xFF059669),
            colorized: true,
            autoCancel: false,
            actions: [
              AndroidNotificationAction(
                'mark_attending',
                '✅ I\'m Going',
                titleColor: Color(0xFF059669),
              ),
              AndroidNotificationAction(
                'view_schedule',
                '📅 View Schedule',
                titleColor: Color(0xFF3B82F6),
              ),
            ],
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'class_starting_$classId',
      );
      
    } catch (e) {
      if (kDebugMode) print('❌ Failed to schedule notification for $className: $e');
    }
  }
  
  // ✅ Helper functions
  static String _getDayOfWeek(int weekday) {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return days[weekday - 1];
  }
  
  static int _getWeekdayNumber(String day) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days.indexOf(day) + 1; // 1-7 for DateTime.weekday
  }
  
  static DateTime _getNextDateForWeekday(int weekday, int weeksFromNow) {
    final now = DateTime.now();
    final daysUntilWeekday = (weekday - now.weekday) % 7;
    return now.add(Duration(days: daysUntilWeekday + (weeksFromNow * 7)));
  }
  
  static String _formatTimeForDatabase(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
  
  static String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
  
  static void _cleanupOldNotifications(DateTime now) {
    final cutoffTime = now.subtract(const Duration(hours: 1));
    final cutoffDay = '${cutoffTime.day}${cutoffTime.month}${cutoffTime.year}';
    
    _notifiedClasses.removeWhere((classId) => !classId.endsWith(cutoffDay));
    
    if (kDebugMode && _notifiedClasses.isNotEmpty) {
      print('🧹 Cleaned up old notifications. Active: ${_notifiedClasses.length}');
    }
  }
  
  // ✅ Test method
  static Future<void> testClassStartingNotification() async {
    if (!_isInitialized) await initialize();
    
    try {
      final now = DateTime.now();
      final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      
      await _sendClassStartingNotification(
        className: 'Advanced Mathematics',
        teacher: 'Dr. Smith',
        location: 'Room 302',
        classTime: currentTime,
        classId: 'test_123',
        now: now,
      );
      
      if (kDebugMode) print('🧪 Test class starting notification sent');
      
    } catch (e) {
      if (kDebugMode) print('❌ Test notification failed: $e');
      throw Exception('Test notification failed: $e');
    }
  }
  
  // ✅ Getters
  static bool get isMonitoring => _isMonitoring;
  static int get notifiedClassesCount => _notifiedClasses.length;
  
  // ✅ Check all classes today - UPDATED for Firestore
  static Future<List<Map<String, dynamic>>> checkAllClassesToday() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('No authenticated user');
    }
    
    try {
      final now = DateTime.now();
      final currentDay = _getDayOfWeek(now.weekday);
      
      final classesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('Classes')
          .where('days', arrayContains: currentDay)
          .get();
      
      final classes = classesSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      
      // Sort by time
      classes.sort((a, b) {
        final timeA = a['time'] ?? '';
        final timeB = b['time'] ?? '';
        return timeA.compareTo(timeB);
      });
      
      if (kDebugMode) {
        print('📅 Classes scheduled for $currentDay:');
        for (final classData in classes) {
          print('   📚 ${classData['title']} at ${classData['time']}');
        }
      }
      
      return classes;
      
    } catch (e) {
      if (kDebugMode) print('❌ Error checking today\'s classes: $e');
      throw Exception('Failed to check classes: $e');
    }
  }

  // ✅ ADD: Make _sendClassStartingNotification accessible for testing
  // (Remove the underscore to make it public or add this wrapper)
  static Future<void> sendTestClassNotification({
    required String className,
    required String teacher,
    required String location,
    required String classTime,
    required String classId,
    required DateTime now,
  }) async {
    return _sendClassStartingNotification(
      className: className,
      teacher: teacher,
      location: location,
      classTime: classTime,
      classId: classId,
      now: now,
    );
  }

  // Helper function (add this to your NotificationService)
  static TimeOfDay? _parseTimeOfDay(String time, DateTime now) {
    final match = RegExp(r'(\d{1,2}):(\d{2})\s*([AP]M)', caseSensitive: false).firstMatch(time);
    if (match == null) return null;
    int hour = int.parse(match.group(1)!);
    final int minute = int.parse(match.group(2)!);
    final String period = match.group(3)!.toUpperCase();
    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return TimeOfDay(hour: hour, minute: minute);
  }
}