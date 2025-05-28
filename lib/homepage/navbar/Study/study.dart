import 'package:app/homepage/navbar/Study/timer.dart';
import 'package:app/homepage/navbar/Study/quiz/quiz.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/cupertino.dart';
import 'dart:async';


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

  // Calculate total study time for a class
  Future<int> _getTotalStudyTime(String classId) async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('Classes')
              .doc(classId)
              .collection('studySessions')
              .get();

      int totalMinutes = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        totalMinutes += (data['minutes'] ?? 0) as int;
      }
      return totalMinutes;
    } catch (e) {
      print('Error calculating study time: $e');
      return 0;
    }
  }

  // Format minutes into hours and minutes
  String _formatStudyTime(int totalMinutes) {
    if (totalMinutes == 0) return '0m';

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours == 0) {
      return '${minutes}m';
    } else if (minutes == 0) {
      return '${hours}h';
    } else {
      return '${hours}h ${minutes}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final isTablet = screenWidth > 600;
    final isLargeScreen = screenWidth > 900;
    final isSmallScreen = screenWidth < 400;

    // Responsive values
    final horizontalPadding =
        isLargeScreen
            ? 40.0
            : isTablet
            ? 24.0
            : 16.0;
    final verticalPadding = isTablet ? 20.0 : 16.0;
    final titleFontSize =
        isLargeScreen
            ? 40.0
            : isTablet
            ? 36.0
            : isSmallScreen
            ? 28.0
            : 32.0;
    final cardPadding = isTablet ? 32.0 : 24.0;
    final cardRadius = isTablet ? 28.0 : 24.0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
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
                  style: GoogleFonts.dmSerifText(
                    fontSize: titleFontSize * 0.7, // Smaller for app bar
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
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
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
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
                              // Tablet/Desktop: Side by side
                              return Row(
                                children: [
                                  Expanded(
                                    child: _ResponsiveFeatureCard(
                                      title: 'Quiz',
                                      subtitle: 'Test Knowledge',
                                      icon: Icons.quiz_outlined,
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF3B82F6),
                                          Color(0xFF1D4ED8),
                                        ],
                                      ),
                                      screenSize: screenSize,
                                      onTap: () => _navigateToQuiz(context),
                                    ),
                                  ),
                                  SizedBox(width: isTablet ? 20.0 : 16.0),
                                  Expanded(
                                    child: _ResponsiveFeatureCard(
                                      title: 'Timer',
                                      subtitle: 'Focus Session',
                                      icon: Icons.access_time_outlined,
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF10B981),
                                          Color(0xFF059669),
                                        ],
                                      ),
                                      screenSize: screenSize,
                                      onTap: () => _navigateToTimer(context),
                                    ),
                                  ),
                                ],
                              );
                            } else {
                              // Mobile: Stacked
                              return Column(
                                children: [
                                  _ResponsiveFeatureCard(
                                    title: 'Quiz',
                                    subtitle: 'Test Knowledge',
                                    icon: Icons.quiz_outlined,
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF3B82F6),
                                        Color(0xFF1D4ED8),
                                      ],
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
                                      colors: [
                                        Color(0xFF10B981),
                                        Color(0xFF059669),
                                      ],
                                    ),
                                    screenSize: screenSize,
                                    onTap: () => _navigateToTimer(context),
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
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 16.0 : 12.0,
                          vertical: isTablet ? 8.0 : 6.0,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF3B82F6,
                          ).withAlpha((0.1 * 255).toInt()),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'All Subjects',
                          style: GoogleFonts.inter(
                            fontSize: isTablet ? 14.0 : 12.0,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF3B82F6),
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: isTablet ? 24.0 : 20.0),
                ]),
              ),
            ),

            // Classes List
            StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('Classes').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF3B82F6),
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
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final Color cardColor =
                          data['color'] != null
                              ? Color(data['color'])
                              : const Color(0xFF3B82F6);
                      final docId = doc.id;

                      return _ResponsiveClassCard(
                        data: data,
                        cardColor: cardColor,
                        docId: docId,
                        index: index,
                        screenSize: screenSize,
                      );
                    }, childCount: snapshot.data!.docs.length),
                  ),
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
        pageBuilder:
            (context, animation, secondaryAnimation) => const StudyQuizScreen(),
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
        pageBuilder:
            (context, animation, secondaryAnimation) => const StudyTimerPage(),
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

    // Responsive sizing - increased heights to prevent overflow
    final cardHeight =
        isLargeScreen
            ? 160.0
            : isTablet
            ? 150.0
            : isSmallScreen
            ? 130.0
            : 140.0;

    final iconSize =
        isLargeScreen
            ? 32.0
            : isTablet
            ? 28.0
            : 24.0;

    final titleFontSize =
        isLargeScreen
            ? 20.0
            : isTablet
            ? 18.0
            : 16.0;

    final subtitleFontSize =
        isLargeScreen
            ? 15.0
            : isTablet
            ? 14.0
            : 12.0;

    final padding =
        isLargeScreen
            ? 28.0
            : isTablet
            ? 24.0
            : 20.0;

    final iconContainerSize =
        isLargeScreen
            ? 56.0
            : isTablet
            ? 52.0
            : 48.0;

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
            maxHeight: cardHeight + 20, // Allow some flexibility
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
              // Background pattern - adjusted sizes
              Positioned(
                top: -15,
                right: -15,
                child: Container(
                  width:
                      isLargeScreen
                          ? 90
                          : isTablet
                          ? 80
                          : 70,
                  height:
                      isLargeScreen
                          ? 90
                          : isTablet
                          ? 80
                          : 70,
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
                  width:
                      isLargeScreen
                          ? 50
                          : isTablet
                          ? 45
                          : 40,
                  height:
                      isLargeScreen
                          ? 50
                          : isTablet
                          ? 45
                          : 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // Content with improved layout
              Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Icon container with fixed size
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
                    // Text content with flexible sizing
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
      ),
    );
  }
}

