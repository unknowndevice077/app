import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

class ClassNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static Timer? _classTimer;
  static bool _notificationsEnabled = true;
  static String _selectedAlarmSound = 'assets/alarms/alarm.mp3'; // Instead of 'default'
  static VoidCallback? _onClassStarting;
  static VoidCallback? _onClassReminder;

  // Audio player state
  static AudioPlayer? _currentTestPlayer;
  static Duration _currentPosition = Duration.zero;
  static Duration _totalDuration = Duration.zero;
  static bool _isPlaying = false;
  static String _currentSongTitle = '';
  static StreamSubscription? _positionSubscription;
  static StreamSubscription? _durationSubscription;
  static StreamSubscription? _playerStateSubscription;

  static const Map<String, String> availableAlarmSounds = {
    'assets/alarms/alarm.mp3': 'Default Alarm',
    'assets/alarms/mixkit-software-interface-back-2575.wav': 'Interface Back',
    'assets/alarms/mixkit-bubble-pop-up-alert-notification-2357.wav': 'Bubble Pop',
    'assets/alarms/mixkit-confirmation-tone-2867.wav': 'Confirmation Tone',
    'assets/alarms/mixkit-happy-bells-notification-937.wav': 'Happy Bells',
    'assets/alarms/mixkit-software-interface-start-2574.wav': 'Interface Start',
    'assets/alarms/Post Malone, Swae Lee - Sunflower (Spider-Man_ Into the Spider-Verse) (Official Video) (1).mp3': 'Sunflower (1)',
    'assets/alarms/Post Malone, Swae Lee - Sunflower (Spider-Man_ Into the Spider-Verse) (Official Video) (2).mp3': 'Sunflower (2)',
  };

  static List<String> customAlarmSoundPaths = [];

  // Getters
  static bool get notificationsEnabled => _notificationsEnabled;
  static String get selectedAlarmSound => _selectedAlarmSound;
  static bool get isPlaying => _isPlaying;
  static Duration get currentPosition => _currentPosition;
  static Duration get totalDuration => _totalDuration;
  static String get currentSongTitle => _currentSongTitle;

  // Initialize
  static Future<void> initialize() async {
    await _loadNotificationPreferences();
    await loadCustomAlarmSounds();

    if (!Platform.isWindows) {
      await _initializeNotifications();
    } else {
      print('🪟 Windows detected - using in-app notifications');
    }
  }

  // Load/save preferences
  static Future<void> _loadNotificationPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _notificationsEnabled = prefs.getBool('class_notifications_enabled') ?? true;
    _selectedAlarmSound = prefs.getString('selected_alarm_sound') ?? 'assets/alarms/alarm.mp3'; // Change from 'default'
  }

  static Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('class_notifications_enabled', enabled);

    if (!enabled) {
      _classTimer?.cancel();
      await _notifications.cancelAll();
    }
  }

  static Future<void> setAlarmSound(String soundKey) async {
    _selectedAlarmSound = soundKey;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_alarm_sound', soundKey);

    // Recreate notification channels with new sound
    if (Platform.isAndroid && !Platform.isWindows) {
      await _createNotificationChannels();
    }
  }

  // Load/save custom sounds
  static Future<void> loadCustomAlarmSounds() async {
    final prefs = await SharedPreferences.getInstance();
    customAlarmSoundPaths = prefs.getStringList('custom_alarm_sounds') ?? [];
  }

  static Future<void> addCustomAlarmSound(String filePath) async {
    final prefs = await SharedPreferences.getInstance();
    customAlarmSoundPaths.add(filePath);
    await prefs.setStringList('custom_alarm_sounds', customAlarmSoundPaths);
  }

  // Audio player methods
  static Future<void> testAlarmSound(String soundKey, {bool playOutLoud = true}) async {
    if (Platform.isWindows) {
      print('🎵 Testing alarm sound: ${availableAlarmSounds[soundKey]}');
      return;
    }

    // Stop any currently playing test sound
    await stopCurrentTestSound();

    // Create new player for testing
    _currentTestPlayer = AudioPlayer();
    _currentSongTitle = availableAlarmSounds[soundKey] ?? 'Custom Sound';
    
    try {
      // Always use AssetSource for sounds in assets folder
      String soundFile = _getSoundFileName(soundKey);
      await _currentTestPlayer!.play(AssetSource(soundFile));
      _isPlaying = true;
      print('🎵 Playing full song from assets: $soundFile');
      
      // Listen to position changes
      _positionSubscription = _currentTestPlayer!.onPositionChanged.listen((position) {
        _currentPosition = position;
      });
      
      // Listen to duration changes
      _durationSubscription = _currentTestPlayer!.onDurationChanged.listen((duration) {
        _totalDuration = duration;
      });
      
      // Listen to player state changes
      _playerStateSubscription = _currentTestPlayer!.onPlayerStateChanged.listen((state) {
        _isPlaying = state == PlayerState.playing;
        if (state == PlayerState.completed) {
          _resetPlayerState();
        }
      });
      
    } catch (e) {
      print('❌ Error playing sound: $e');
      _resetPlayerState();
    }
  }

  static Future<void> pauseCurrentTestSound() async {
    if (_currentTestPlayer != null) {
      await _currentTestPlayer!.pause();
      _isPlaying = false;
    }
  }

  static Future<void> resumeCurrentTestSound() async {
    if (_currentTestPlayer != null) {
      await _currentTestPlayer!.resume();
      _isPlaying = true;
    }
  }

  static Future<void> seekTo(Duration position) async {
    if (_currentTestPlayer != null) {
      await _currentTestPlayer!.seek(position);
      _currentPosition = position;
    }
  }

  static Future<void> stopCurrentTestSound() async {
    if (_currentTestPlayer != null) {
      await _currentTestPlayer!.stop();
      await _currentTestPlayer!.dispose();
      _currentTestPlayer = null;
    }
    _resetPlayerState();
  }

  static void _resetPlayerState() {
    _isPlaying = false;
    _currentPosition = Duration.zero;
    _totalDuration = Duration.zero;
    _currentSongTitle = '';
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
  }

  // Helper method to get sound file name
  static String _getSoundFileName(String soundKey) {
  // If it's an asset path, extract the filename
  if (soundKey.startsWith('assets/alarms/')) {
    return soundKey.replaceFirst('assets/', '');
  }
  
  // Handle legacy keys
  switch (soundKey) {
    case 'default':
    case 'alarm':
    case 'classic':
    case 'gentle':
    case 'urgent':
    case 'school_bell':
    case 'digital':
    case 'nature':
    case 'chimes':
      return 'alarms/alarm.mp3';
    default:
      return 'alarms/alarm.mp3';
  }
}

  // Notification initialization
  static Future<void> _initializeNotifications() async {
    if (Platform.isAndroid) {
      await Permission.notification.request();
      await Permission.scheduleExactAlarm.request();
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        print('Notification tapped: ${details.payload}');
      },
    );

    if (Platform.isAndroid) {
      await _createNotificationChannels();
    }
  }

  static Future<void> _createNotificationChannels() async {
    const reminderChannel = AndroidNotificationChannel(
      'class_reminders',
      'Class Reminders',
      description: 'Notifications for upcoming classes',
      importance: Importance.high,
      sound: RawResourceAndroidNotificationSound('notification'),
      enableVibration: true,
    );

    final alarmChannel = AndroidNotificationChannel(
      'class_alarms',
      'Class Alarms',
      description: 'Critical alarms when classes start',
      importance: Importance.max,
      sound: _getAndroidAlarmSound(_selectedAlarmSound),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
      playSound: true,
    );

    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(reminderChannel);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(alarmChannel);
  }

  // Sound helpers
  static RawResourceAndroidNotificationSound _getAndroidAlarmSound(String soundKey) {
    if (soundKey == 'default') {
      return const RawResourceAndroidNotificationSound('alarm');
    }
    const supported = [
      'alarm', 'classic_alarm', 'gentle_alarm', 'urgent_alarm',
      'school_bell', 'digital_alarm', 'nature_alarm', 'chimes_alarm',
    ];
    if (supported.contains(soundKey)) {
      return RawResourceAndroidNotificationSound(soundKey);
    }
    return const RawResourceAndroidNotificationSound('alarm');
  }

  static AndroidNotificationSound _getAndroidNotificationSound(String soundKeyOrPath) {
    if (customAlarmSoundPaths.contains(soundKeyOrPath) && Platform.isAndroid) {
      return UriAndroidNotificationSound(soundKeyOrPath);
    }
    if (soundKeyOrPath == 'default') {
      return const RawResourceAndroidNotificationSound('alarm');
    }
    const supported = [
      'alarm', 'classic_alarm', 'gentle_alarm', 'urgent_alarm',
      'school_bell', 'digital_alarm', 'nature_alarm', 'chimes_alarm',
    ];
    if (supported.contains(soundKeyOrPath)) {
      return RawResourceAndroidNotificationSound(soundKeyOrPath);
    }
    return const RawResourceAndroidNotificationSound('alarm');
  }

  // Class notification scheduling
  static void scheduleClassNotifications(
    List<ClassModel> classes, {
    int minutesBefore = 10,
  }) {
    _classTimer?.cancel();
    
    if (_notificationsEnabled && classes.isNotEmpty) {
      _classTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
        _checkForUpcomingClasses(classes, minutesBefore);
      });
    }
  }

  static void _checkForUpcomingClasses(List<ClassModel> classes, int minutesBefore) {
    if (!_notificationsEnabled) return;

    final now = DateTime.now();
    final currentDay = getCurrentDayName();

    for (final classModel in classes) {
      if (!classModel.days.contains(currentDay)) continue;

      final classTime = _parseClassStartTime(classModel.time);
      if (classTime == null) continue;

      final classDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        classTime.hour,
        classTime.minute,
      );

      final difference = classDateTime.difference(now).inMinutes;

      if (difference == minutesBefore) {
        _showReminderNotification(classModel, '$minutesBefore minutes');
      }

      if (difference == 0) {
        _showClassStartingAlarm(classModel);
      }
    }
  }

  static Future<void> _showReminderNotification(ClassModel classModel, String timeUntil) async {
    if (!_notificationsEnabled) return;

    print('📚 Class Reminder: ${classModel.title} starts in $timeUntil');

    if (Platform.isWindows) {
      _onClassReminder?.call();
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      'class_reminders',
      'Class Reminders',
      channelDescription: 'Notifications for upcoming classes',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      interruptionLevel: InterruptionLevel.active,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      classModel.title.hashCode,
      '📚 Class Starting Soon',
      '${classModel.title} starts in $timeUntil\n📍 ${classModel.location} • 👨‍🏫 ${classModel.teacher}',
      details,
      payload: 'reminder_${classModel.title}',
    );
  }

  static Future<void> _showClassStartingAlarm(ClassModel classModel) async {
    if (!_notificationsEnabled) return;

    print('🚨 CLASS STARTING NOW: ${classModel.title}');

    if (Platform.isWindows) {
      _onClassStarting?.call();
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      'class_alarms',
      'Class Alarms',
      channelDescription: 'Critical alarms when classes start',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      color: Colors.red,
      colorized: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
      playSound: true,
      sound: _getAndroidNotificationSound(_selectedAlarmSound),
      autoCancel: false,
      timeoutAfter: 30000,
    );

    final details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      classModel.title.hashCode + 10000,
      '🚨 CLASS STARTING NOW! 🚨',
      '${classModel.title} is starting RIGHT NOW!\n📍 Go to ${classModel.location}',
      details,
      payload: 'alarm_${classModel.title}',
    );
  }

  static TimeOfDay? _parseClassStartTime(String timeString) {
    final parts = timeString.split(' - ');
    if (parts.isEmpty) return null;

    final startTimeStr = parts[0].trim();
    final format = RegExp(r'(\d{1,2}):(\d{2})\s*([AP]M)', caseSensitive: false);
    final match = format.firstMatch(startTimeStr);

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

  static String getCurrentDayName() {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[DateTime.now().weekday - 1];
  }

  // Cleanup
  static void dispose() {
    _classTimer?.cancel();
    _resetPlayerState();
  }
}

