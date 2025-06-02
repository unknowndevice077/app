import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

// Class Timer Page with circular ball animation - separate from general timer
class ClassTimer extends StatefulWidget {
  final String? classId;
  final String? topicId;
  final String? topicTitle;

  const ClassTimer({
    super.key,
    this.classId,
    this.topicId,
    this.topicTitle,
  });

  @override
  State<ClassTimer> createState() => _ClassTimerState();
}

class _ClassTimerState extends State<ClassTimer>
    with TickerProviderStateMixin {
  int _minutes = 15;
  int _seconds = 0;
  Timer? _timer;
  bool _isRunning = false;
  String? _selectedClassId;
  List<Map<String, dynamic>> _classes = [];

  // Add these variables to track original timer values
  int _originalMinutes = 15;
  int _originalSeconds = 0;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  late AnimationController _ballController; // Controller for the ball
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _ballAnimation; // Animation for the ball

  @override
  void initState() {
    super.initState();
    _loadClasses();
    _initializeAnimations();

    // Set initial class if provided
    if (widget.classId != null) {
      _selectedClassId = widget.classId;
    }
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    // Ball controller for 60-second rotation
    _ballController = AnimationController(
      duration: const Duration(seconds: 60), // Exactly 60 seconds
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));

    // Ball animation for circular motion
    _ballAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi, // Full circle
    ).animate(CurvedAnimation(
      parent: _ballController,
      curve: Curves.linear,
    ));
  }

  Future<void> _loadClasses() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('Classes')
              .get();

      setState(() {
        _classes =
            snapshot.docs
                .map(
                  (doc) => {
                    'id': doc.id,
                    'title': doc.data()['title'] ?? 'Unknown Class',
                    'color': doc.data()['color'] ?? Colors.blue.value,
                  },
                )
                .toList();
      });
    } catch (e) {
      print('Error loading classes: $e');
    }
  }

  void _startTimer() {
    if (_isRunning) return;

    // Store the original timer values when starting
    _originalMinutes = _minutes;
    _originalSeconds = _seconds;

    setState(() => _isRunning = true);
    _pulseController.repeat(reverse: true);
    _ballController.repeat(); // Start ball animation

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_minutes == 0 && _seconds == 0) {
          _timer?.cancel();
          _isRunning = false;
          _pulseController.stop();
          _ballController.stop(); // Stop ball animation
          _saveStudySession(); // Save when timer completes naturally
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

  void _resetTimer() {
    // Save progress before resetting if timer was running
    if (_isRunning) {
      _saveStudySession();
    }

    _timer?.cancel();
    _pulseController.stop();
    _ballController.stop(); // Stop ball animation
    _ballController.reset(); // Reset ball position

    setState(() {
      _minutes = 15;
      _seconds = 0;
      _isRunning = false;
      // Reset original values too
      _originalMinutes = 15;
      _originalSeconds = 0;
    });
  }

  void _pauseTimer() {
    if (!_isRunning) return;

    _timer?.cancel();
    _pulseController.stop();
    _ballController.stop(); // Pause ball animation
    setState(() => _isRunning = false);

    // Save progress when pausing
    _saveStudySession();
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[400]!, Colors.green[600]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.celebration, size: 64, color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    'Great Work!',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You completed your study session!',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.green[600],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _resetTimer();
                    },
                    child: Text(
                      'Continue',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _saveStudySession() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    // Calculate actual time studied based on original vs current time
    final originalTotalSeconds = (_originalMinutes * 60) + _originalSeconds;
    final remainingTotalSeconds = (_minutes * 60) + _seconds;
    final studiedSeconds = originalTotalSeconds - remainingTotalSeconds;
    final studiedMinutes = (studiedSeconds / 60).floor();

    // Save even if less than a minute (but more than 0 seconds)
    if (studiedSeconds <= 0) return;

    try {
      // Save to ClassTimerSessions collection for the specific class (CLASS-SPECIFIC)
      if (_selectedClassId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('Classes')
            .doc(_selectedClassId)
            .collection('ClassTimerSessions')
            .add({
              'duration': studiedSeconds, // Total seconds studied
              'timestamp': FieldValue.serverTimestamp(),
              'date': DateTime.now().toIso8601String().split('T')[0],
              'topicId': widget.topicId, // Include topic if available
              'topicTitle': widget.topicTitle, // Include topic title if available
            });
      }

      // Also save to STATISTICS collection for overall tracking
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('STATISTICS')
          .add({
            'minutesStudied': studiedMinutes,
            'secondsStudied': studiedSeconds,
            'subjectId': _selectedClassId,
            'subjectTitle':
                _selectedClassId != null
                    ? _classes.firstWhere(
                      (c) => c['id'] == _selectedClassId,
                      orElse: () => {'title': 'Unknown'},
                    )['title']
                    : 'Class Study',
            'timestamp': FieldValue.serverTimestamp(),
            'date': DateTime.now().toIso8601String().split('T')[0],
            'sessionType': 'class_timer', // Different from general timer
            'topicId': widget.topicId,
            'topicTitle': widget.topicTitle,
          });

      if (mounted) {
        final timeMessage =
            studiedSeconds < 60
                ? '$studiedSeconds seconds'
                : studiedSeconds < 120
                ? '1 minute and ${studiedSeconds % 60} seconds'
                : studiedMinutes > 0
                ? '$studiedMinutes minutes and ${studiedSeconds % 60} seconds'
                : '$studiedSeconds seconds';

        final subjectName =
            _selectedClassId != null
                ? _classes.firstWhere(
                  (c) => c['id'] == _selectedClassId,
                  orElse: () => {'title': 'Unknown'},
                )['title']
                : 'Class Study';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Class study session saved: $timeMessage for $subjectName'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }

      // Reset original values after saving to prevent duplicate saves
      _originalMinutes = _minutes;
      _originalSeconds = _seconds;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving session: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _showSubjectSelector() async {
    if (_classes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No subjects available. Create a class first.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A), // Dark grey background
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.8,
            minChildSize: 0.4,
            expand: false,
            builder: (context, scrollController) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      'Select Subject to Study',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose which subject you want to focus on',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Clear selection option
                    if (_selectedClassId != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.grey[600],
                              shape: BoxShape.circle,
                            ),
                          ),
                          title: Text(
                            'General Study (No Subject)',
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontWeight: FontWeight.normal,
                              fontSize: 16,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.clear,
                            color: Colors.red,
                            size: 20,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onTap: () {
                            setState(() {
                              _selectedClassId = null;
                            });
                            Navigator.pop(context);
                          },
                        ),
                      ),

                    // Subject list
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: _classes.length,
                        itemBuilder: (context, index) {
                          final classData = _classes[index];
                          final isSelected =
                              _selectedClassId == classData['id'];
                          final classColor = Color(
                            classData['color'] ?? Colors.blue.value,
                          );

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: classColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: classColor.withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              title: Text(
                                classData['title'],
                                style: GoogleFonts.inter(
                                  color:
                                      isSelected
                                          ? Colors.white
                                          : Colors.white70,
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              trailing:
                                  isSelected
                                      ? Icon(
                                        Icons.check_circle,
                                        color: classColor,
                                        size: 20,
                                      )
                                      : const Icon(
                                        Icons.radio_button_unchecked,
                                        color: Colors.white54,
                                        size: 20,
                                      ),
                              selected: isSelected,
                              selectedTileColor: classColor.withOpacity(0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side:
                                    isSelected
                                        ? BorderSide(
                                          color: classColor.withOpacity(0.3),
                                        )
                                        : BorderSide.none,
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedClassId = classData['id'];
                                });
                                Navigator.pop(context);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showEditDialog() async {
    int tempMinutes = _minutes;
    int tempSeconds = _seconds;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A), // Dark grey background
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 32,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Text(
                      'Set Timer',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Minutes',
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 120,
                              width: 80,
                              child: ListWheelScrollView.useDelegate(
                                itemExtent: 40,
                                diameterRatio: 1.5,
                                physics: const FixedExtentScrollPhysics(),
                                controller: FixedExtentScrollController(
                                  initialItem: tempMinutes,
                                ),
                                onSelectedItemChanged: (value) {
                                  tempMinutes = value;
                                },
                                childDelegate: ListWheelChildBuilderDelegate(
                                  builder:
                                      (context, index) => Center(
                                        child: Text(
                                          index.toString().padLeft(2, '0'),
                                          style: GoogleFonts.inter(
                                            fontSize: 24,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  childCount: 100,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 40),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Seconds',
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 120,
                              width: 80,
                              child: ListWheelScrollView.useDelegate(
                                itemExtent: 40,
                                diameterRatio: 1.5,
                                physics: const FixedExtentScrollPhysics(),
                                controller: FixedExtentScrollController(
                                  initialItem: tempSeconds,
                                ),
                                onSelectedItemChanged: (value) {
                                  tempSeconds = value;
                                },
                                childDelegate: ListWheelChildBuilderDelegate(
                                  builder:
                                      (context, index) => Center(
                                        child: Text(
                                          index.toString().padLeft(2, '0'),
                                          style: GoogleFonts.inter(
                                            fontSize: 24,
                                            color: Colors.white,
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
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _minutes = tempMinutes;
                              _seconds = tempSeconds;
                              _originalMinutes = tempMinutes;
                              _originalSeconds = tempSeconds;
                            });
                            Navigator.pop(context);
                          },
                          child: Text(
                            'Set Timer',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _scaleController.dispose();
    _ballController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final isTablet = screenWidth > 600;

    final selectedClass = _selectedClassId != null
        ? _classes.firstWhere(
            (c) => c['id'] == _selectedClassId,
            orElse: () => {'title': 'Unknown', 'color': Colors.blue.value},
          )
        : null;

    return WillPopScope(
      onWillPop: () async {
        // Auto-save when back button is pressed
        if (_isRunning) {
          await _saveStudySession();
        }
        return true; // Allow the pop
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF2C2C2C), // Singular dark grey background
        body: SafeArea(
          child: Column(
            children: [
              // Modern AppBar
              Padding(
                padding: EdgeInsets.all(isTablet ? 24 : 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: isTablet ? 28 : 24,
                      ),
                      onPressed: () async {
                        // Auto-save when back button is pressed
                        if (_isRunning) {
                          await _saveStudySession();
                        }
                        Navigator.pop(context);
                      },
                    ),
                    Expanded(
                      child: Text(
                        'Class Timer', // Changed from "Focus Timer"
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: isTablet ? 24 : 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: selectedClass != null 
                                  ? Color(selectedClass['color']).withOpacity(0.2)
                                  : Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selectedClass != null 
                                    ? Color(selectedClass['color'])
                                    : Colors.white24,
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.menu_book,
                              color: selectedClass != null 
                                  ? Color(selectedClass['color'])
                                  : Colors.white70,
                              size: 20,
                            ),
                          ),
                          tooltip: selectedClass != null 
                              ? 'Studying: ${selectedClass['title']}'
                              : 'Select Subject',
                          onPressed: _showSubjectSelector,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Subject indicator
              if (selectedClass != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Color(selectedClass['color']).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: Color(selectedClass['color']).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Color(selectedClass['color']),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        selectedClass['title'],
                        style: GoogleFonts.inter(
                          color: Color(selectedClass['color']),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

              // Timer Display with Ball Animation
              Expanded(
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Main timer circle (removed pulsation)
                      Container(
                        width: isTablet ? 320 : 280,
                        height: isTablet ? 320 : 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selectedClass != null
                                ? Color(selectedClass['color']).withOpacity(0.3)
                                : Colors.white.withOpacity(0.2),
                            width: 2,
                          ),
                          gradient: selectedClass != null
                              ? LinearGradient(
                                  colors: [
                                    Color(selectedClass['color']).withOpacity(0.1),
                                    Color(selectedClass['color']).withOpacity(0.3),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${_minutes.toString().padLeft(2, '0')}:${_seconds.toString().padLeft(2, '0')}',
                                style: GoogleFonts.inter(
                                  fontSize: isTablet ? 64 : 48,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _isRunning ? 'FOCUS TIME' : 'READY TO FOCUS',
                                style: GoogleFonts.inter(
                                  fontSize: isTablet ? 16 : 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Animated ball that goes around the circle
                      if (_isRunning)
                        AnimatedBuilder(
                          animation: _ballAnimation,
                          builder: (context, child) {
                            final radius = (isTablet ? 320 : 280) / 2;
                            final ballX = radius * math.cos(_ballAnimation.value - math.pi / 2);
                            final ballY = radius * math.sin(_ballAnimation.value - math.pi / 2);
                            
                            return Transform.translate(
                              offset: Offset(ballX, ballY),
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: selectedClass != null 
                                      ? Color(selectedClass['color'])
                                      : Colors.blue,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: (selectedClass != null 
                                          ? Color(selectedClass['color'])
                                          : Colors.blue).withOpacity(0.5),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              // Control Buttons
              Padding(
                padding: EdgeInsets.all(isTablet ? 32 : 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Reset Button
                    GestureDetector(
                      onTapDown: (_) => _scaleController.forward(),
                      onTapUp: (_) => _scaleController.reverse(),
                      onTapCancel: () => _scaleController.reverse(),
                      child: AnimatedBuilder(
                        animation: _scaleAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Container(
                              width: isTablet ? 80 : 70,
                              height: isTablet ? 80 : 70,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.refresh,
                                  color: Colors.white,
                                  size: isTablet ? 32 : 28,
                                ),
                                onPressed: _resetTimer,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Main Action Button
                    GestureDetector(
                      onTapDown: (_) => _scaleController.forward(),
                      onTapUp: (_) => _scaleController.reverse(),
                      onTapCancel: () => _scaleController.reverse(),
                      child: AnimatedBuilder(
                        animation: _scaleAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Container(
                              width: isTablet ? 120 : 100,
                              height: isTablet ? 120 : 100,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _isRunning 
                                      ? [Colors.orange[600]!, Colors.orange[800]!]
                                      : [Colors.green[600]!, Colors.green[800]!],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: (_isRunning ? Colors.orange : Colors.green).withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: Icon(
                                  _isRunning ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                  size: isTablet ? 48 : 40,
                                ),
                                onPressed: () {
                                  if (_isRunning) {
                                    _pauseTimer();
                                  } else {
                                    _startTimer();
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Clock Button
                    GestureDetector(
                      onTapDown: (_) => _scaleController.forward(),
                      onTapUp: (_) => _scaleController.reverse(),
                      onTapCancel: () => _scaleController.reverse(),
                      child: AnimatedBuilder(
                        animation: _scaleAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Container(
                              width: isTablet ? 80 : 70,
                              height: isTablet ? 80 : 70,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.access_time,
                                  color: Colors.white,
                                  size: isTablet ? 32 : 28,
                                ),
                                onPressed: _isRunning ? null : _showEditDialog,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
