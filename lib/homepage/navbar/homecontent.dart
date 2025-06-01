import 'package:app/homepage/navbar/userprofile.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/profile_picture_provider.dart';
import 'package:app/login/Auth.dart';

class Homecontent extends StatefulWidget {
  final String? greeting; // ✅ Add this line
  final String? username;
  final Widget? profilePicture;

  const Homecontent({
    super.key,
    this.greeting, // ✅ Add this line
    this.username,
    this.profilePicture,
  });

  @override
  State<Homecontent> createState() => _HomecontentState();
}

class _HomecontentState extends State<Homecontent> {
  double _totalStudyHours = 0.0;
  int _totalClasses = 0;
  int _totalExams = 0;
  int _selectedDayIndex = DateTime.now().weekday - 1;
  Timer? _timer;
  Timer? _homeTimer;
  StreamSubscription? _classesSubscription;

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _fetchAllStatistics();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _homeTimer?.cancel();
    _classesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchAllStatistics() async {
    await Future.wait([
      _fetchTotalStudyHours(),
      _fetchTotalClasses(),
      _fetchTotalExams(),
    ]);
  }

  Future<void> _fetchTotalStudyHours() async {
    try {
      double totalHours = 0.0;
      final statisticsSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('STATISTICS')
              .get();

      if (statisticsSnapshot.docs.isNotEmpty) {
        for (var doc in statisticsSnapshot.docs) {
          final data = doc.data();
          if (data.containsKey('hours') && data['hours'] != null) {
            totalHours += (data['hours'] as num).toDouble();
          }
          if (data.containsKey('minutes') && data['minutes'] != null) {
            totalHours += (data['minutes'] as num).toDouble() / 60.0;
          }
          if (data.containsKey('duration') && data['duration'] != null) {
            totalHours +=
                (data['duration'] as num).toDouble() / (1000 * 60 * 60);
          }
        }
      } else {
        final studySessionsSnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('StudySessions')
                .get();

        for (var doc in studySessionsSnapshot.docs) {
          final data = doc.data();
          if (data.containsKey('duration')) {
            if (data.containsKey('durationUnit') &&
                data['durationUnit'] == 'minutes') {
              totalHours += (data['duration'] as num).toDouble() / 60.0;
            } else if (data.containsKey('durationUnit') &&
                data['durationUnit'] == 'hours') {
              totalHours += (data['duration'] as num).toDouble();
            } else {
              totalHours += (data['duration'] as num).toDouble() / 60.0;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _totalStudyHours = totalHours;
        });
      }
    } catch (e) {
      print('Error fetching total study hours: $e');
    }
  }

  Future<void> _fetchTotalClasses() async {
    try {
      final classesSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('Classes')
              .get();

      if (mounted) {
        setState(() {
          _totalClasses = classesSnapshot.docs.length;
        });
      }
    } catch (e) {
      print('Error fetching total classes: $e');
    }
  }

  Future<void> _fetchTotalExams() async {
    try {
      int examCount = 0;
      final classesSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('Classes')
              .get();

      for (var classDoc in classesSnapshot.docs) {
        if (!mounted) return;
        final eventsSnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('Classes')
                .doc(classDoc.id)
                .collection('events')
                .where('type', isEqualTo: 'exam')
                .get();
        if (!mounted) return;
        examCount += eventsSnapshot.docs.length;
      }

      final globalEventsSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('Events')
              .where('type', isEqualTo: 'exam')
              .get();
      examCount += globalEventsSnapshot.docs.length;

      if (mounted) {
        setState(() {
          _totalExams = examCount;
        });
      }
    } catch (e) {
      print('Error fetching total exams: $e');
    }
  }

  Future<int> getTotalDeadlines() async {
    int deadlineCount = 0;
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final classesSnapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('Classes')
            .get();

    for (var classDoc in classesSnapshot.docs) {
      final eventsSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('Classes')
              .doc(classDoc.id)
              .collection('events')
              .where('type', isEqualTo: 'deadline')
              .get();
      deadlineCount += eventsSnapshot.docs.length;
    }

    final eventsSnapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('Events')
            .where('type', isEqualTo: 'deadline')
            .get();
    deadlineCount += eventsSnapshot.docs.length;

    return deadlineCount;
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

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (context) => Auth()));
  }

  // Add this method inside the _HomecontentState class:
  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 18) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  String _getTrimmedUsername() {
    // Check if widget.username is provided and not empty
    if (widget.username != null && widget.username!.trim().isNotEmpty) {
      return widget.username!;
    }
    
    // If no custom username, get the current user's email and trim it
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email != null) {
      final email = user!.email!;
      // Extract the part before @ symbol
      if (email.contains('@')) {
        return email.split('@')[0];
      }
      return email; // Return full email if no @ found (shouldn't happen)
    }
    
    // Fallback if no user or email
    return 'User';
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

    final titleFontSize = 32.0; // Or use your responsive logic if needed

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // GREETING HEADER
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 24,
              right: 24,
              bottom: 16,
            ),
            child: Row(
              children: [
                // Profile picture clickable
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const UserProfile()),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.black,
                        width: 2, // Adjust border width as needed
                      ),
                    ),
                    child: Consumer<ProfilePictureProvider>(
                      builder: (context, profileProvider, child) {
                        return profileProvider.getProfilePictureWidget(
                          radius: 24,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Greeting (bold)
                    Text(
                      getGreeting(),
                      style: GoogleFonts.dmSerifText(
                        fontSize: titleFontSize * 0.6,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    // Username below greeting (bold, smaller) - Trimmed email if no custom username
                    Text(
                      _getTrimmedUsername(),
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Builder(
                  builder:
                      (context) => IconButton(
                        icon: const Icon(
                          Icons.menu,
                          color: Colors.black,
                          size: 28,
                        ),
                        tooltip: 'Open Menu',
                        onPressed: () {
                          Scaffold.of(context).openEndDrawer();
                        },
                      ),
                ),
              ],
            ),
          ),
          // Main content
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Statistics Row
                SizedBox(
                  height: 150,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _StatsCard(
                          label: "Total Study Time",
                          value: _totalStudyHours,
                          color: Colors.blueAccent,
                          icon: Icons.access_time_rounded,
                          isHours: true,
                        ),
                        _CountCard(
                          label: "Total Classes",
                          count: _totalClasses,
                          color: Colors.green,
                          icon: Icons.school,
                        ),
                        _CountCard(
                          label: "Total Exams",
                          count: _totalExams,
                          color: Colors.red,
                          icon: Icons.quiz,
                        ),
                        FutureBuilder<int>(
                          future: getTotalDeadlines(),
                          builder: (context, snapshot) {
                            final count = snapshot.data ?? 0;
                            return _CountCard(
                              label: "Total Deadlines",
                              count: count,
                              color: Colors.orange,
                              icon: Icons.assignment_late,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
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
                    physics: const BouncingScrollPhysics(),
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
              ],
            ),
          ),
          // Class cards
          StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('Classes')
                    .snapshots(),
            builder: (context, snapshot) {
              print('StreamBuilder state: ${snapshot.connectionState}');
              print('Has data: ${snapshot.hasData}');
              print('Has error: ${snapshot.hasError}');
              if (snapshot.hasError) {
                print('Error: ${snapshot.error}');
              }
              if (snapshot.hasData) {
                print('Documents count: ${snapshot.data!.docs.length}');
              }

              // ✅ FIXED: Only show loading if there's no data yet
              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(50),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              // ✅ Handle error state
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(50),
                    child: Text(
                      'Error loading classes: ${snapshot.error}',
                      style: GoogleFonts.dmSerifText(
                        fontSize: 18,
                        color: Colors.red,
                      ),
                    ),
                  ),
                );
              }

              // ✅ Handle empty data (keep your existing code)
              if (snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(50),
                    child: Text(
                      'No classes found.\n\nNavigate to classes to add your first class!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSerifText(
                        fontSize: 20,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                );
              }

              final docs = snapshot.data!.docs;
              final daysOfWeek = [
                'Monday',
                'Tuesday',
                'Wednesday',
                'Thursday',
                'Friday',
                'Saturday',
                'Sunday',
              ];
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

              if (todayClasses.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(50),
                    child: Text(
                      'No classes for today.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSerifText(
                        fontSize: 20,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: List.generate(todayClasses.length, (index) {
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
                    child: Column(
                      children: [
                        Row(
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
                                              ? classModel.color.withOpacity(
                                                0.60,
                                              )
                                              : (classModel.color.value ==
                                                      Colors.white.value
                                                  ? Colors.transparent
                                                  : classModel.color
                                                      .withOpacity(0.10)),
                                      borderRadius: BorderRadius.circular(24),
                                      border:
                                          classModel.color.value ==
                                                  Colors.white.value
                                              ? Border.all(
                                                color: Colors.black,
                                                width: 2,
                                              )
                                              : null,
                                      boxShadow:
                                          isCurrent
                                              ? [
                                                BoxShadow(
                                                  color: classModel.color
                                                      .withOpacity(0.18),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: _fetchClassEvents(doc.id, classModel.title),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox();
                            }
                            if (snapshot.hasError) {
                              return const Padding(
                                padding: EdgeInsets.all(8),
                                child: Text(
                                  'Error loading events',
                                  style: TextStyle(color: Colors.red),
                                ),
                              );
                            }
                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return const Padding(padding: EdgeInsets.all(8));
                            }
                            final events = snapshot.data!;
                            return Column(
                              children:
                                  events
                                      .map((event) => _EventCard(event: event))
                                      .toList(),
                            );
                          },
                        ),
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: _fetchClassDayEvents(
                            classModel.title,
                            firstDayOfWeek.add(
                              Duration(days: _selectedDayIndex),
                            ),
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox();
                            }
                            if (snapshot.hasError) {
                              return const Padding(
                                padding: EdgeInsets.all(8),
                                child: Text(
                                  'Error loading events',
                                  style: TextStyle(color: Colors.red),
                                ),
                              );
                            }
                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            final events = snapshot.data!;
                            return Column(
                              children:
                                  events.map((event) {
                                    String label =
                                        event['type'] == 'deadline'
                                            ? 'Deadline'
                                            : event['type'] == 'exam'
                                            ? 'Exam'
                                            : 'Event';
                                    Color cardColor =
                                        event['type'] == 'deadline'
                                            ? Colors.yellow[600]!.withOpacity(
                                              0.15,
                                            )
                                            : event['type'] == 'exam'
                                            ? Colors.redAccent.withOpacity(0.15)
                                            : Colors.grey[200]!;

                                    return Container(
                                      margin: const EdgeInsets.only(
                                        left: 36,
                                        right: 0,
                                        top: 0,
                                        bottom: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: cardColor,
                                        borderRadius: const BorderRadius.only(
                                          topRight: Radius.circular(18),
                                          bottomRight: Radius.circular(18),
                                        ),
                                        border: Border(
                                          left: BorderSide(
                                            color: classModel.color,
                                            width: 6,
                                          ),
                                        ),
                                      ),
                                      child: ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 18,
                                              vertical: 2,
                                            ),
                                        leading: Icon(
                                          event['type'] == 'deadline'
                                              ? Icons.assignment_late
                                              : Icons.quiz,
                                          color:
                                              event['type'] == 'deadline'
                                                  ? Colors.orange
                                                  : Colors.red,
                                        ),
                                        title: Text(
                                          label,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Colors.black,
                                          ),
                                        ),
                                        subtitle: Text(
                                          event['date'] != null
                                              ? "${event['date'].day}/${event['date'].month}/${event['date'].year}"
                                              : '',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        trailing: const Icon(
                                          Icons.arrow_right_alt,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchClassEvents(
    String classId,
    String title,
  ) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final eventsSnapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('Classes')
            .doc(classId)
            .collection('events')
            .get();
    return eventsSnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'title': data['title'] ?? '',
        'type': data['type'] ?? '',
        'date': data['date'],
        'title': title,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchClassDayEvents(
    String title,
    DateTime selectedDate,
  ) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final startOfDay = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final endOfDay = startOfDay.add(const Duration(days: 1));
    List<Map<String, dynamic>> events = [];

    final globalEventsSnapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('Events')
            .where(
              'date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
            )
            .where('date', isLessThan: Timestamp.fromDate(endOfDay))
            .get();

    for (var doc in globalEventsSnapshot.docs) {
      final data = doc.data();
      if ((data['type'] ?? '').toString().toLowerCase() == 'deadline' ||
          (data['type'] ?? '').toString().toLowerCase() == 'exam') {
        if ((data['title'] ?? '').toString().trim().toLowerCase() ==
            title.trim().toLowerCase()) {
          events.add({
            'title': data['title'] ?? '',
            'type': data['type'] ?? '',
            'date': (data['date'] as Timestamp).toDate(),
            'title': title,
          });
        }
      }
    }

    final classesSnapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('Classes')
            .where('title', isEqualTo: title)
            .limit(1)
            .get();

    if (classesSnapshot.docs.isNotEmpty) {
      final classId = classesSnapshot.docs.first.id;
      final classEventsSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('Classes')
              .doc(classId)
              .collection('events')
              .where(
                'date',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
              )
              .where('date', isLessThan: Timestamp.fromDate(endOfDay))
              .get();

      for (var doc in classEventsSnapshot.docs) {
        final data = doc.data();
        if (data['type'] == 'deadline' || data['type'] == 'exam') {
          events.add({
            'title': data['title'] ?? '',
            'type': data['type'] ?? '',
            'date': (data['date'] as Timestamp).toDate(),
            'title': title,
          });
        }
      }
    }

    return events;
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

class ClassModel {
  final String title;
  final String time;
  final String location;
  final String teacher;
  final String notes;
  final Color color;
  final List<String> days;
  final bool notify; // ✅ Add this line

  ClassModel({
    required this.title,
    required this.time,
    required this.location,
    required this.teacher,
    required this.notes,
    required this.color,
    required this.days,
    this.notify = true, // ✅ Add this line with default value
  });

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'time': time,
      'location': location,
      'teacher': teacher,
      'notes': notes,
      'color': color.value,
      'days': days,
      'notify': notify, // ✅ Add this line
    };
  }

  factory ClassModel.fromFirestore(Map<String, dynamic> data) {
    return ClassModel(
      title: data['title'] ?? '',
      time: data['time'] ?? '',
      location: data['location'] ?? '',
      teacher: data['teacher'] ?? '',
      notes: data['notes'] ?? '',
      color: Color(data['color'] ?? Colors.white.value),
      days: data['days'] != null ? List<String>.from(data['days']) : <String>[],
      notify: data['notify'] ?? true, // ✅ Add this line
    );
  }
}

class _StatsCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final IconData icon;
  final bool isHours;

  const _StatsCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.isHours = false,
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
              if (isHours) ...[
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
              ] else ...[
                Text(
                  '${value.toInt()}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                isHours ? "Total Hours" : "Total Hours",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ],
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _CountCard({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
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
                "Total items",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    String label = 'Event';
    if (event['type'] != null && (event['type'] as String).isNotEmpty) {
      label =
          (event['type'] as String)[0].toUpperCase() +
          (event['type'] as String).substring(1).toLowerCase();
    }

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
                    event['title'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (label == 'Exam')
              FutureBuilder<String>(
                future: _getClassTime(event['title']),
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

  // Helper method for fetching class time
  Future<String> _getClassTime(String? title) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    if (title == null || title.isEmpty) return 'Time not available';
    try {
      final classSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('Classes')
              .where('title', isEqualTo: title)
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
}
