import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/services/notification_service.dart';
import 'package:flutter/foundation.dart';

class ClassNotificationPage extends StatefulWidget {
  const ClassNotificationPage({super.key});

  @override
  State<ClassNotificationPage> createState() => _ClassNotificationPageState();
}

class _ClassNotificationPageState extends State<ClassNotificationPage>
    with TickerProviderStateMixin {
  bool _notificationsEnabled = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      });
    }
  }

  // Fix the _saveSettings method to use the correct notification methods:
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', _notificationsEnabled);
      
      if (kDebugMode) {
        print('💾 Settings saved:');
        print('   Notifications: $_notificationsEnabled');
        print('   Sound: Android default notification sound');
      }

      // ✅ FIXED: Use the correct notification scheduling methods
      try {
        if (_notificationsEnabled) {
          // Schedule all types of notifications
          await NotificationService.scheduleAllNotifications();
        } else {
          // Cancel all notifications
          await NotificationService.cancelAllNotifications();
        }
      } catch (notificationError) {
        if (kDebugMode) {
          print('❌ Notification error: $notificationError');
        }
        // Don't throw the error, just log it - settings still saved
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving settings: $e');
      }
      // Show user feedback if in UI context
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return WillPopScope(
      onWillPop: () async {
        try {
          await _saveSettings();
        } catch (e) {
          if (kDebugMode) {
            print('❌ Error saving on back gesture: $e');
          }
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: const Color(0xFF3B82F6),
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'Notification Settings',
            style: GoogleFonts.inter(
              fontSize: isTablet ? 24 : 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () async {
              try {
                await _saveSettings();
              } catch (e) {
                if (kDebugMode) {
                  print('❌ Error saving on back press: $e');
                }
              }
              
              if (mounted) {
                Navigator.pop(context);
              }
            },
          ),
        ),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: CustomScrollView(
            slivers: [
              // Header Section
              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF3B82F6).withOpacity(0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  padding: EdgeInsets.all(isTablet ? 32 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.notifications_active,
                            color: Color(0xFF3B82F6),
                            size: isTablet ? 36 : 32,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Class Notifications',
                                  style: GoogleFonts.inter(
                                    fontSize: isTablet ? 32 : 28,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                Text(
                                  'Simple and reliable notifications',
                                  style: GoogleFonts.inter(
                                    fontSize: isTablet ? 16 : 14,
                                    color: const Color(0xFF64748B),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Get notified when your classes start using Android\'s default notification sound',
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 18 : 16,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Main Notification Toggle Card
              SliverToBoxAdapter(
                child: Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: isTablet ? 32 : 16,
                    vertical: 8,
                  ),
                  padding: EdgeInsets.all(isTablet ? 32 : 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Main toggle
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(isTablet ? 20 : 16),
                            decoration: BoxDecoration(
                              color: _notificationsEnabled 
                                  ? const Color(0xFF3B82F6).withOpacity(0.15)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              _notificationsEnabled
                                  ? Icons.notifications_active
                                  : Icons.notifications_off,
                              color: _notificationsEnabled 
                                  ? const Color(0xFF3B82F6)
                                  : Colors.grey[600],
                              size: isTablet ? 32 : 28,
                            ),
                          ),
                          SizedBox(width: isTablet ? 24 : 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Enable Notifications',
                                  style: GoogleFonts.inter(
                                    fontSize: isTablet ? 22 : 18,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _notificationsEnabled 
                                      ? 'You\'ll receive alerts for upcoming classes'
                                      : 'Notifications are currently disabled',
                                  style: GoogleFonts.inter(
                                    fontSize: isTablet ? 16 : 14,
                                    color: _notificationsEnabled 
                                        ? const Color(0xFF059669)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Transform.scale(
                            scale: isTablet ? 1.2 : 1.0,
                            child: Switch(
                              value: _notificationsEnabled,
                              onChanged: (value) {
                                setState(() {
                                  _notificationsEnabled = value;
                                });
                                _saveSettings();
                              },
                              activeColor: const Color(0xFF3B82F6),
                              activeTrackColor: const Color(0xFF3B82F6).withOpacity(0.3),
                            ),
                          ),
                        ],
                      ),
                      
                      // Divider
                      Container(
                        margin: EdgeInsets.symmetric(vertical: isTablet ? 24 : 20),
                        height: 1,
                        color: Colors.grey.withOpacity(0.2),
                      ),
                      
                      // Sound info
                      Row(
                        children: [
                          Icon(
                            Icons.volume_up,
                            color: Colors.grey[600],
                            size: isTablet ? 24 : 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Notification Sound',
                                  style: GoogleFonts.inter(
                                    fontSize: isTablet ? 16 : 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Uses your device\'s default notification sound',
                                  style: GoogleFonts.inter(
                                    fontSize: isTablet ? 14 : 12,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Test Notification Button
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 16),
                  margin: EdgeInsets.only(top: isTablet ? 24 : 16),
                  child: ElevatedButton.icon(
                    onPressed: _notificationsEnabled ? () async {
                      try {
                        await NotificationService.testBackgroundNotification();
                        
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.schedule, color: Colors.white),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Test notification scheduled!',
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Text(
                                          'Close the app and wait 10 seconds',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: const Color(0xFF059669),
                              duration: const Duration(seconds: 4),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (kDebugMode) {
                          print('❌ Test notification error: $e');
                        }
                        
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to schedule test notification: ${e.toString()}'),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        }
                      }
                    } : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _notificationsEnabled 
                          ? const Color(0xFF059669)
                          : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: isTablet ? 20 : 16,
                        horizontal: isTablet ? 32 : 24,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: _notificationsEnabled ? 3 : 0,
                    ),
                    icon: Icon(
                      Icons.phone_android,
                      size: isTablet ? 24 : 20,
                    ),
                    label: Text(
                      'Test Notification',
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 18 : 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

              // Info Section
              SliverToBoxAdapter(
                child: Container(
                  margin: EdgeInsets.all(isTablet ? 32 : 16),
                  padding: EdgeInsets.all(isTablet ? 24 : 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF3B82F6).withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: const Color(0xFF3B82F6),
                            size: isTablet ? 24 : 20,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'How it works',
                            style: GoogleFonts.inter(
                              fontSize: isTablet ? 18 : 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF3B82F6),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isTablet ? 16 : 12),
                      _InfoBullet(
                        'Notification when class begins',
                        isTablet: isTablet,
                      ),
                      _InfoBullet(
                        'Uses reliable Android default sound',
                        isTablet: isTablet,
                      ),
                      _InfoBullet(
                        'Works even when app is closed',
                        isTablet: isTablet,
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom spacing
              SliverToBoxAdapter(
                child: SizedBox(height: isTablet ? 50 : 30),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ✅ Info bullet widget
class _InfoBullet extends StatelessWidget {
  final String text;
  final bool isTablet;

  const _InfoBullet(this.text, {required this.isTablet});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isTablet ? 8 : 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: isTablet ? 6 : 5,
            height: isTablet ? 6 : 5,
            margin: EdgeInsets.only(
              top: isTablet ? 8 : 7,
              right: isTablet ? 12 : 10,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: isTablet ? 16 : 14,
                color: const Color(0xFF1E293B),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}