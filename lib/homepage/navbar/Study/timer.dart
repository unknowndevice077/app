import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

// Study Timer Page with a simple start/stop timer
class StudyTimerPage extends StatefulWidget {
  const StudyTimerPage({super.key});

  @override
  State<StudyTimerPage> createState() => _StudyTimerPageState();
}

class _StudyTimerPageState extends State<StudyTimerPage> {
  int _minutes = 15;
  int _seconds = 0;
  Timer? _timer;
  bool _isRunning = false;
  String? _selectedClassId;
  List<Map<String, dynamic>> _classes = [];
  
  // Add these variables to track original timer values
  int _originalMinutes = 15;
  int _originalSeconds = 0;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('Classes').get();
      setState(() {
        _classes = snapshot.docs.map((doc) => {
          'id': doc.id,
          'title': doc.data()['title'] ?? 'Unknown Class',
          'color': doc.data()['color'] ?? Colors.blue.value,
        }).toList();
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
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_minutes == 0 && _seconds == 0) {
          _timer?.cancel();
          _isRunning = false;
          _saveStudySession(); // Save when timer completes naturally
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
    setState(() => _isRunning = false);
    
    // Save progress when pausing
    _saveStudySession();
  }

  Future<void> _saveStudySession() async {
    // Calculate actual time studied based on original vs current time
    final originalTotalSeconds = (_originalMinutes * 60) + _originalSeconds;
    final remainingTotalSeconds = (_minutes * 60) + _seconds;
    final studiedSeconds = originalTotalSeconds - remainingTotalSeconds;
    final studiedMinutes = (studiedSeconds / 60).floor(); // Use floor instead of round
    
    // Save even if less than a minute (but more than 0 seconds)
    if (studiedSeconds <= 0) return;
    
    try {
      // ALWAYS save to STATISTICS collection (overall time tracking)
      await FirebaseFirestore.instance
          .collection('STATISTICS')
          .add({
        'minutesStudied': studiedMinutes,
        'secondsStudied': studiedSeconds,
        'subjectId': _selectedClassId, // null if no subject selected
        'subjectTitle': _selectedClassId != null 
            ? _classes.firstWhere(
                (c) => c['id'] == _selectedClassId,
                orElse: () => {'title': 'Unknown'}
              )['title'] 
            : 'General Study', // Default title when no subject
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toIso8601String().split('T')[0],
        'sessionType': _selectedClassId != null ? 'subject_specific' : 'general',
      });
      
      // Also save to subject-specific collection if a subject is selected
      if (_selectedClassId != null) {
        await FirebaseFirestore.instance
            .collection('Classes')
            .doc(_selectedClassId)
            .collection('subjectTime')
            .add({
          'minutesStudied': studiedMinutes,
          'secondsStudied': studiedSeconds,
          'timestamp': FieldValue.serverTimestamp(),
          'date': DateTime.now().toIso8601String().split('T')[0],
        });
        
        await FirebaseFirestore.instance
            .collection('Classes')
            .doc(_selectedClassId)
            .collection('studySessions')
            .add({
          'minutes': studiedMinutes,
          'seconds': studiedSeconds,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      
      if (mounted) {
        final timeMessage = studiedSeconds < 60 
            ? '$studiedSeconds seconds'
            : studiedSeconds < 120
                ? '1 minute and ${studiedSeconds % 60} seconds'
                : studiedMinutes > 0
                    ? '$studiedMinutes minutes and ${studiedSeconds % 60} seconds'
                    : '$studiedSeconds seconds';
        
        final subjectName = _selectedClassId != null 
            ? _classes.firstWhere(
                (c) => c['id'] == _selectedClassId,
                orElse: () => {'title': 'Unknown'}
              )['title']
            : 'General Study';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Study session saved: $timeMessage for $subjectName'),
            backgroundColor: Colors.green,
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
          ),
        );
      }
    }
  }

  // Helper function to get total study time from STATISTICS collection
  Future<int> getTotalOverallStudyTime() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('STATISTICS')
          .get();
      
      int totalMinutes = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        totalMinutes += (data['minutesStudied'] ?? 0) as int;
      }
      return totalMinutes;
    } catch (e) {
      print('Error getting total overall study time: $e');
      return 0;
    }
  }

  // Helper function to get today's total study time from STATISTICS collection
  Future<int> getTodayOverallStudyTime() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final snapshot = await FirebaseFirestore.instance
          .collection('STATISTICS')
          .where('date', isEqualTo: today)
          .get();
      
      int totalMinutes = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        totalMinutes += (data['minutesStudied'] ?? 0) as int;
      }
      return totalMinutes;
    } catch (e) {
      print('Error getting today overall study time: $e');
      return 0;
    }
  }

  // Helper function to get study time for a specific subject from STATISTICS
  Future<int> getSubjectStudyTimeFromStats(String subjectId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('STATISTICS')
          .where('subjectId', isEqualTo: subjectId)
          .get();
      
      int totalMinutes = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        totalMinutes += (data['minutesStudied'] ?? 0) as int;
      }
      return totalMinutes;
    } catch (e) {
      print('Error getting subject study time from stats: $e');
      return 0;
    }
  }

  // Helper function to get general study time (no subject selected)
  Future<int> getGeneralStudyTime() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('STATISTICS')
          .where('sessionType', isEqualTo: 'general')
          .get();
      
      int totalMinutes = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        totalMinutes += (data['minutesStudied'] ?? 0) as int;
      }
      return totalMinutes;
    } catch (e) {
      print('Error getting general study time: $e');
      return 0;
    }
  }

  Future<void> _showSubjectSelector() async {
    if (_classes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No subjects available. Create a class first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      isScrollControlled: true, // Add this to prevent overflow
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8, // Limit height
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24, // Handle keyboard
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const Text(
                'Select Subject to Study',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose which subject you want to focus on',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              
              // Make the subject list scrollable
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: _classes.map((classData) {
                      final isSelected = _selectedClassId == classData['id'];
                      final classColor = Color(classData['color'] ?? Colors.blue.value);
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8), // Reduced margin
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), // Reduced padding
                          leading: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: classColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          title: Text(
                            classData['title'],
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis, // Handle long subject names
                            maxLines: 1,
                          ),
                          trailing: isSelected 
                              ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                              : const Icon(Icons.radio_button_unchecked, color: Colors.white54, size: 20),
                          selected: isSelected,
                          selectedTileColor: Colors.white.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onTap: () {
                            setState(() {
                              _selectedClassId = classData['id'];
                            });
                            Navigator.pop(context);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              if (_selectedClassId != null)
                Center(
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedClassId = null;
                      });
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Clear Selection',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // Update the edit dialog to also update original values
  Future<void> _showEditDialog() async {
    int tempMinutes = _minutes;
    int tempSeconds = _seconds;
    
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
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
                  const Text(
                    'Set Timer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Minutes', style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 8),
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
                                    style: const TextStyle(
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
                          const Text('Seconds', style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 8),
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
                                    style: const TextStyle(
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
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _minutes = tempMinutes;
                            _seconds = tempSeconds;
                            // Update original values when setting new timer
                            _originalMinutes = tempMinutes;
                            _originalSeconds = tempSeconds;
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Set'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final isSmallScreen = screenWidth < 600;
    final isLandscape = screenWidth > screenHeight;

    double containerWidth;
    double containerHeight;
    double fontSize;
    double spacing;

    if (isLandscape) {
      // Landscape mode - containers side by side
      containerWidth = screenWidth * 0.35; // Smaller width for side-by-side
      containerHeight = screenHeight * 0.5; // Taller in landscape
      fontSize = screenWidth * 0.12; // Smaller font for landscape
      spacing = 12;
    } else if (isSmallScreen) {
      // Portrait mode - small screen
      containerWidth = screenWidth * 0.85;
      containerHeight = screenHeight * 0.25; // Reduced height for portrait
      fontSize = screenWidth * 0.25;
      spacing = 16;
    } else {
      // Portrait mode - large screen
      containerWidth = 400;
      containerHeight = 200;
      fontSize = 120;
      spacing = 24;
    }

    containerWidth = containerWidth.clamp(200, 500);
    containerHeight = containerHeight.clamp(120, 300);
    fontSize = fontSize.clamp(60, 200);

    final selectedClass = _selectedClassId != null 
        ? _classes.firstWhere(
            (c) => c['id'] == _selectedClassId,
            orElse: () => {'title': 'Unknown', 'color': Colors.blue.value}
          )
        : null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Study Timer', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selectedClass != null 
                    ? Color(selectedClass['color']).withOpacity(0.3)
                    : Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
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
            onPressed: _isRunning ? null : _showSubjectSelector,
          ),
          IconButton(
            icon: const Icon(Icons.access_time, color: Colors.white),
            tooltip: 'Edit Timer',
            onPressed: _isRunning ? null : _showEditDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 16 : 24,
                    vertical: isLandscape ? 8 : 16,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Subject indicator - make smaller in landscape
                      if (selectedClass != null)
                        Container(
                          margin: EdgeInsets.only(bottom: isLandscape ? 8 : 16),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Color(selectedClass['color']).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Color(selectedClass['color']).withOpacity(0.5),
                            ),
                          ),
                          child: Text(
                            selectedClass['title'],
                            style: TextStyle(
                              color: Color(selectedClass['color']),
                              fontSize: isLandscape ? 12 : 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      
                      SizedBox(height: isLandscape ? 8 : spacing),
                      
                      // Timer containers - arrange differently for landscape vs portrait
                      if (isLandscape)
                        // Landscape: Side by side layout
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Minutes container
                            Container(
                              width: containerWidth,
                              height: containerHeight,
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        _minutes.toString().padLeft(2, '0'),
                                        style: TextStyle(
                                          fontSize: fontSize,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          fontFamily: 'Major Mono Display',
                                          letterSpacing: fontSize * -0.03,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'MINUTES',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white70,
                                        letterSpacing: 2,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            // Seconds container
                            Container(
                              width: containerWidth,
                              height: containerHeight,
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        _seconds.toString().padLeft(2, '0'),
                                        style: TextStyle(
                                          fontSize: fontSize,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          fontFamily: 'Major Mono Display',
                                          letterSpacing: fontSize * -0.03,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'SECONDS',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white70,
                                        letterSpacing: 2,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        // Portrait: Stacked layout
                        Column(
                          children: [
                            // Minutes container
                            Center(
                              child: Container(
                                width: containerWidth,
                                height: containerHeight,
                                decoration: BoxDecoration(
                                  color: Colors.grey[900],
                                  borderRadius: BorderRadius.circular(
                                    isSmallScreen ? 24 : 36,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          _minutes.toString().padLeft(2, '0'),
                                          style: TextStyle(
                                            fontSize: fontSize,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            fontFamily: 'Major Mono Display',
                                            letterSpacing: fontSize * -0.03,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'MINUTES',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 16 : 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white70,
                                          letterSpacing: 3,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            
                            SizedBox(height: spacing),
                            
                            // Seconds container
                            Center(
                              child: Container(
                                width: containerWidth,
                                height: containerHeight,
                                decoration: BoxDecoration(
                                  color: Colors.grey[900],
                                  borderRadius: BorderRadius.circular(
                                    isSmallScreen ? 24 : 36,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          _seconds.toString().padLeft(2, '0'),
                                          style: TextStyle(
                                            fontSize: fontSize,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            fontFamily: 'Major Mono Display',
                                            letterSpacing: fontSize * -0.03,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'SECONDS',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 16 : 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white70,
                                          letterSpacing: 3,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      
                      SizedBox(height: isLandscape ? 16 : spacing * 1.5),
                      
                      // Buttons - arrange differently for landscape
                      if (isLandscape)
                        // Landscape: Buttons side by side
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            SizedBox(
                              width: screenWidth * 0.3,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isRunning ? Colors.orange[700] : Colors.green[800],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(color: Colors.white, width: 1.5),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                onPressed: () {
                                  if (_isRunning) {
                                    _pauseTimer();
                                  } else {
                                    _startTimer();
                                  }
                                },
                                child: Text(_isRunning ? 'PAUSE' : 'START'),
                              ),
                            ),
                            
                            SizedBox(
                              width: screenWidth * 0.3,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white, width: 1.5),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _resetTimer,
                                child: const Text('RESET'),
                              ),
                            ),
                          ],
                        )
                      else
                        // Portrait: Buttons stacked
                        Column(
                          children: [
                            SizedBox(
                              width: containerWidth * 0.7,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isRunning ? Colors.orange[700] : Colors.green[800],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(color: Colors.white, width: 1.5),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                onPressed: () {
                                  if (_isRunning) {
                                    _pauseTimer();
                                  } else {
                                    _startTimer();
                                  }
                                },
                                child: Text(_isRunning ? 'PAUSE' : 'START FOCUS'),
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            SizedBox(
                              width: containerWidth * 0.7,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white, width: 1.5),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  textStyle: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _resetTimer,
                                child: const Text('RESET'),
                              ),
                            ),
                          ],
                        ),
                      
                      SizedBox(height: isLandscape ? 8 : spacing),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}