import 'package:app/homepage/navbar/Study/quiz/quiz.dart'; // ✅ ADD THIS
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'topic.dart';
import 'timer.dart';
import 'ask_ai_screen.dart';
class Study extends StatefulWidget {
  const Study({super.key});

  @override
  State<Study> createState() => _StudyState();
}

class _StudyState extends State<Study> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Calculate total study time from ClassTimerSessions and count only topics
  Future<Map<String, dynamic>> _getClassStats(String classId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {'studyTime': 0, 'topicCount': 0};

      // Get study time from ClassTimerSessions
      final studySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('Classes')
          .doc(classId)
          .collection('ClassTimerSessions')
          .get();

      int totalSeconds = 0;
      for (var doc in studySnapshot.docs) {
        final data = doc.data();
        totalSeconds += (data['duration'] ?? 0) as int;
      }

      // Get ALL documents in topics collection for analysis
      final topicSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('Classes')
          .doc(classId)
          .collection('topics')
          .get();

      // More strict filtering for actual topics
      int actualTopicCount = 0;
      List<String> invalidDocs = [];
      
      for (var doc in topicSnapshot.docs) {
        final data = doc.data();
        
        // A valid topic must have:
        // 1. A title field that's not null or empty
        // 2. A createdAt field (topics have this, files have addedAt)
        // 3. NOT have a fileName field (which files have)
        bool isValidTopic = data.containsKey('title') && 
                           data['title'] != null && 
                           data['title'].toString().trim().isNotEmpty &&
                           data.containsKey('createdAt') &&
                           !data.containsKey('fileName') && // Files have this field
                           !data.containsKey('addedAt'); // Files use addedAt instead of createdAt
        
        if (isValidTopic) {
          actualTopicCount++;
        } else {
          // Track invalid documents for potential cleanup
          invalidDocs.add(doc.id);
          print('Invalid/orphaned document found: ${doc.id} with data: $data');
        }
      }

      // Debug: Print detailed analysis
      print('=== ENHANCED DEBUG: Topics for class $classId ===');
      print('Total documents in topics collection: ${topicSnapshot.docs.length}');
      print('Valid topic count: $actualTopicCount');
      print('Invalid/orphaned documents: ${invalidDocs.length}');
      if (invalidDocs.isNotEmpty) {
        print('Invalid doc IDs: $invalidDocs');
      }
      print('=== END ENHANCED DEBUG ===');

      return {
        'studyTime': totalSeconds,
        'topicCount': actualTopicCount,
      };
    } catch (e) {
      print('Error calculating class stats: $e');
      return {'studyTime': 0, 'topicCount': 0};
    }
  }

  // Delete topic
  Future<void> _deleteTopic(String classId, String topicId, String topicTitle) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete Topic'),
          content: Text('Are you sure you want to delete "$topicTitle"?\n\nThis will also delete all files in this topic.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        // Delete all files in this topic first
        final filesSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('Classes')
            .doc(classId)
            .collection('topics')
            .doc(topicId)
            .collection('files')
            .get();

        // Delete all file documents
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in filesSnapshot.docs) {
          batch.delete(doc.reference);
        }

        // Delete the topic document
        batch.delete(
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('Classes')
              .doc(classId)
              .collection('topics')
              .doc(topicId),
        );

        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Text('Topic deleted successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Error deleting topic'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  // Format seconds into readable time
  String _formatStudyTime(int totalSeconds) {
    if (totalSeconds == 0) return '0s';

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      // Show hour:min format when it reaches an hour
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      // Show min:sec format when it's in minutes
      return '${minutes}m ${seconds}s';
    } else {
      // Show just seconds if it hasn't reached a minute yet
      return '${seconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final isTablet = screenWidth > 600;
    final isLargeScreen = screenWidth > 900;
    final isSmallScreen = screenWidth < 400;
    final isVerySmallScreen = screenWidth < 350; // New breakpoint for very small screens

    // Responsive values
    final horizontalPadding = isLargeScreen ? 40.0 : isTablet ? 24.0 : 16.0;
    final verticalPadding = isTablet ? 20.0 : 16.0;
    final titleFontSize = isLargeScreen ? 40.0 : isTablet ? 36.0 : isSmallScreen ? 28.0 : 32.0;
    final cardPadding = isTablet ? 32.0 : 24.0;
    final cardRadius = isTablet ? 28.0 : 24.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            // Responsive App Bar
            SliverAppBar(
              expandedHeight: isTablet ? 140.0 : 120.0,
              floating: false,
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                title: Text(
                  'Study Hub',
                  style: GoogleFonts.dmSerifText(fontSize: 36, color: Colors.black), // ✅ CHANGED FONT
                ),
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, Color(0xFFF8FAFC)],
                    ),
                  ),
                ),
              ),
            ),

            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Feature Cards Section
                  Container(
                    padding: EdgeInsets.all(cardPadding),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(cardRadius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Actions',
                          style: GoogleFonts.inter(
                            fontSize: isTablet ? 24.0 : 20.0,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: isTablet ? 12.0 : 8.0),
                        Text(
                          'Choose your study method',
                          style: GoogleFonts.inter(
                            fontSize: isTablet ? 16.0 : 14.0,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: isTablet ? 32.0 : 24.0),
                        // Responsive layout for feature cards
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth > 600) {
                              // Tablet/Desktop: Three cards side by side
                              return Row(
                                children: [
                                  Expanded(
                                    child: _ResponsiveFeatureCard(
                                      title: 'Quiz',
                                      subtitle: 'Test Knowledge',
                                      icon: Icons.quiz_outlined,
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                                      ),
                                      screenSize: screenSize,
                                      onTap: () => _navigateToQuiz(context),
                                    ),
                                  ),
                                  SizedBox(width: isTablet ? 16.0 : 12.0),
                                  Expanded(
                                    child: _ResponsiveFeatureCard(
                                      title: 'Timer',
                                      subtitle: 'Focus Session',
                                      icon: Icons.access_time_outlined,
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                                      ),
                                      screenSize: screenSize,
                                      onTap: () => _navigateToTimer(context),
                                    ),
                                  ),
                                  SizedBox(width: isTablet ? 16.0 : 12.0),
                                  Expanded(
                                    child: _ResponsiveFeatureCard(
                                      title: 'Ask AI',
                                      subtitle: 'Get Help',
                                      icon: Icons.psychology_outlined,
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                                      ),
                                      screenSize: screenSize,
                                      onTap: () => _navigateToAskAI(context),
                                    ),
                                  ),
                                ],
                              );
                            } else {
                              // Mobile: Stacked cards
                              return Column(
                                children: [
                                  _ResponsiveFeatureCard(
                                    title: 'Quiz',
                                    subtitle: 'Test Knowledge',
                                    icon: Icons.quiz_outlined,
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                                    ),
                                    screenSize: screenSize,
                                    onTap: () => _navigateToQuiz(context),
                                  ),
                                  const SizedBox(height: 16),
                                  _ResponsiveFeatureCard(
                                    title: 'Timer',
                                    subtitle: 'Focus Session',
                                    icon: Icons.access_time_outlined,
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                                    ),
                                    screenSize: screenSize,
                                    onTap: () => _navigateToTimer(context),
                                  ),
                                  const SizedBox(height: 16),
                                  _ResponsiveFeatureCard(
                                    title: 'Ask AI',
                                    subtitle: 'Get Help',
                                    icon: Icons.psychology_outlined,
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                                    ),
                                    screenSize: screenSize,
                                    onTap: () => _navigateToAskAI(context),
                                  ),
                                ],
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: isTablet ? 40.0 : 32.0),

                  // Classes Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Classes',
                            style: GoogleFonts.inter(
                              fontSize: isTablet ? 28.0 : 24.0,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: isTablet ? 6.0 : 4.0),
                          Text(
                            'Continue your learning journey',
                            style: GoogleFonts.inter(
                              fontSize: isTablet ? 16.0 : 14.0,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(FirebaseAuth.instance.currentUser?.uid)
                            .collection('Classes')
                            .snapshots(),
                        builder: (context, snapshot) {
                          final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                          return Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 16.0 : 12.0,
                              vertical: isTablet ? 8.0 : 6.0,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$count Classes',
                              style: GoogleFonts.inter(
                                fontSize: isTablet ? 14.0 : 12.0,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF3B82F6),
                              ),
                            )
                          );
                        },
                      ),
                    ],
                  ),

                  SizedBox(height: isTablet ? 24.0 : 20.0),
                ]),
              ),
            ),

            // Classes List with enhanced stats
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser?.uid)
                  .collection('Classes')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return SliverFillRemaining(
                    child: SingleChildScrollView(
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 64, color: Colors.red),
                              SizedBox(height: 16),
                              Text(
                                'Error loading classes',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red,
                                ),
                              ),
                              SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32),
                                child: Text(
                                  'Please check your connection and try again',
                                  style: GoogleFonts.inter(color: Colors.grey[600]),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return SliverFillRemaining(
                    child: _ResponsiveEmptyState(screenSize: screenSize),
                  );
                }

                return SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final doc = snapshot.data!.docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final Color cardColor = data['color'] != null
                            ? Color(data['color'])
                            : const Color(0xFF3B82F6);
                        final docId = doc.id;

                        return FutureBuilder<Map<String, dynamic>>(
                          future: _getClassStats(docId),
                          builder: (context, statsSnapshot) {
                            final stats = statsSnapshot.data ?? {'studyTime': 0, 'topicCount': 0};
                            return _ModernClassCard(
                              data: data,
                              cardColor: cardColor,
                              docId: docId,
                              index: index,
                              screenSize: screenSize,
                              studyTime: stats['studyTime'],
                              topicCount: stats['topicCount'],
                            );
                          },
                        );
                      },
                      childCount: snapshot.data!.docs.length,
                    ),
                  )
                );
              },
            ),

            // Bottom spacing
            SliverPadding(
              padding: EdgeInsets.only(bottom: isTablet ? 60.0 : 40.0),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToQuiz(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const StudyQuizScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: animation.drive(
              Tween(begin: const Offset(1.0, 0.0), end: Offset.zero),
            ),
            child: child,
          );
        },
      ),
    );
  }

  void _navigateToTimer(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => StudyTimerPage(
          // Remove the parameters since timer.dart doesn't need them
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: animation.drive(
              Tween(begin: const Offset(1.0, 0.0), end: Offset.zero),
            ),
            child: child,
          );
        },
      ),
    );
  }

  void _navigateToAskAI(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => AskAiScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: animation.drive(
              Tween(begin: const Offset(1.0, 0.0), end: Offset.zero),
            ),
            child: child,
          );
        },
      ),
    );
  }
}

