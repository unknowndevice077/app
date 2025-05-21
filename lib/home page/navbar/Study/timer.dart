import 'package:flutter/material.dart';
import 'dart:async';

// Study Timer Page with a simple start/stop timer
class StudyTimerPage extends StatefulWidget {
  const StudyTimerPage({super.key});

  @override
  State<StudyTimerPage> createState() => _StudyTimerPageState();
}

class _StudyTimerPageState extends State<StudyTimerPage> {
  int _minutes = 75;
  int _seconds = 0;
  Timer? _timer;
  bool _isRunning = false;

  void _startTimer() {
    if (_isRunning) return;
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_minutes == 0 && _seconds == 0) {
          _timer?.cancel();
          _isRunning = false;
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
    _timer?.cancel();
    setState(() {
      _minutes = 0;
      _seconds = 0;
      _isRunning = false;
    });
  }

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
              Stack(
                alignment: Alignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Minutes Picker
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Minutes', style: TextStyle(color: Colors.white70)),
                          SizedBox(
                            height: 120,
                            width: 70,
                            child: ListWheelScrollView.useDelegate(
                              itemExtent: 36,
                              diameterRatio: 1.2,
                              physics: const FixedExtentScrollPhysics(),
                              controller: FixedExtentScrollController(initialItem: tempMinutes),
                              onSelectedItemChanged: (value) {
                                tempMinutes = value;
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                builder: (context, index) => Text(
                                  index.toString().padLeft(2, '0'),
                                  style: const TextStyle(
                                    fontSize: 28,
                                    color: Colors.white,
                                    fontFamily: 'Major Mono Display',
                                  ),
                                ),
                                childCount: 100,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 32),
                      // Seconds Picker
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Seconds', style: TextStyle(color: Colors.white70)),
                          SizedBox(
                            height: 120,
                            width: 70,
                            child: ListWheelScrollView.useDelegate(
                              itemExtent: 36,
                              diameterRatio: 1.2,
                              physics: const FixedExtentScrollPhysics(),
                              controller: FixedExtentScrollController(initialItem: tempSeconds),
                              onSelectedItemChanged: (value) {
                                tempSeconds = value;
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                builder: (context, index) => Text(
                                  index.toString().padLeft(2, '0'),
                                  style: const TextStyle(
                                    fontSize: 28,
                                    color: Colors.white,
                                    fontFamily: 'Major Mono Display',
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
                  // Two white lines sandwiching the selected number, reaching the edge and lowered
                  Positioned(
                    left: 0,
                    right: 0,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 28), // Lower the lines
                        Container(
                          height: 2,
                          color: Colors.greenAccent,
                          margin: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 36), // itemExtent (36) for spacing between lines
                        Container(
                          height: 2,
                          color: Colors.greenAccent,
                          margin: EdgeInsets.zero,
                        ),
                      ],
                    ),
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
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Focus', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            tooltip: 'Edit Timer',
            onPressed: _isRunning ? null : _showEditDialog,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Minutes
            Container(
              width: MediaQuery.of(context).size.width * 0.65,
              height: MediaQuery.of(context).size.height * 0.34,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(32),
              ),
              child: Center(
                child: Text(
                  _minutes.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    fontSize: 230,
                    fontWeight: FontWeight.w900,
                    color: Color.fromARGB(255, 255, 255, 255),
                    fontFamily: 'Major Mono Display',
                    letterSpacing: -8,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Seconds
            Container(
              width: MediaQuery.of(context).size.width * 0.65,
              height: MediaQuery.of(context).size.height * 0.34,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(32),
              ),
              child: Center(
                child: Text(
                  _seconds.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    fontSize: 230,
                    fontWeight: FontWeight.w900,
                    color: Color.fromARGB(255, 255, 255, 255),
                    fontFamily: 'Major Mono Display',
                    letterSpacing: -8,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20), // Reduced from 40 to 20 to move buttons higher
            // Start/Pause Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[800],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.white),
                ),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              onPressed: () {
                if (_isRunning) {
                  // Pause
                  _timer?.cancel();
                  setState(() => _isRunning = false);
                } else {
                  // Start
                  _startTimer();
                }
              },
              child: Text(_isRunning ? 'Pause' : 'Start Focus'),
            ),
            const SizedBox(height: 10),
            // Reset Button
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _resetTimer,
              child: const Text('Reset'),
            ),
          ],
        ),
      ),
    );
  }
}
