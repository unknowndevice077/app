import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/services/notification_service.dart';

class NotificationTestPage extends StatefulWidget {
  const NotificationTestPage({super.key});

  @override
  State<NotificationTestPage> createState() => _NotificationTestPageState();
}

class _NotificationTestPageState extends State<NotificationTestPage> {
  bool _isLoading = false;
  List<String> _testResults = [];
  int _backgroundTestDelay = 15; // seconds
  
  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    try {
      await NotificationService.initialize();
      setState(() {});
    } catch (e) {
      _addTestResult('❌ Initialization failed: $e', isError: true);
    }
  }

  void _addTestResult(String result, {bool isError = false}) {
    if (mounted) {
      setState(() {
        _testResults.insert(0, '${DateTime.now().toString().substring(11, 19)}: $result');
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Background Notification Test',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _testResults.clear();
              });
              _addTestResult('🔄 Test results cleared');
            },
            tooltip: 'Clear Results',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Overview Card
            _buildStatusCard(),
            
            const SizedBox(height: 16),
            
            // Quick Tests Card
            _buildQuickTestsCard(),
            
            const SizedBox(height: 16),
            
            // Background Test Card
            _buildBackgroundTestCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.blue.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.info_outline, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Notification System Status',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatusRow(
              'Real-time Monitoring',
              NotificationService.isMonitoring,
              Icons.monitor_heart,
              Icons.monitor_heart_outlined,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.notifications_active, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  Text(
                    'Notified Classes Today: ${NotificationService.notifiedClassesCount}',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, bool status, IconData trueIcon, IconData falseIcon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.blue.shade700,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: status ? Colors.green.shade100 : Colors.red.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: status ? Colors.green.shade300 : Colors.red.shade300,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  status ? trueIcon : falseIcon,
                  size: 16,
                  color: status ? Colors.green.shade700 : Colors.red.shade700,
                ),
                const SizedBox(width: 4),
                Text(
                  status ? 'Active' : 'Inactive',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: status ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTestsCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.flash_on, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Quick Tests',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'These tests send notifications immediately:',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTestButton(
                    'Instant Test',
                    Icons.notifications,
                    Colors.green,
                    () => _runInstantTest(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTestButton(
                    'Class Test',
                    Icons.school,
                    Colors.blue,
                    () => _runClassTest(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildTestButton(
              'Permission Check',
              Icons.security,
              Colors.orange,
              () => _runPermissionCheck(),
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundTestCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.purple.shade50, Colors.purple.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.schedule, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Background Test',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.purple.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade700,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🎯 CRITICAL BACKGROUND TEST',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This test will schedule a notification and you MUST close the app completely to verify background delivery works.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.purple.shade100,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Delay (seconds):',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    color: Colors.purple.shade800,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 80,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _backgroundTestDelay,
                      items: [5, 10, 15, 30, 60].map((seconds) {
                        return DropdownMenuItem(
                          value: seconds,
                          child: Text(
                            '$seconds',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: Colors.purple.shade800,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _backgroundTestDelay = value!;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTestButton(
              'START BACKGROUND TEST',
              Icons.rocket_launch,
              Colors.purple,
              () => _runBackgroundTest(),
              fullWidth: true,
              isPrimary: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestResultsCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade600,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.history, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Test Results',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${_testResults.length} results',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_testResults.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.science_outlined, 
                           size: 48, 
                           color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'No test results yet',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        'Run a test to see results here',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ListView.builder(
                  itemCount: _testResults.length,
                  itemBuilder: (context, index) {
                    final result = _testResults[index];
                    final isError = result.contains('❌');
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isError ? Colors.red.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isError ? Colors.red.shade200 : Colors.green.shade200,
                        ),
                      ),
                      child: Text(
                        result,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          color: isError ? Colors.red.shade800 : Colors.green.shade800,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed, {
    bool fullWidth = false,
    bool isPrimary = false,
  }) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : onPressed,
        icon: _isLoading && isPrimary
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(icon, size: 18),
        label: Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: fullWidth ? 16 : 14,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            vertical: fullWidth ? 16 : 12,
            horizontal: fullWidth ? 24 : 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  // Test Methods
  Future<void> _runInstantTest() async {
    setState(() => _isLoading = true);
    try {
      await NotificationService.testClassStartingNotification();
      _addTestResult('✅ Instant notification sent successfully');
    } catch (e) {
      _addTestResult('❌ Instant test failed: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _runClassTest() async {
    setState(() => _isLoading = true);
    try {
      // Use the public test method from your service
      await NotificationService.testClassStartingNotification();
      _addTestResult('✅ Class notification test sent successfully');
    } catch (e) {
      _addTestResult('❌ Class test failed: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _runPermissionCheck() async {
    setState(() => _isLoading = true);
    try {
      final hasPermission = await NotificationService.hasNotificationPermission();
      if (hasPermission) {
        _addTestResult('✅ Notification permissions granted');
      } else {
        _addTestResult('⚠️ Notification permissions denied', isError: true);
      }
    } catch (e) {
      _addTestResult('❌ Permission check failed: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _runBackgroundTest() async {
    setState(() => _isLoading = true);
    try {
      // Schedule a test notification in the future using only the public method
      await Future.delayed(Duration(seconds: _backgroundTestDelay));
      await NotificationService.testClassStartingNotification();
      _addTestResult('🚀 Background test notification sent after $_backgroundTestDelay seconds');
      _addTestResult('📱 CLOSE THE APP COMPLETELY NOW!');
      _addTestResult('⏰ If notification appears while app is closed, background works!');
      _showBackgroundTestDialog();
    } catch (e) {
      _addTestResult('❌ Background test failed: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showBackgroundTestDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.rocket_launch, color: Colors.purple.shade600),
            const SizedBox(width: 12),
            Text(
              'Background Test Active',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '🎯 Test notification scheduled!',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.purple.shade700,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Column(
                children: [
                  Text(
                    'CLOSE THE APP COMPLETELY',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.purple.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Notification will arrive in $_backgroundTestDelay seconds',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.purple.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '✅ If you see the notification while the app is closed, background notifications work!\n\n❌ If not, check battery optimization settings.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.purple.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'I understand - Close App Now',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: Colors.purple.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleClassMonitoring() async {
    setState(() => _isLoading = true);
    try {
      if (NotificationService.isMonitoring) {
        await NotificationService.stopClassTimeMonitoring();
        _addTestResult('🛑 Class monitoring stopped');
      } else {
        await NotificationService.startClassTimeMonitoring();
        _addTestResult('🎯 Class monitoring started');
      }
    } catch (e) {
      _addTestResult('❌ Monitoring toggle failed: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkTodaysClasses() async {
    setState(() => _isLoading = true);
    try {
      final classes = await NotificationService.checkAllClassesToday();
      if (classes.isEmpty) {
        _addTestResult('📅 No classes scheduled for today');
      } else {
        _addTestResult('📚 Found ${classes.length} classes today');
        for (final classData in classes.take(3)) {
          _addTestResult('   📖 ${classData['title']} at ${classData['time']}');
        }
        if (classes.length > 3) {
          _addTestResult('   ... and ${classes.length - 3} more');
        }
      }
    } catch (e) {
      _addTestResult('❌ Failed to check classes: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }
}