// New Modern Class Card Design
class _ModernClassCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color cardColor;
  final String docId;
  final int index;
  final Size screenSize;
  final int studyTime;
  final int topicCount;

  const _ModernClassCard({
    required this.data,
    required this.cardColor,
    required this.docId,
    required this.index,
    required this.screenSize,
    required this.studyTime,
    required this.topicCount,
  });

  String _formatStudyTime(int totalSeconds) {
    if (totalSeconds == 0) return '0s';

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      // Show hour:min format when it reaches an hour
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      // Show min:sec format when it's in minutes
      return '${minutes}m ${seconds}s';
    } else {
      // Show just seconds if it hasn't reached a minute yet
      return '${seconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = screenSize.width > 600;
    final marginBottom = isTablet ? 20.0 : 16.0;

    return Container(
      margin: EdgeInsets.only(bottom: marginBottom),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                TopicScreen(
              classId: docId,
              classData: data,
              classColor: cardColor,
              classTitle: data['title'] ?? 'Class',
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: animation.drive(
                  Tween(begin: const Offset(1.0, 0.0), end: Offset.zero).chain(
                    CurveTween(curve: Curves.easeOutCubic),
                  ),
                ),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
            border: Border.all(color: Colors.grey[100]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header with gradient accent
              Container(
                padding: EdgeInsets.all(isTablet ? 24 : 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cardColor.withOpacity(0.1),
                      cardColor.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(isTablet ? 24 : 20),
                    topRight: Radius.circular(isTablet ? 24 : 20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: isTablet ? 64 : 56,
                      height: isTablet ? 64 : 56,
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: cardColor.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.school_outlined,
                        color: Colors.white,
                        size: isTablet ? 32 : 28,
                      ),
                    ),
                    SizedBox(width: isTablet ? 20 : 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['title'] ?? 'No Title',
                            style: GoogleFonts.inter(
                              fontSize: isTablet ? 22 : 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: isTablet ? 8 : 6),
                          Text(
                            data['teacher'] ?? 'No teacher assigned',
                            style: GoogleFonts.inter(
                              fontSize: isTablet ? 16 : 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey[400],
                      size: isTablet ? 24 : 20,
                    ),
                  ],
                ),
              ),

              // Stats Section
              Container(
                padding: EdgeInsets.all(isTablet ? 24 : 20),
                child: Column(
                  children: [
                    // Study Time and Topics Row
                    Row(
                      children: [
                        Expanded(
                          child: _StatItem(
                            icon: Icons.access_time_outlined,
                            label: 'Study Time',
                            value: _formatStudyTime(studyTime),
                            color: Colors.blue,
                            isTablet: isTablet,
                          ),
                        ),
                        SizedBox(width: isTablet ? 20 : 16),
                        Expanded(
                          child: _StatItem(
                            icon: Icons.topic_outlined,
                            label: 'Topics',
                            value: topicCount.toString(),
                            color: Colors.green,
                            isTablet: isTablet,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: isTablet ? 20 : 16),

                    // Class Details
                    Container(
                      padding: EdgeInsets.all(isTablet ? 20 : 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _DetailRow(
                            icon: CupertinoIcons.time,
                            text: data['time'] ?? 'No time set',
                            isTablet: isTablet,
                          ),
                          if (data['location'] != null && data['location'].toString().isNotEmpty) ...[
                            SizedBox(height: isTablet ? 12 : 8),
                            _DetailRow(
                              icon: CupertinoIcons.location,
                              text: data['location'],
                              isTablet: isTablet,
                            ),
                          ],
                        ],
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

// Stat Item Widget
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isTablet;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: isTablet ? 28 : 24,
          ),
          SizedBox(height: isTablet ? 12 : 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: isTablet ? 20 : 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          SizedBox(height: isTablet ? 4 : 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: isTablet ? 14 : 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

// Detail Row Widget
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isTablet;

  const _DetailRow({
    required this.icon,
    required this.text,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(isTablet ? 10 : 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: isTablet ? 18 : 16,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(width: isTablet ? 16 : 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: isTablet ? 16 : 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ResponsiveFeatureCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final LinearGradient gradient;
  final Size screenSize;
  final VoidCallback onTap;

  const _ResponsiveFeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.screenSize,
    required this.onTap,
  });

  @override
  State<_ResponsiveFeatureCard> createState() => _ResponsiveFeatureCardState();
}

class _ResponsiveFeatureCardState extends State<_ResponsiveFeatureCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = widget.screenSize.width > 600;
    final isLargeScreen = widget.screenSize.width > 900;
    final isSmallScreen = widget.screenSize.width < 400;

    final cardHeight = isLargeScreen ? 160.0 : isTablet ? 150.0 : isSmallScreen ? 130.0 : 140.0;
    final iconSize = isLargeScreen ? 32.0 : isTablet ? 28.0 : 24.0;
    final titleFontSize = isLargeScreen ? 20.0 : isTablet ? 18.0 : 16.0;
    final subtitleFontSize = isLargeScreen ? 15.0 : isTablet ? 14.0 : 12.0;
    final padding = isLargeScreen ? 28.0 : isTablet ? 24.0 : 20.0;
    final iconContainerSize = isLargeScreen ? 56.0 : isTablet ? 52.0 : 48.0;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            minHeight: cardHeight,
            maxHeight: cardHeight + 20,
          ),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
            boxShadow: [
              BoxShadow(
                color: widget.gradient.colors.first.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Background pattern
              Positioned(
                top: -15,
                right: -15,
                child: Container(
                  width: isLargeScreen ? 90 : isTablet ? 80 : 70,
                  height: isLargeScreen ? 90 : isTablet ? 80 : 70,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: -10,
                left: -10,
                child: Container(
                  width: isLargeScreen ? 50 : isTablet ? 45 : 40,
                  height: isLargeScreen ? 50 : isTablet ? 45 : 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // Content
              Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: iconContainerSize,
                      height: iconContainerSize,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Icon(
                          widget.icon,
                          color: Colors.white,
                          size: iconSize,
                        ),
                      ),
                    ),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: GoogleFonts.inter(
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: isTablet ? 4 : 3),
                          Text(
                            widget.subtitle,
                            style: GoogleFonts.inter(
                              fontSize: subtitleFontSize,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.8),
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ));
    }
  }


class _ResponsiveEmptyState extends StatelessWidget {
  final Size screenSize;

  const _ResponsiveEmptyState({required this.screenSize});

  @override
  Widget build(BuildContext context) {
    final isTablet = screenSize.width > 600;
    final iconSize = isTablet ? 80.0 : 64.0;
    final titleFontSize = isTablet ? 28.0 : 24.0;
    final subtitleFontSize = isTablet ? 18.0 : 16.0;

    return SingleChildScrollView(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6, // Ensure enough height for centering
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 40 : 32),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.school_outlined,
                  size: iconSize,
                  color: const Color(0xFF64748B),
                ),
              ),
              SizedBox(height: isTablet ? 32 : 24),
              Text(
                'No Classes Yet',
                style: GoogleFonts.inter(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              SizedBox(height: isTablet ? 12 : 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Your classes will appear here once you create them',
                  style: GoogleFonts.inter(
                    fontSize: subtitleFontSize,
                    color: const Color(0xFF64748B),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: isTablet ? 24 : 16),
              // Optional: Add a small hint about where to create classes
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 24 : 20,
                  vertical: isTablet ? 16 : 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue[600],
                      size: isTablet ? 20 : 18,
                    ),
                    SizedBox(width: isTablet ? 12 : 8),
                    Flexible(
                      child: Text(
                        'Create classes from the Classes tab',
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 14 : 12,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
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

Widget _buildQuickActionButton(
  BuildContext context, {
  required IconData icon,
  required String label,
  required VoidCallback onTap,
  required bool isSmallScreen,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 16,
        vertical: isSmallScreen ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: isSmallScreen ? 24 : 28,
            color: Colors.blue.shade700,
          ),
          SizedBox(height: isSmallScreen ? 4 : 8),
          Text(
            label,
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 14,
              fontWeight: FontWeight.w500,
              color: Colors.blue.shade700,
            ),
          ),
        ],
      ),
    ),
  );
}