class _ResponsiveClassCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color cardColor;
  final String docId;
  final int index;
  final Size screenSize;

  const _ResponsiveClassCard({
    required this.data,
    required this.cardColor,
    required this.docId,
    required this.index,
    required this.screenSize,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = screenSize.width > 600;
    final isLight =
        ThemeData.estimateBrightnessForColor(cardColor) == Brightness.light;

    final cardPadding = isTablet ? 32.0 : 24.0;
    final titleFontSize = isTablet ? 26.0 : 22.0;
    final detailFontSize = isTablet ? 16.0 : 14.0;
    final iconSize = isTablet ? 22.0 : 18.0;
    final marginBottom = isTablet ? 24.0 : 20.0;

    return Container(
      margin: EdgeInsets.only(bottom: marginBottom),
      child: GestureDetector(
        onTap:
            () => Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder:
                    (context, animation, secondaryAnimation) =>
                        ResponsiveClassDetailScreen(
                          data: data,
                          cardColor: cardColor,
                          docId: docId,
                          screenSize: screenSize,
                        ),
                transitionsBuilder: (
                  context,
                  animation,
                  secondaryAnimation,
                  child,
                ) {
                  return SlideTransition(
                    position: animation.drive(
                      Tween(begin: const Offset(1.0, 0.0), end: Offset.zero),
                    ),
                    child: child,
                  );
                },
              ),
            ),
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(isTablet ? 28 : 24),
            boxShadow: [
              BoxShadow(
                color: cardColor.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Background pattern
              Positioned(
                top: -30,
                right: -30,
                child: Container(
                  width: isTablet ? 140 : 120,
                  height: isTablet ? 140 : 120,
                  decoration: BoxDecoration(
                    color: (isLight ? Colors.black : Colors.white).withOpacity(
                      0.05,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // Content
              Padding(
                padding: EdgeInsets.all(cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['title'] ?? 'No Title',
                                style: GoogleFonts.inter(
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.w700,
                                  color: isLight ? Colors.black : Colors.white,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: isTablet ? 12 : 8),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isTablet ? 16 : 12,
                                  vertical: isTablet ? 6 : 4,
                                ),
                                decoration: BoxDecoration(
                                  color: (isLight ? Colors.black : Colors.white)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Active',
                                  style: GoogleFonts.inter(
                                    fontSize: isTablet ? 14 : 12,
                                    fontWeight: FontWeight.w600,
                                    color: (isLight
                                            ? Colors.black
                                            : Colors.white)
                                        .withOpacity(0.7),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(isTablet ? 16 : 12),
                          decoration: BoxDecoration(
                            color: (isLight ? Colors.black : Colors.white)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.school_outlined,
                            color: (isLight ? Colors.black : Colors.white)
                                .withOpacity(0.7),
                            size: isTablet ? 28 : 24,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: isTablet ? 28 : 24),

                    // Class details
                    _ResponsiveDetailRow(
                      icon: CupertinoIcons.time,
                      text: data['time'] ?? 'No time set',
                      isLight: isLight,
                      screenSize: screenSize,
                    ),
                    SizedBox(height: isTablet ? 16 : 12),
                    _ResponsiveDetailRow(
                      icon: CupertinoIcons.person,
                      text: data['teacher'] ?? 'No teacher assigned',
                      isLight: isLight,
                      screenSize: screenSize,
                      isBold: true,
                    ),
                    SizedBox(height: isTablet ? 16 : 12),
                    _ResponsiveDetailRow(
                      icon: CupertinoIcons.location,
                      text: data['location'] ?? 'No location set',
                      isLight: isLight,
                      screenSize: screenSize,
                    ),

                    SizedBox(height: isTablet ? 24 : 20),

                    // Action arrow
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tap to explore',
                          style: GoogleFonts.inter(
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.w500,
                            color: (isLight ? Colors.black : Colors.white)
                                .withOpacity(0.6),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: (isLight ? Colors.black : Colors.white)
                              .withOpacity(0.6),
                          size: isTablet ? 18 : 16,
                        ),
                      ],
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

class _ResponsiveDetailRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isLight;
  final Size screenSize;
  final bool isBold;

  const _ResponsiveDetailRow({
    required this.icon,
    required this.text,
    required this.isLight,
    required this.screenSize,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = screenSize.width > 600;
    final iconSize = isTablet ? 20.0 : 16.0;
    final fontSize = isTablet ? 16.0 : 14.0;
    final iconPadding = isTablet ? 10.0 : 6.0;

    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(iconPadding),
          decoration: BoxDecoration(
            color: (isLight ? Colors.black : Colors.white).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: (isLight ? Colors.black : Colors.white).withOpacity(0.7),
          ),
        ),
        SizedBox(width: isTablet ? 16 : 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
              color: (isLight ? Colors.black : Colors.white).withOpacity(
                isBold ? 1.0 : 0.7,
              ),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
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
    final buttonPadding = EdgeInsets.symmetric(
      horizontal: isTablet ? 32 : 24,
      vertical: isTablet ? 16 : 12,
    );

    return Center(
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
          Text(
            'Create your first class to start studying',
            style: GoogleFonts.inter(
              fontSize: subtitleFontSize,
              color: const Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isTablet ? 40 : 32),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to create class screen
            },
            icon: Icon(Icons.add, size: isTablet ? 24 : 20),
            label: const Text('Create Class'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              padding: buttonPadding,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Responsive Class Detail Screen
class ResponsiveClassDetailScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final Color cardColor;
  final String docId;
  final Size screenSize;

  const ResponsiveClassDetailScreen({
    super.key,
    required this.data,
    required this.cardColor,
    required this.docId,
    required this.screenSize,
  });

  @override
  State<ResponsiveClassDetailScreen> createState() =>
      _ResponsiveClassDetailScreenState();
}

class _ResponsiveClassDetailScreenState
    extends State<ResponsiveClassDetailScreen>
    with TickerProviderStateMixin {
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _classStream;
  bool _editTopics = false;
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;

  @override
  void initState() {
    super.initState();
    _classStream =
        FirebaseFirestore.instance
            .collection('Classes')
            .doc(widget.docId)
            .snapshots();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Add topic dialog with responsive design
  Future<void> _showAddTopicDialog() async {
    final isTablet = widget.screenSize.width > 600;
    String topicTitle = '';

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
            ),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isTablet ? 12 : 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.add,
                    color: const Color(0xFF3B82F6),
                    size: isTablet ? 24 : 20,
                  ),
                ),
                SizedBox(width: isTablet ? 16 : 12),
                Text(
                  'Create Topic',
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 20 : 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: isTablet ? 400 : double.maxFinite,
              child: TextField(
                autofocus: true,
                style: GoogleFonts.inter(fontSize: isTablet ? 16 : 14),
                decoration: InputDecoration(
                  labelText: 'Topic Title',
                  hintText: 'Enter topic name...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF3B82F6),
                      width: 2,
                    ),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 16 : 12,
                    vertical: isTablet ? 16 : 12,
                  ),
                ),
                onChanged: (val) => topicTitle = val,
              ),
            ),
            actionsPadding: EdgeInsets.all(isTablet ? 24 : 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 24 : 20,
                    vertical: isTablet ? 12 : 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  if (topicTitle.trim().isNotEmpty) {
                    try {
                      await FirebaseFirestore.instance
                          .collection('Classes')
                          .doc(widget.docId)
                          .collection('topics')
                          .add({
                            'title': topicTitle.trim(),
                            'description': '',
                            'created': FieldValue.serverTimestamp(),
                          });
                      Navigator.pop(context);

                      // Show success message
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Topic "$topicTitle" created successfully!',
                            style: GoogleFonts.inter(),
                          ),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error creating topic: $e'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }
                  }
                },
                child: Text(
                  'Create',
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  // Edit topic dialog
  Future<void> _showEditTopicDialog(String topicId, String currentTitle) async {
    final isTablet = widget.screenSize.width > 600;
    String topicTitle = currentTitle;
    final TextEditingController controller = TextEditingController(
      text: currentTitle,
    );

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
            ),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isTablet ? 12 : 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.edit,
                    color: Colors.orange,
                    size: isTablet ? 24 : 20,
                  ),
                ),
                SizedBox(width: isTablet ? 16 : 12),
                Text(
                  'Edit Topic',
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 20 : 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: isTablet ? 400 : double.maxFinite,
              child: TextField(
                controller: controller,
                autofocus: true,
                style: GoogleFonts.inter(fontSize: isTablet ? 16 : 14),
                decoration: InputDecoration(
                  labelText: 'Topic Title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.orange,
                      width: 2,
                    ),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 16 : 12,
                    vertical: isTablet ? 16 : 12,
                  ),
                ),
                onChanged: (val) => topicTitle = val,
              ),
            ),
            actionsPadding: EdgeInsets.all(isTablet ? 24 : 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 24 : 20,
                    vertical: isTablet ? 12 : 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  if (topicTitle.trim().isNotEmpty &&
                      topicTitle.trim() != currentTitle) {
                    try {
                      await FirebaseFirestore.instance
                          .collection('Classes')
                          .doc(widget.docId)
                          .collection('topics')
                          .doc(topicId)
                          .update({
                            'title': topicTitle.trim(),
                            'updated': FieldValue.serverTimestamp(),
                          });
                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Topic updated successfully!'),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error updating topic: $e'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }
                  } else {
                    Navigator.pop(context);
                  }
                },
                child: Text(
                  'Update',
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  // Delete confirmation dialog
  Future<void> _showDeleteConfirmationDialog(
    String topicId,
    String topicTitle,
  ) async {
    final isTablet = widget.screenSize.width > 600;

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
            ),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isTablet ? 12 : 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.delete,
                    color: Colors.red,
                    size: isTablet ? 24 : 20,
                  ),
                ),
                SizedBox(width: isTablet ? 16 : 12),
                Expanded(
                  child: Text(
                    'Delete Topic',
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 20 : 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              'Are you sure you want to delete "$topicTitle"?\n\nThis will also delete all files and content associated with this topic.',
              style: GoogleFonts.inter(
                height: 1.5,
                fontSize: isTablet ? 16 : 14,
              ),
            ),
            actionsPadding: EdgeInsets.all(isTablet ? 24 : 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 24 : 20,
                    vertical: isTablet ? 12 : 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  try {
                    // Delete all files in the topic first
                    final filesSnapshot =
                        await FirebaseFirestore.instance
                            .collection('Classes')
                            .doc(widget.docId)
                            .collection('topics')
                            .doc(topicId)
                            .collection('files')
                            .get();

                    for (var fileDoc in filesSnapshot.docs) {
                      await fileDoc.reference.delete();
                    }

                    // Then delete the topic
                    await FirebaseFirestore.instance
                        .collection('Classes')
                        .doc(widget.docId)
                        .collection('topics')
                        .doc(topicId)
                        .delete();

                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Topic deleted successfully!'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error deleting topic: $e'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                },
                child: Text(
                  'Delete',
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = widget.screenSize.width > 600;
    final isLight =
        ThemeData.estimateBrightnessForColor(widget.cardColor) ==
        Brightness.light;
    final expandedHeight = isTablet ? 240.0 : 200.0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // Responsive App Bar
          SliverAppBar(
            expandedHeight: expandedHeight,
            floating: false,
            pinned: true,
            backgroundColor: widget.cardColor,
            foregroundColor: isLight ? Colors.black : Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: FadeTransition(
                opacity: _fadeInAnimation,
                child: Text(
                  widget.data['title'] ?? 'Class Details',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: isTablet ? 22.0 : 20.0,
                  ),
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.cardColor,
                      widget.cardColor.withOpacity(0.8),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Background pattern
                    Positioned(
                      top: -50,
                      right: -50,
                      child: Container(
                        width: isTablet ? 220 : 200,
                        height: isTablet ? 220 : 200,
                        decoration: BoxDecoration(
                          color: (isLight ? Colors.black : Colors.white)
                              .withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -30,
                      left: -30,
                      child: Container(
                        width: isTablet ? 120 : 100,
                        height: isTablet ? 120 : 100,
                        decoration: BoxDecoration(
                          color: (isLight ? Colors.black : Colors.white)
                              .withOpacity(0.03),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              Container(
                margin: EdgeInsets.only(right: isTablet ? 12 : 8),
                decoration: BoxDecoration(
                  color: (isLight ? Colors.black : Colors.white).withOpacity(
                    0.1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(_editTopics ? Icons.check : Icons.edit),
                  tooltip: _editTopics ? 'Done Editing' : 'Edit Topics',
                  iconSize: isTablet ? 24 : 20,
                  onPressed: () {
                    setState(() {
                      _editTopics = !_editTopics;
                    });
                  },
                ),
              ),
              Container(
                margin: EdgeInsets.only(right: isTablet ? 20 : 16),
                decoration: BoxDecoration(
                  color: (isLight ? Colors.black : Colors.white).withOpacity(
                    0.1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Create Topic',
                  iconSize: isTablet ? 24 : 20,
                  onPressed: _showAddTopicDialog,
                ),
              ),
            ],
          ),

          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _classStream,
            builder: (context, snapshot) {
              final data = snapshot.data?.data() ?? widget.data;

              return SliverPadding(
                padding: EdgeInsets.all(isTablet ? 32.0 : 24.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Class details card
                    FadeTransition(
                      opacity: _fadeInAnimation,
                      child: Container(
                        padding: EdgeInsets.all(isTablet ? 32 : 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            isTablet ? 24 : 20,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Class Details',
                              style: GoogleFonts.inter(
                                fontSize: isTablet ? 22 : 18,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            SizedBox(height: isTablet ? 24 : 20),
                            _ResponsiveDetailRow(
                              icon: CupertinoIcons.time,
                              text: data['time'] ?? 'No time set',
                              isLight: true,
                              screenSize: widget.screenSize,
                            ),
                            SizedBox(height: isTablet ? 20 : 16),
                            _ResponsiveDetailRow(
                              icon: CupertinoIcons.person,
                              text: data['teacher'] ?? 'No teacher assigned',
                              isLight: true,
                              screenSize: widget.screenSize,
                              isBold: true,
                            ),
                            SizedBox(height: isTablet ? 20 : 16),
                            _ResponsiveDetailRow(
                              icon: CupertinoIcons.location,
                              text: data['location'] ?? 'No location set',
                              isLight: true,
                              screenSize: widget.screenSize,
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: isTablet ? 40 : 32),

                    // Topics section
                    FadeTransition(
                      opacity: _fadeInAnimation,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Topics',
                                style: GoogleFonts.inter(
                                  fontSize: isTablet ? 28 : 24,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              SizedBox(height: isTablet ? 6 : 4),
                              Text(
                                'Organize your study materials',
                                style: GoogleFonts.inter(
                                  fontSize: isTablet ? 16 : 14,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          if (_editTopics)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 20 : 16,
                                vertical: isTablet ? 10 : 8,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFF59E0B),
                                    Color(0xFFD97706),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFF59E0B,
                                    ).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: isTablet ? 18 : 16,
                                  ),
                                  SizedBox(width: isTablet ? 10 : 8),
                                  Text(
                                    'Edit Mode',
                                    style: GoogleFonts.inter(
                                      fontSize: isTablet ? 14 : 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    SizedBox(height: isTablet ? 24 : 20),

                    // Topics list
                    StreamBuilder<QuerySnapshot>(
                      stream:
                          FirebaseFirestore.instance
                              .collection('Classes')
                              .doc(widget.docId)
                              .collection('topics')
                              .orderBy('created', descending: true)
                              .snapshots(),
                      builder: (context, topicSnapshot) {
                        if (!topicSnapshot.hasData ||
                            topicSnapshot.data!.docs.isEmpty) {
                          return FadeTransition(
                            opacity: _fadeInAnimation,
                            child: Container(
                              padding: EdgeInsets.all(isTablet ? 48 : 40),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(
                                  isTablet ? 24 : 20,
                                ),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(isTablet ? 24 : 20),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.topic_outlined,
                                      size: isTablet ? 56 : 48,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                  SizedBox(height: isTablet ? 20 : 16),
                                  Text(
                                    'No topics created yet',
                                    style: GoogleFonts.inter(
                                      fontSize: isTablet ? 22 : 18,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                  SizedBox(height: isTablet ? 12 : 8),
                                  Text(
                                    'Tap the + button to create your first topic',
                                    style: GoogleFonts.inter(
                                      fontSize: isTablet ? 16 : 14,
                                      color: const Color(0xFF64748B),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: List.generate(
                            topicSnapshot.data!.docs.length,
                            (index) {
                              final doc = topicSnapshot.data!.docs[index];
                              final topicData =
                                  doc.data() as Map<String, dynamic>;
                              final topicTitle = topicData['title'] ?? '';

                              return FadeTransition(
                                opacity: _fadeInAnimation,
                                child: Container(
                                  margin: EdgeInsets.only(
                                    bottom: isTablet ? 16 : 12,
                                  ),
                                  child: _ResponsiveTopicCard(
                                    topicTitle: topicTitle,
                                    topicId: doc.id,
                                    editMode: _editTopics,
                                    screenSize: widget.screenSize,
                                    onTap:
                                        _editTopics
                                            ? null
                                            : () {
                                              // Navigate to topic detail screen
                                              Navigator.push(
                                                context,
                                                PageRouteBuilder(
                                                  pageBuilder:
                                                      (
                                                        context,
                                                        animation,
                                                        secondaryAnimation,
                                                      ) => TopicDetailScreen(
                                                        classId: widget.docId,
                                                        topicId: doc.id,
                                                        topicTitle: topicTitle,
                                                      ),
                                                  transitionsBuilder: (
                                                    context,
                                                    animation,
                                                    secondaryAnimation,
                                                    child,
                                                  ) {
                                                    return SlideTransition(
                                                      position: animation.drive(
                                                        Tween(
                                                          begin: const Offset(
                                                            1.0,
                                                            0.0,
                                                          ),
                                                          end: Offset.zero,
                                                        ),
                                                      ),
                                                      child: child,
                                                    );
                                                  },
                                                ),
                                              );
                                            },
                                    onEdit:
                                        () => _showEditTopicDialog(
                                          doc.id,
                                          topicTitle,
                                        ),
                                    onDelete:
                                        () => _showDeleteConfirmationDialog(
                                          doc.id,
                                          topicTitle,
                                        ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Responsive Topic Card Widget
class _ResponsiveTopicCard extends StatefulWidget {
  final String topicTitle;
  final String topicId;
  final bool editMode;
  final Size screenSize;
  final VoidCallback? onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ResponsiveTopicCard({
    required this.topicTitle,
    required this.topicId,
    required this.editMode,
    required this.screenSize,
    this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_ResponsiveTopicCard> createState() => _ResponsiveTopicCardState();
}

class _ResponsiveTopicCardState extends State<_ResponsiveTopicCard>
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
      end: 0.98,
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

    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => _controller.forward() : null,
      onTapUp:
          widget.onTap != null
              ? (_) {
                _controller.reverse();
                widget.onTap!();
              }
              : null,
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: EdgeInsets.all(isTablet ? 24 : 20),
          decoration: BoxDecoration(
            color: widget.editMode ? const Color(0xFFFEF3C7) : Colors.white,
            borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
            border:
                widget.editMode
                    ? Border.all(color: const Color(0xFFF59E0B), width: 2)
                    : Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color:
                    widget.editMode
                        ? const Color(0xFFF59E0B).withOpacity(0.2)
                        : Colors.black.withOpacity(0.05),
                blurRadius: widget.editMode ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              if (widget.editMode)
                Container(
                  margin: EdgeInsets.only(right: isTablet ? 20 : 16),
                  padding: EdgeInsets.all(isTablet ? 12 : 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.edit,
                    size: isTablet ? 20 : 18,
                    color: const Color(0xFFF59E0B),
                  ),
                )
              else
                Container(
                  margin: EdgeInsets.only(right: isTablet ? 20 : 16),
                  padding: EdgeInsets.all(isTablet ? 12 : 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.topic_outlined,
                    size: isTablet ? 20 : 18,
                    color: const Color(0xFF3B82F6),
                  ),
                ),
              Expanded(
                child: Text(
                  widget.topicTitle,
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.w600,
                    color:
                        widget.editMode
                            ? const Color(0xFF92400E)
                            : const Color(0xFF1E293B),
                  ),
                ),
              ),
              if (widget.editMode)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.edit_outlined,
                        color: const Color(0xFF3B82F6),
                        size: isTablet ? 22 : 20,
                      ),
                      tooltip: 'Edit Topic Name',
                      onPressed: widget.onEdit,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: isTablet ? 22 : 20,
                      ),
                      tooltip: 'Delete Topic',
                      onPressed: widget.onDelete,
                    ),
                  ],
                )
              else
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: isTablet ? 18 : 16,
                  color: const Color(0xFF9CA3AF),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Add placeholder for TopicDetailScreen
class TopicDetailScreen extends StatelessWidget {
  final String classId;
  final String topicId;
  final String topicTitle;

  const TopicDetailScreen({
    super.key,
    required this.classId,
    required this.topicId,
    required this.topicTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(topicTitle),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Text(
          'Topic Detail Screen\nClass: $classId\nTopic: $topicTitle',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 16),
        ),
      ),
    );
  }
}

Future<Map<String, dynamic>?> _getLatestNoteForSubject(String subject) async {
  final normalizedSubject = subject.trim().toLowerCase();
  final snapshot =
      await FirebaseFirestore.instance
          .collection('Notes')
          .where('subject_normalized', isEqualTo: normalizedSubject)
          .orderBy('updatedAt', descending: true)
          .limit(1)
          .get();
  if (snapshot.docs.isNotEmpty) {
    return snapshot.docs.first.data();
  }
  return null;
}
