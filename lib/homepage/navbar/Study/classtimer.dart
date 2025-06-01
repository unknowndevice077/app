import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class ClassTimer extends StatefulWidget {
  final String classId;
  final String topicId;
  final String topicTitle;

  const ClassTimer({
    super.key,
    required this.classId,
    required this.topicId,
    required this.topicTitle,
  });

  @override
  State<ClassTimer> createState() => _ClassTimerState();
}

class _ClassTimerState extends State<ClassTimer>
    with TickerProviderStateMixin {
  Timer? _timer;
  int _minutes = 25;
  int _seconds = 0;
  bool _isRunning = false;
  int _originalMinutes = 25;
  int _originalSeconds = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _originalMinutes = _minutes;
    _originalSeconds = _seconds;
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startTimer() {
    if (_isRunning) return;
    
    _originalMinutes = _minutes;
    _originalSeconds = _seconds;
    
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_minutes == 0 && _seconds == 0) {
          _timer?.cancel();
          _isRunning = false;
          _saveStudySession();
          _showCompletionDialog();
        } else if (_seconds == 0) {
          _minutes--;
          _seconds = 59;
        } else {
          _seconds--;
        }
      });
    });
  }

  void _pauseTimer() {
    if (!_isRunning) return;
    
    _timer?.cancel();
    setState(() => _isRunning = false);
    _saveStudySession();
  }

  void _resetTimer() {
    if (_isRunning) {
      _saveStudySession();
    }
    
    _timer?.cancel();
    setState(() {
      _minutes = 25;
      _seconds = 0;
      _isRunning = false;
      _originalMinutes = 25;
      _originalSeconds = 0;
    });
  }

  Future<void> _saveStudySession() async {
    final originalTotalSeconds = (_originalMinutes * 60) + _originalSeconds;
    final remainingTotalSeconds = (_minutes * 60) + _seconds;
    final studiedSeconds = originalTotalSeconds - remainingTotalSeconds;
    final studiedMinutes = (studiedSeconds / 60).floor();
    
    if (studiedSeconds <= 0) return;
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('study_sessions')
          .add({
        'classId': widget.classId,
        'topicId': widget.topicId,
        'topicTitle': widget.topicTitle,
        'duration': studiedMinutes,
        'seconds': studiedSeconds,
        'date': FieldValue.serverTimestamp(),
        'type': 'timer',
      });
    } catch (e) {
      print('Error saving study session: $e');
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.celebration, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Text(
              'Well Done!',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        content: Text(
          'You\'ve completed your study session for ${widget.topicTitle}!',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetTimer();
            },
            child: Text(
              'Start Again',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: Colors.orange,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Done',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showTimePickerDialog() {
    int tempMinutes = _minutes;
    int tempSeconds = _seconds;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Set Timer',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Minutes picker
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Minutes', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    width: 80,
                    child: ListWheelScrollView.useDelegate(
                      itemExtent: 40,
                      diameterRatio: 1.5,
                      physics: const FixedExtentScrollPhysics(),
                      controller: FixedExtentScrollController(initialItem: tempMinutes),
                      onSelectedItemChanged: (value) {
                        tempMinutes = value;
                      },
                      childDelegate: ListWheelChildBuilderDelegate(
                        builder: (context, index) => Center(
                          child: Text(
                            index.toString().padLeft(2, '0'),
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        childCount: 60,
                      ),
                    ),
                  ),
                ],
              ),
              // Seconds picker
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Seconds', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    width: 80,
                    child: ListWheelScrollView.useDelegate(
                      itemExtent: 40,
                      diameterRatio: 1.5,
                      physics: const FixedExtentScrollPhysics(),
                      controller: FixedExtentScrollController(initialItem: tempSeconds),
                      onSelectedItemChanged: (value) {
                        tempSeconds = value;
                      },
                      childDelegate: ListWheelChildBuilderDelegate(
                        builder: (context, index) => Center(
                          child: Text(
                            index.toString().padLeft(2, '0'),
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        childCount: 60,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _minutes = tempMinutes;
                  _seconds = tempSeconds;
                  _originalMinutes = tempMinutes;
                  _originalSeconds = tempSeconds;
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Set',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final containerSize = isTablet ? 200.0 : 160.0;
    final fontSize = isTablet ? 48.0 : 36.0;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Study Timer',
              style: GoogleFonts.inter(
                fontSize: isTablet ? 20 : 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              widget.topicTitle,
              style: GoogleFonts.inter(
                fontSize: isTablet ? 14 : 12,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _isRunning ? null : _showTimePickerDialog,
            icon: Icon(Icons.timer, color: Colors.white),
            tooltip: 'Set Timer',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Timer display
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Minutes container
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) => Transform.scale(
                    scale: _isRunning ? _pulseAnimation.value : 1.0,
                    child: Container(
                      width: containerSize,
                      height: containerSize,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.shade400,
                            Colors.orange.shade600,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.3),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _minutes.toString().padLeft(2, '0'),
                            style: GoogleFonts.inter(
                              fontSize: fontSize,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'MINUTES',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                SizedBox(width: 20),
                
                // Seconds container
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) => Transform.scale(
                    scale: _isRunning ? _pulseAnimation.value : 1.0,
                    child: Container(
                      width: containerSize,
                      height: containerSize,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.shade400,
                            Colors.orange.shade600,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.3),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _seconds.toString().padLeft(2, '0'),
                            style: GoogleFonts.inter(
                              fontSize: fontSize,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'SECONDS',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: isTablet ? 60 : 40),
            
            // Control buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Start/Pause button
                ElevatedButton(
                  onPressed: _isRunning ? _pauseTimer : _startTimer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRunning ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 32 : 24,
                      vertical: isTablet ? 16 : 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(
                    _isRunning ? 'PAUSE' : 'START',
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                
                SizedBox(width: 20),
                
                // Reset button
                OutlinedButton(
                  onPressed: _resetTimer,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white, width: 2),
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 32 : 24,
                      vertical: isTablet ? 16 : 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(
                    'RESET',
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
