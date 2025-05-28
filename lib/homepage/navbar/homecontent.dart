import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

class Homecontent extends StatefulWidget {
  const Homecontent({super.key});

  @override
  State<Homecontent> createState() => _HomecontentState();
}

class _HomecontentState extends State<Homecontent> {
  double _totalHours = 0.0;
  int _selectedDayIndex = DateTime.now().weekday - 1; // 0 = Monday
  Timer? _timer;
  StreamSubscription? _classesSubscription;

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _fetchTotalHours();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _classesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchTotalHours() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('STATISTICS')
          .get();
      if (!mounted) return;
      double total = 0.0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('hours') && data['hours'] != null) {
          total += (data['hours'] as num).toDouble();
        }
      }
      if (mounted) {
        setState(() {
          _totalHours = total;
        });
      }
    } catch (e) {
      print('Error fetching total hours: $e');
    }
  }

  String getTodayName() {
    final weekday = DateTime.now().weekday;
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[weekday - 1];
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning!';
    if (hour < 17) return 'Good Afternoon!';
    return 'Good Evening!';
  }

  Future<int> _fetchWeeklyDeadlines() async {
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final nextMonday = monday.add(const Duration(days: 7));

    int deadlineCount = 0;

    try {
      final classesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('Classes')
          .get();
      if (!mounted) return 0;

      for (var classDoc in classesSnapshot.docs) {
        if (!mounted) return deadlineCount;
        final eventsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('Classes')
            .doc(classDoc.id)
            .collection('events')
            .where('type', isEqualTo: 'deadline')
            .where(
              'date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(monday.toUtc()),
            )
            .where(
              'date',
              isLessThan: Timestamp.fromDate(nextMonday.toUtc()),
            )
            .get();
        if (!mounted) return deadlineCount;
        deadlineCount += eventsSnapshot.docs.length;
      }
    } catch (e) {
      print('Error fetching weekly deadlines: $e');
    }

    return deadlineCount;
  }

  Future<int> _fetchTotalDeadlines() async {
    int deadlineCount = 0;

    try {
      final classesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('Classes')
          .get();
      if (!mounted) return 0;

      for (var classDoc in classesSnapshot.docs) {
        if (!mounted) return deadlineCount;
        final eventsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('Classes')
            .doc(classDoc.id)
            .collection('events')
            .where('type', isEqualTo: 'deadline')
            .get();
        if (!mounted) return deadlineCount;
        deadlineCount += eventsSnapshot.docs.length;
      }
    } catch (e) {
      print('Error fetching total deadlines: $e');
    }

    return deadlineCount;
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDayOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final daysOfWeek = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final daysShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return CustomScrollView(
      slivers: [
        // Greeting, stats, weekday selector
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 24,
                      top: 32,
                      right: 24,
                    ),
                    child: Text(
                      getGreeting(),
                      style: GoogleFonts.dmSerifText(
                        color: Colors.black,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Statistics Row
                  SizedBox(
                    height: 150,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _StatsCard(
                            label: "Total Hours",
                            value: _totalHours,
                            color: Colors.blueAccent,
                          ),
                          FutureBuilder<int>(
                            future: _fetchTotalDeadlines(),
                            builder: (context, snapshot) {
                              final totalDeadlines = snapshot.data ?? 0;
                              return _DeadlinesCard(
                                count: totalDeadlines,
                                color: Colors.red,
                                isWeekly: false,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Today's Classes Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      "Today's Classes",
                      style: GoogleFonts.dmSerifText(
                        color: Colors.black,
                        fontSize: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  // Weekday selector
                  SizedBox(
                    height: 70,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 7,
                      itemBuilder: (context, index) {
                        final date = firstDayOfWeek.add(Duration(days: index));
                        final isToday =
                            date.day == now.day &&
                            date.month == now.month &&
                            date.year == now.year;
                        final isSelected = _selectedDayIndex == index;
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 8,
                          ),
                          child: GestureDetector(
                            onTap:
                                () => setState(() => _selectedDayIndex = index),
                            child: Container(
                              width: 48,
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? Colors.blueAccent
                                        : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${date.day}',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          isSelected
                                              ? Colors.white
                                              : Colors.black,
                                    ),
                                  ),
                                  Text(
                                    daysShort[index],
                                    style: TextStyle(
                                      fontSize: 13,
                                      color:
                                          isSelected
                                              ? Colors.white
                                              : (isToday
                                                  ? Colors.blueAccent
                                                  : Colors.grey),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
        // Class cards
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('Classes')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return SliverFillRemaining(
                child: Center(
                  child: Text(
                    'No classes found.',
                    style: GoogleFonts.dmSerifText(
                      fontSize: 20,
                      color: Colors.grey,
                    ),
                  ),
                ),
              );
            }
            final docs = snapshot.data!.docs;
            final selectedDayName = daysOfWeek[_selectedDayIndex];
            final todayClasses =
                docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final List days =
                      data['days'] != null
                          ? List<String>.from(data['days'])
                          : <String>[];
                  return days.contains(selectedDayName);
                }).toList();

            // Sort by start time
            todayClasses.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aTime = aData['time'] ?? '';
              final bTime = bData['time'] ?? '';
              try {
                final aStart = _parseTimeOfDay(aTime.split('-')[0].trim());
                final bStart = _parseTimeOfDay(bTime.split('-')[0].trim());
                final aMinutes = aStart.hour * 60 + aStart.minute;
                final bMinutes = bStart.hour * 60 + bStart.minute;
                return aMinutes.compareTo(bMinutes);
              } catch (_) {
                return 0;
              }
            });

            // Remove classes that have already ended
            final now = TimeOfDay.now();
            todayClasses.removeWhere((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final time = data['time'] ?? '';
              try {
                final times = time.split('-');
                if (times.length == 2) {
                  final end = _parseTimeOfDay(times[1].trim());
                  final nowMinutes = now.hour * 60 + now.minute;
                  final endMinutes = end.hour * 60 + end.minute;
                  return nowMinutes >= endMinutes;
                }
              } catch (_) {}
              return false;
            });

            return SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final doc = todayClasses[index];
                final data = doc.data() as Map<String, dynamic>;
                final classModel = ClassModel(
                  title: data['title'] ?? '',
                  time: data['time'] ?? '',
                  location: data['location'] ?? '',
                  teacher: data['teacher'] ?? '',
                  notes: data['notes'] ?? '',
                  color: Color(data['color'] ?? Colors.white.value),
                  days:
                      data['days'] != null
                          ? List<String>.from(data['days'])
                          : <String>[],
                );

                // Parse class time
                final now = TimeOfDay.now();
                bool isCurrent = false;
                String startTimeLabel = '';
                try {
                  final times = classModel.time.split('-');
                  if (times.length == 2) {
                    final start = _parseTimeOfDay(times[0].trim());
                    final end = _parseTimeOfDay(times[1].trim());
                    isCurrent =
                        daysOfWeek[_selectedDayIndex] == getTodayName() &&
                        _isNowBetween(now, start, end);
                    startTimeLabel = times[0].trim();
                  }
                } catch (_) {}

                return Padding(
                  padding: const EdgeInsets.only(
                    left: 0.0,
                    right: 20.0,
                    top: 10.0,
                    bottom: 10.0,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isCurrent)
                        SizedBox(
                          width: 48,
                          child: Text(
                            startTimeLabel,
                            style: TextStyle(
                              fontSize: 14,
                              color: classModel.color,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      if (!isCurrent) const SizedBox(width: 8),
                      if (!isCurrent)
                        SizedBox(
                          height: 120,
                          child: Center(
                            child: Container(
                              width: 8,
                              height: 120,
                              decoration: BoxDecoration(
                                color: classModel.color.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    classModel.color == Colors.white
                                        ? Border.all(
                                          color: Colors.black,
                                          width: 1.5,
                                        )
                                        : null,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 12),
                      // Class card
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: isCurrent ? 400 : 300,
                              minWidth: 0,
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              decoration: BoxDecoration(
                                color:
                                    isCurrent
                                        ? classModel.color.withOpacity(0.60)
                                        : (classModel.color.value ==
                                                Colors.white.value
                                            ? Colors.transparent
                                            : classModel.color.withOpacity(
                                              0.10,
                                            )),
                                borderRadius: BorderRadius.circular(24),
                                border:
                                    classModel.color.value == Colors.white.value
                                        ? Border.all(
                                          color: Colors.black,
                                          width: 2,
                                        )
                                        : null,
                                boxShadow:
                                    isCurrent
                                        ? [
                                          BoxShadow(
                                            color: classModel.color.withOpacity(
                                              0.18,
                                            ),
                                            blurRadius: 24,
                                            offset: const Offset(0, 8),
                                          ),
                                        ]
                                        : [],
                              ),
                              height: isCurrent ? 170 : 110,
                              padding: EdgeInsets.only(
                                left: 24,
                                right: isCurrent ? 28 : 12,
                                top: isCurrent ? 20 : 10,
                                bottom: isCurrent ? 20 : 10,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        classModel.title,
                                        style: TextStyle(
                                          fontSize: isCurrent ? 22 : 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        "Class",
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    classModel.time.isNotEmpty
                                        ? classModel.time
                                        : 'No time set',
                                    style: TextStyle(
                                      fontSize: isCurrent ? 16 : 13,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    classModel.teacher,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }, childCount: todayClasses.length),
            );
          },
        ),
        // ✅ FIXED: Event cards - Now uses per-user Classes collection
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('Classes')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SliverToBoxAdapter(child: SizedBox());
            }
            final docs = snapshot.data!.docs;
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchTodayEvents(
                docs,
                firstDayOfWeek.add(Duration(days: _selectedDayIndex)),
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final events = snapshot.data ?? [];
                if (events.isEmpty) {
                  return const SliverToBoxAdapter(child: SizedBox());
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final event = events[index];
                    return _EventCard(event: event);
                  }, childCount: events.length),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

// Helper to parse "HH:mm AM/PM" to TimeOfDay
TimeOfDay _parseTimeOfDay(String time) {
  final format = RegExp(r'(\d+):(\d+)\s*(AM|PM)', caseSensitive: false);
  final match = format.firstMatch(time);
  if (match == null) throw FormatException('Invalid time');
  int hour = int.parse(match.group(1)!);
  int minute = int.parse(match.group(2)!);
  final period = match.group(3)!.toUpperCase();
  if (period == 'PM' && hour != 12) hour += 12;
  if (period == 'AM' && hour == 12) hour = 0;
  return TimeOfDay(hour: hour, minute: minute);
}

// Helper to check if now is between start and end
bool _isNowBetween(TimeOfDay now, TimeOfDay start, TimeOfDay end) {
  final nowMinutes = now.hour * 60 + now.minute;
  final startMinutes = start.hour * 60 + start.minute;
  final endMinutes = end.hour * 60 + end.minute;
  return nowMinutes >= startMinutes && nowMinutes < endMinutes;
}

// ✅ FIXED: Fetch events for the selected day - Already using per-user path
Future<List<Map<String, dynamic>>> _fetchTodayEvents(
  List<QueryDocumentSnapshot> classDocs,
  DateTime selectedDate,
) async {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  List<Map<String, dynamic>> events = [];
  final startOfDay = DateTime(
    selectedDate.year,
    selectedDate.month,
    selectedDate.day,
  );
  final endOfDay = startOfDay.add(const Duration(days: 1));
  for (var doc in classDocs) {
    final classData = doc.data() as Map<String, dynamic>;
    final classTitle = classData['title'] ?? '';
    final eventsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('Classes')
        .doc(doc.id)
        .collection('events')
        .where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .get();
    for (var eventDoc in eventsSnapshot.docs) {
      final eventData = eventDoc.data();
      events.add({
        'title': eventData['title'] ?? '',
        'type': eventData['type'] ?? '',
        'date': (eventData['date'] as Timestamp).toDate(),
        'classTitle': classTitle,
      });
    }
  }
  return events;
}

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    String timeLabel = '';

    // Dynamically set label based on event type
    String label = 'Event';
    if (event['type'] != null && (event['type'] as String).isNotEmpty) {
      label =
          (event['type'] as String).substring(0, 1).toUpperCase() +
          (event['type'] as String).substring(1).toLowerCase();
    }

    // Set card color based on label - LIGHTER COLORS
    Color cardColor = Colors.grey[200]!;
    if (label == 'Exam') {
      cardColor = Colors.redAccent.withOpacity(0.15);
    } else if (label == 'Deadline') {
      cardColor = Colors.yellow[600]!.withOpacity(0.15);
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    event['classTitle'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (label == 'Exam')
              FutureBuilder<String>(
                future: _getClassTime(event['classTitle']),
                builder: (context, snapshot) {
                  final classTime = snapshot.data ?? 'Time not available';
                  return Text(
                    classTime,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              )
            else if (label == 'Deadline')
              Text(
                event['date'] != null
                    ? "${event['date'].day}/${event['date'].month}/${event['date'].year}"
                    : '',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ✅ FIXED: Get class time - Now uses per-user Classes collection
  Future<String> _getClassTime(String? classTitle) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    if (classTitle == null || classTitle.isEmpty) return 'Time not available';

    try {
      final classSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('Classes')
          .where('title', isEqualTo: classTitle)
          .limit(1)
          .get();
      if (classSnapshot.docs.isNotEmpty) {
        return classSnapshot.docs.first.data()['time'] ?? 'Time not available';
      }
    } catch (e) {
      print('Error fetching class time: $e');
    }
    return 'Time not available';
  }

  String _formatEventTime(dynamic date, BuildContext context) {
    DateTime dt;
    if (date is DateTime) {
      dt = date;
    } else if (date is Timestamp) {
      dt = date.toDate();
    } else {
      return '';
    }
    return TimeOfDay.fromDateTime(dt).format(context);
  }
}

class _StatsCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _StatsCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    int hours = value.floor();
    int minutes = ((value - hours) * 60).round();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Textual stats
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$hours',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    'h ',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    minutes.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    'm',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "Total study time",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          // Right: Gauge
          CustomPaint(
            size: const Size(70, 70),
            painter: _GaugePainter(color),
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.access_time_rounded,
                  color: Colors.grey,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final Color color;
  _GaugePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final startAngle = 3.14159 * 0.75;
    final sweepAngle = 3.14159 * 1.5;
    final paint =
        Paint()
          ..shader = SweepGradient(
            startAngle: 0,
            endAngle: 3.14159 * 2,
            colors: [Colors.greenAccent, Colors.yellow, Colors.orange, color],
          ).createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(
        center: size.center(Offset.zero),
        radius: size.width / 2 - 8,
      ),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Dummy ClassModel for demonstration. Replace with your actual model if needed.
class ClassModel {
  final String title;
  final String time;
  final String location;
  final String teacher;
  final String notes;
  final Color color;
  final List<String> days;

  ClassModel({
    required this.title,
    required this.time,
    required this.location,
    required this.teacher,
    required this.notes,
    required this.color,
    required this.days,
  });
}

class _DeadlinesCard extends StatelessWidget {
  final int count;
  final Color color;
  final bool isWeekly;

  const _DeadlinesCard({
    required this.count,
    required this.color,
    this.isWeekly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Textual stats
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isWeekly ? "Deadlines This Week" : "Total Deadlines",
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isWeekly ? "Total weekly deadlines" : "Total deadlines",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          // Right: Icon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.assignment_turned_in, color: color, size: 28),
            ),
        ],
      ),
    );
  }
}
