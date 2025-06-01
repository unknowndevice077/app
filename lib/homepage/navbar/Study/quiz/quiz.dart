import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/homepage/navbar/Study/quiz/quiz_taking_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudyQuizScreen extends StatefulWidget {
  const StudyQuizScreen({super.key});

  @override
  State<StudyQuizScreen> createState() => _StudyQuizScreenState();
}

class _StudyQuizScreenState extends State<StudyQuizScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _subjects = [];
  bool _loading = true;
  String? _selectedSubjectId;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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
    _loadSubjects();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ❌ CURRENT: Uses global Classes collection
  // final snapshot = await FirebaseFirestore.instance.collection('Classes').get();

  // ✅ FIX: Use per-user Classes collection
  Future<void> _loadSubjects() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('Classes')
          .get();

      setState(() {
        _subjects =
            snapshot.docs
                .map(
                  (doc) => {
                    'id': doc.id,
                    'title': doc.data()['title'] ?? 'Unknown Subject',
                    'color':
                        doc.data()['color'] ?? const Color(0xFF3B82F6).value,
                    'teacher': doc.data()['teacher'] ?? '',
                    'location': doc.data()['location'] ?? '',
                  },
                )
                .toList();
        _loading = false;
      });
      _animationController.forward();
    } catch (e) {
      setState(() {
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading subjects: $e'),
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

  void _selectSubject(String subjectId) {
    setState(() {
      _selectedSubjectId = _selectedSubjectId == subjectId ? null : subjectId;
    });
  }

  void _startQuiz() {
    if (_selectedSubjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a subject first'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final selectedSubject = _subjects.firstWhere(
      (subject) => subject['id'] == _selectedSubjectId,
    );

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) =>
                TopicSelectionScreen(subject: selectedSubject),
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

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final isLargeScreen = screenSize.width > 900;

    // Get selected subject color for bottom bar
    Color? selectedSubjectColor;
    if (_selectedSubjectId != null) {
      final selectedSubject = _subjects.firstWhere(
        (subject) => subject['id'] == _selectedSubjectId,
      );
      selectedSubjectColor = Color(selectedSubject['color']);
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            // Modern App Bar similar to Study
            SliverAppBar(
              expandedHeight: isTablet ? 160 : 140,
              floating: false,
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.of(context).pop(),
              ),
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                title: Text(
                  'Quiz',
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 28 : 24,
                    fontWeight: FontWeight.w700,
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
                  child: Stack(
                    children: [
                      Positioned(
                        top: -30,
                        right: -30,
                        child: Container(
                          width: isTablet ? 120 : 100,
                          height: isTablet ? 120 : 100,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withOpacity(0.05),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SliverPadding(
              padding: EdgeInsets.all(isTablet ? 32.0 : 24.0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Header section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Test Your Knowledge',
                            style: GoogleFonts.inter(
                              fontSize: isTablet ? 28.0 : 24.0,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: isTablet ? 6.0 : 4.0),
                          Text(
                            'Choose a subject to start your quiz',
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
                            0xFF10B981,
                          ).withAlpha((0.1 * 255).toInt()),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                     SizedBox(width: isTablet ? 8 : 6),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: isTablet ? 32.0 : 24.0),

                  // Content
                  if (_loading)
                    SizedBox(
                      height: 400,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    )
                  else if (_subjects.isEmpty)
                    _buildEmptyState(isTablet)
                  else
                    _buildSubjectGrid(isTablet, isLargeScreen),

                  // Add bottom padding for the floating action button
                  SizedBox(height: isTablet ? 120 : 100),
                ]),
              ),
            ),
          ],
        ),
      ),
      // Bottom navigation bar with Start Quiz button
      bottomNavigationBar:
          !_loading && _subjects.isNotEmpty
              ? Container(
                padding: EdgeInsets.all(isTablet ? 24 : 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Subject Selection Summary
                      if (_selectedSubjectId != null) ...[
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(isTablet ? 16 : 12),
                          margin: EdgeInsets.only(bottom: isTablet ? 16 : 12),
                          decoration: BoxDecoration(
                            color: selectedSubjectColor!.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedSubjectColor.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(isTablet ? 8 : 6),
                                decoration: BoxDecoration(
                                  color: selectedSubjectColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.quiz_outlined,
                                  color: Colors.white,
                                  size: isTablet ? 20 : 16,
                                ),
                              ),
                              SizedBox(width: isTablet ? 12 : 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Selected Subject',
                                      style: GoogleFonts.inter(
                                        fontSize: isTablet ? 14 : 12,
                                        fontWeight: FontWeight.w500,
                                        color: selectedSubjectColor,
                                      ),
                                    ),
                                    Text(
                                      _subjects.firstWhere(
                                        (subject) =>
                                            subject['id'] == _selectedSubjectId,
                                      )['title'],
                                      style: GoogleFonts.inter(
                                        fontSize: isTablet ? 16 : 14,
                                        fontWeight: FontWeight.w600,
                                        color: selectedSubjectColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.check_circle,
                                color: selectedSubjectColor,
                                size: isTablet ? 24 : 20,
                              ),
                            ],
                          ),
                        ),
                      ],
                      // Start Quiz Button
                      SizedBox(
                        width: double.infinity,
                        height: isTablet ? 56 : 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _selectedSubjectId != null
                                    ? selectedSubjectColor
                                    : Colors.grey,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                isTablet ? 28 : 25,
                              ),
                            ),
                            elevation: _selectedSubjectId != null ? 5 : 0,
                            shadowColor: selectedSubjectColor?.withOpacity(0.3),
                          ),
                          onPressed:
                              _selectedSubjectId != null ? _startQuiz : null,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.play_arrow_rounded,
                                size: isTablet ? 24 : 20,
                              ),
                              SizedBox(width: isTablet ? 12 : 8),
                              Text(
                                _selectedSubjectId == null
                                    ? 'Select a Subject to Continue'
                                    : 'Start Quiz',
                                style: GoogleFonts.inter(
                                  fontSize: isTablet ? 18 : 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              : null,
    );
  }

  Widget _buildEmptyState(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 48 : 40),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
              Icons.quiz_outlined,
              size: isTablet ? 56 : 48,
              color: const Color(0xFF64748B),
            ),
          ),
          SizedBox(height: isTablet ? 20 : 16),
          Text(
            'No Subjects Available',
            style: GoogleFonts.inter(
              fontSize: isTablet ? 22 : 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: isTablet ? 12 : 8),
          Text(
            'Create some classes first to take quizzes',
            style: GoogleFonts.inter(
              fontSize: isTablet ? 16 : 14,
              color: const Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectGrid(bool isTablet, bool isLargeScreen) {
    final crossAxisCount =
        isLargeScreen
            ? 3
            : isTablet
            ? 2
            : 1;
    final childAspectRatio = isTablet ? 1.1 : 1.3;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: isTablet ? 20 : 16,
        mainAxisSpacing: isTablet ? 20 : 16,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: _subjects.length,
      itemBuilder: (context, index) {
        final subject = _subjects[index];
        return _ResponsiveSubjectCard(
          subject: subject,
          isSelected: _selectedSubjectId == subject['id'],
          screenSize: MediaQuery.of(context).size,
          onTap: () => _selectSubject(subject['id']),
        );
      },
    );
  }
}

class _ResponsiveSubjectCard extends StatefulWidget {
  final Map<String, dynamic> subject;
  final bool isSelected;
  final Size screenSize;
  final VoidCallback onTap;

  const _ResponsiveSubjectCard({
    required this.subject,
    required this.isSelected,
    required this.screenSize,
    required this.onTap,
  });

  @override
  State<_ResponsiveSubjectCard> createState() => _ResponsiveSubjectCardState();
}

class _ResponsiveSubjectCardState extends State<_ResponsiveSubjectCard>
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

  // Helper function to determine if a color is light
  bool _isLightColor(Color color) {
    final brightness = ThemeData.estimateBrightnessForColor(color);
    return brightness == Brightness.light;
  }

  // Helper function to get contrasting border color for light colors
  Color _getContrastingBorderColor(Color subjectColor, bool isSelected) {
    final isLight = _isLightColor(subjectColor);
    
    if (!isSelected) {
      return const Color(0xFFE2E8F0); // Default gray border
    }
    
    if (isLight) {
      // For light colors, use a darker version or fallback to dark blue
      return subjectColor == Colors.white || subjectColor.value == 0xFFFFFFFF
          ? const Color(0xFF3B82F6) // Blue for pure white
          : HSLColor.fromColor(subjectColor).withLightness(0.3).toColor(); // Darker version
    } else {
      return subjectColor; // Use original color for dark colors
    }
  }

  // Helper function to get selection indicator color
  Color _getSelectionIndicatorColor(Color subjectColor) {
    final isLight = _isLightColor(subjectColor);
    
    if (isLight) {
      return subjectColor == Colors.white || subjectColor.value == 0xFFFFFFFF
          ? const Color(0xFF3B82F6) // Blue for pure white
          : HSLColor.fromColor(subjectColor).withLightness(0.4).toColor(); // Darker version
    } else {
      return subjectColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = widget.screenSize.width > 600;
    final subjectColor = Color(widget.subject['color']);
    final isLightSubjectColor = _isLightColor(subjectColor);
    
    // Get contrasting colors for light subjects
    final borderColor = _getContrastingBorderColor(subjectColor, widget.isSelected);
    final indicatorColor = _getSelectionIndicatorColor(subjectColor);

    // Determine text colors based on selection and subject color lightness
    Color titleColor;
    Color teacherColor;

    if (widget.isSelected) {
      if (isLightSubjectColor) {
        // Light subject color + selected = use black text for high contrast
        titleColor = Colors.black87;
        teacherColor = Colors.black54;
      } else {
        // Dark subject color + selected = use subject color
        titleColor = subjectColor;
        teacherColor = subjectColor.withOpacity(0.8);
      }
    } else {
      // When not selected, use default colors
      titleColor = const Color(0xFF1E293B);
      teacherColor = const Color(0xFF64748B);
    }

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
          decoration: BoxDecoration(
            color: widget.isSelected
                ? (isLightSubjectColor ? Colors.white : subjectColor.withOpacity(0.05))
                : Colors.white,
            borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
            border: Border.all(
              color: borderColor, // Use contrasting border color
              width: widget.isSelected ? 3 : 1, // Thicker border when selected
            ),
            boxShadow: [
              BoxShadow(
                color: widget.isSelected
                    ? borderColor.withOpacity(0.3) // Use border color for shadow
                    : Colors.black.withOpacity(0.05),
                blurRadius: widget.isSelected ? 15 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 24 : 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon with selection indicator
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: isTablet ? 64 : 56,
                      height: isTablet ? 64 : 56,
                      decoration: BoxDecoration(
                        color: indicatorColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: indicatorColor,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.quiz_outlined,
                        color: indicatorColor,
                        size: isTablet ? 28 : 24,
                      ),
                    ),
                    if (widget.isSelected)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: isTablet ? 28 : 24,
                          height: isTablet ? 28 : 24,
                          decoration: BoxDecoration(
                            color: indicatorColor, // Use indicator color
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: indicatorColor.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.check,
                            color: Colors.white,
                            size: isTablet ? 16 : 14,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: isTablet ? 16 : 12),
                Text(
                  widget.subject['title'],
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.subject['teacher'].isNotEmpty) ...[
                  SizedBox(height: isTablet ? 8 : 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: isTablet ? 16 : 14,
                        color: teacherColor,
                      ),
                      SizedBox(width: isTablet ? 6 : 4),
                      Flexible(
                        child: Text(
                          widget.subject['teacher'],
                          style: GoogleFonts.inter(
                            fontSize: isTablet ? 14 : 12,
                            color: teacherColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                
                // ✅ ADD: Selection indicator at bottom for extra visibility
                if (widget.isSelected) ...[
                  SizedBox(height: isTablet ? 12 : 8),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 16 : 12,
                      vertical: isTablet ? 6 : 4,
                    ),
                    decoration: BoxDecoration(
                      color: indicatorColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: indicatorColor.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: isTablet ? 16 : 14,
                        ),
                        SizedBox(width: isTablet ? 6 : 4),
                        Text(
                          'Selected',
                          style: GoogleFonts.inter(
                            fontSize: isTablet ? 12 : 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ));
  }
}

// Enhanced Topic Selection Screen
class TopicSelectionScreen extends StatefulWidget {
  final Map<String, dynamic> subject;

  const TopicSelectionScreen({super.key, required this.subject});

  @override
  State<TopicSelectionScreen> createState() => _TopicSelectionScreenState();
}

class _TopicSelectionScreenState extends State<TopicSelectionScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _topics = [];
  final Set<String> _selectedTopics = {};
  bool _loading = true;
  int _questionCount = 10;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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
    _loadTopics();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadTopics() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('Classes')
          .doc(widget.subject['id'])
          .collection('topics')
          .get();

      setState(() {
        _topics = snapshot.docs
            .map(
              (doc) => {
                'id': doc.id,
                'title': doc.data()['title'] ?? 'Unknown Topic',
                'description': doc.data()['description'] ?? '',
              },
            )
            .toList();
        _loading = false;
      });
      _animationController.forward();
    } catch (e) {
      setState(() {
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading topics: $e'),
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

  void _toggleTopic(String topicId) {
    setState(() {
      if (_selectedTopics.contains(topicId)) {
        _selectedTopics.remove(topicId);
      } else {
        _selectedTopics.add(topicId);
      }
    });
  }

  void _startQuizWithTopics() {
    if (_selectedTopics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select at least one topic'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final selectedTopics =
        _topics
            .where((topic) => _selectedTopics.contains(topic['id']))
            .toList();

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) => QuizTakingScreen(
              topics: selectedTopics,
              questionCount: _questionCount,
              subject: widget.subject, // Add this line
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

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final subjectColor = Color(widget.subject['color']);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: isTablet ? 160 : 140,
              floating: false,
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.of(context).pop(),
              ),
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Select Topics',
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 24 : 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      widget.subject['title'],
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.w500,
                        color: subjectColor,
                      ),
                    ),
                  ],
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

            if (_loading)
              SliverFillRemaining(
                child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
                ),
              )
            else if (_topics.isEmpty)
              SliverFillRemaining(child: _buildEmptyState(isTablet))
            else
              SliverPadding(
                padding: EdgeInsets.all(isTablet ? 32.0 : 24.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Choose Topics',
                              style: GoogleFonts.inter(
                                fontSize: isTablet ? 28.0 : 24.0,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: isTablet ? 6.0 : 4.0),
                            Text(
                              '${_selectedTopics.length} topic(s) selected',
                              style: GoogleFonts.inter(
                                fontSize: isTablet ? 16.0 : 14.0,
                                color: subjectColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    SizedBox(height: isTablet ? 32.0 : 24.0),

                    // Question Count Section
                    Container(
                      padding: EdgeInsets.all(isTablet ? 24 : 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(isTablet ? 12 : 10),
                                decoration: BoxDecoration(
                                  color: subjectColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.quiz_outlined,
                                  color: subjectColor,
                                  size: isTablet ? 24 : 20,
                                ),
                              ),
                              SizedBox(width: isTablet ? 16 : 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Question Count',
                                      style: GoogleFonts.inter(
                                        fontSize: isTablet ? 18 : 16,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF1E293B),
                                      ),
                                    ),
                                    SizedBox(height: isTablet ? 4 : 2),
                                    Text(
                                      'How many questions would you like?',
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
                          SizedBox(height: isTablet ? 20 : 16),
                          Wrap(
                            spacing: isTablet ? 12 : 8,
                            runSpacing: isTablet ? 12 : 8,
                            children:
                                [5, 10, 15, 20, 25, 30].map((count) {
                                  final isSelected = _questionCount == count;
                                  return GestureDetector(
                                    onTap:
                                        () => setState(
                                          () => _questionCount = count,
                                        ),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isTablet ? 20 : 16,
                                        vertical: isTablet ? 12 : 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            isSelected
                                                ? subjectColor
                                                : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color:
                                              isSelected
                                                  ? subjectColor
                                                  : Colors.grey[300]!,
                                          width: isSelected ? 2 : 1,
                                        ),
                                        boxShadow:
                                            isSelected
                                                ? [
                                                  BoxShadow(
                                                    color: subjectColor
                                                        .withOpacity(0.3),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ]
                                                : [],
                                      ),
                                      child: Text(
                                        '$count',
                                        style: GoogleFonts.inter(
                                          fontSize: isTablet ? 16 : 14,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              isSelected
                                                  ? Colors.white
                                                  : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                          SizedBox(height: isTablet ? 16 : 12),
                          Container(
                            padding: EdgeInsets.all(isTablet ? 16 : 12),
                            decoration: BoxDecoration(
                              color: subjectColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: subjectColor.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  color: subjectColor,
                                  size: isTablet ? 20 : 18,
                                ),
                                SizedBox(width: isTablet ? 12 : 8),
                                Expanded(
                                  child: Text(
                                    'Selected: $_questionCount questions',
                                    style: GoogleFonts.inter(
                                      fontSize: isTablet ? 14 : 12,
                                      fontWeight: FontWeight.w500,
                                      color: subjectColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: isTablet ? 32 : 24),

                    // Topics Section Header
                    Text(
                      'Available Topics',
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 22 : 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(height: isTablet ? 4 : 2),
                    Text(
                      'Select the topics you want to be quizzed on',
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 14 : 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),

                    SizedBox(height: isTablet ? 20 : 16),

                    // Topics list
                    ...List.generate(_topics.length, (index) {
                      final topic = _topics[index];
                      final isSelected = _selectedTopics.contains(topic['id']);

                      return Container(
                        margin: EdgeInsets.only(bottom: isTablet ? 16 : 12),
                        child: _ResponsiveTopicCard(
                          topic: topic,
                          isSelected: isSelected,
                          subjectColor: subjectColor,
                          screenSize: screenSize,
                          onTap: () => _toggleTopic(topic['id']),
                        ),
                      );
                    }),

                    SizedBox(height: isTablet ? 32 : 24),
                  ]),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar:
          !_loading && _topics.isNotEmpty
              ? Container(
                padding: EdgeInsets.all(isTablet ? 24 : 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Quiz Summary
                      if (_selectedTopics.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(isTablet ? 16 : 12),
                          margin: EdgeInsets.only(bottom: isTablet ? 16 : 12),
                          decoration: BoxDecoration(
                            color: subjectColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: subjectColor.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Quiz Summary',
                                    style: GoogleFonts.inter(
                                      fontSize: isTablet ? 16 : 14,
                                      fontWeight: FontWeight.w600,
                                      color: subjectColor,
                                    ),
                                  ),
                                  SizedBox(height: isTablet ? 4 : 2),
                                  Text(
                                    '${_selectedTopics.length} topics • $_questionCount questions',
                                    style: GoogleFonts.inter(
                                      fontSize: isTablet ? 14 : 12,
                                      color: subjectColor,
                                    ),
                                  ),
                                ],
                              ),
                              Icon(
                                Icons.check_circle_outline,
                                color: subjectColor,
                                size: isTablet ? 24 : 20,
                              ),
                            ],
                          ),
                        ),
                      // Start Quiz Button
                      SizedBox(
                        width: double.infinity,
                        height: isTablet ? 56 : 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _selectedTopics.isNotEmpty
                                    ? subjectColor
                                    : Colors.grey,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                isTablet ? 28 : 25,
                              ),
                            ),
                            elevation: _selectedTopics.isNotEmpty ? 5 : 0,
                          ),
                          onPressed:
                              _selectedTopics.isNotEmpty
                                  ? _startQuizWithTopics
                                  : null,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow, size: isTablet ? 24 : 20),
                              SizedBox(width: isTablet ? 12 : 8),
                              Text(
                                _selectedTopics.isEmpty
                                    ? 'Select Topics to Continue'
                                    : 'Start Quiz ($_questionCount questions)',
                                style: GoogleFonts.inter(
                                  fontSize: isTablet ? 18 : 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              : null,
    );
  }

  Widget _buildEmptyState(bool isTablet) {
    return Container(
      margin: EdgeInsets.all(isTablet ? 32 : 24),
      padding: EdgeInsets.all(isTablet ? 48 : 40),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
            'No Topics Available',
            style: GoogleFonts.inter(
              fontSize: isTablet ? 22 : 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: isTablet ? 12 : 8),
          Text(
            'Add some topics to this subject first',
            style: GoogleFonts.inter(
              fontSize: isTablet ? 16 : 14,
              color: const Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ResponsiveTopicCard extends StatefulWidget {
  final Map<String, dynamic> topic;
  final bool isSelected;
  final Color subjectColor;
  final Size screenSize;
  final VoidCallback onTap;

  const _ResponsiveTopicCard({
    required this.topic,
    required this.isSelected,
    required this.subjectColor,
    required this.screenSize,
    required this.onTap,
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

  // Helper functions (same as above)
  bool _isLightColor(Color color) {
    final brightness = ThemeData.estimateBrightnessForColor(color);
    return brightness == Brightness.light;
  }

  Color _getContrastingColor(Color subjectColor) {
    final isLight = _isLightColor(subjectColor);
    
    if (isLight) {
      return subjectColor == Colors.white || subjectColor.value == 0xFFFFFFFF
          ? const Color(0xFF3B82F6)
          : HSLColor.fromColor(subjectColor).withLightness(0.4).toColor();
    } else {
      return subjectColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = widget.screenSize.width > 600;
    final isLightSubjectColor = _isLightColor(widget.subjectColor);
    final contrastingColor = _getContrastingColor(widget.subjectColor);

    // Determine text colors
    Color titleColor;
    if (widget.isSelected) {
      if (isLightSubjectColor) {
        titleColor = Colors.black87;
      } else {
        titleColor = widget.subjectColor;
      }
    } else {
      titleColor = const Color(0xFF1E293B);
    }

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
          padding: EdgeInsets.all(isTablet ? 24 : 20),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? (isLightSubjectColor ? Colors.white : widget.subjectColor.withOpacity(0.05))
                : Colors.white,
            borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
            border: Border.all(
              color: widget.isSelected ? contrastingColor : const Color(0xFFE2E8F0),
              width: widget.isSelected ? 3 : 1, // Thicker border when selected
            ),
            boxShadow: [
              BoxShadow(
                color: widget.isSelected
                    ? contrastingColor.withOpacity(0.3)
                    : Colors.black.withOpacity(0.05),
                blurRadius: widget.isSelected ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isTablet ? 32 : 28,
                height: isTablet ? 32 : 28,
                decoration: BoxDecoration(
                  color: widget.isSelected ? contrastingColor : Colors.transparent,
                  border: Border.all(
                    color: widget.isSelected ? contrastingColor : Colors.grey,
                    width: 3, // Thicker border for visibility
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: widget.isSelected ? [
                    BoxShadow(
                      color: contrastingColor.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ] : [],
                ),
                child: widget.isSelected
                    ? Icon(
                        Icons.check,
                        color: Colors.white,
                        size: isTablet ? 20 : 18,
                      )
                    : null,
              ),
              SizedBox(width: isTablet ? 20 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.topic['title'],
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 18 : 16,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    if (widget.topic['description'].isNotEmpty) ...[
                      SizedBox(height: isTablet ? 6 : 4),
                      Text(
                        widget.topic['description'],
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 14 : 12,
                          color: const Color(0xFF64748B),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ));
  }
}