// ClassModel
class ClassModel {
  String title;
  String time;
  String location;
  String teacher;
  String notes;
  Color color;
  List<String> days;
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

class AlarmSoundPicker extends StatefulWidget {
  const AlarmSoundPicker({super.key});

  @override
  State<AlarmSoundPicker> createState() => _AlarmSoundPickerState();
}

class _AlarmSoundPickerState extends State<AlarmSoundPicker> {
  String? _selectedSound;

  @override
  void initState() {
    super.initState();
    _selectedSound = ClassNotificationService.selectedAlarmSound;
    
    // Fallback if the selected sound doesn't exist in the map
    if (!ClassNotificationService.availableAlarmSounds.containsKey(_selectedSound)) {
      _selectedSound = ClassNotificationService.availableAlarmSounds.keys.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: _selectedSound,
      decoration: InputDecoration(
        labelText: 'Choose Alarm Sound',
        prefixIcon: Icon(Icons.music_note, color: Colors.purple[700]),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.white,
      ),
      items: ClassNotificationService.availableAlarmSounds.entries.map(
        (entry) => DropdownMenuItem<String>(
          value: entry.key,
          child: Text(entry.value),
        ),
      ).toList(),
      onChanged: (value) async {
        if (value != null) {
          await ClassNotificationService.setAlarmSound(value);
          setState(() {
            _selectedSound = value;
          });
        }
      },
    );
  }
}