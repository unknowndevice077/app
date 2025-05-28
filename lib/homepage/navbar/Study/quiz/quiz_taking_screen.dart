import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'dart:convert';

class QuizTakingScreen extends StatefulWidget {
  final List<Map<String, dynamic>> topics;
  final int questionCount;
  final Map<String, dynamic> subject; // Add subject data to get color

  const QuizTakingScreen({
    super.key,
    required this.topics,
    required this.questionCount,
    required this.subject, // Add this parameter
  });

  @override
  State<QuizTakingScreen> createState() => _QuizTakingScreenState();
}

class _QuizTakingScreenState extends State<QuizTakingScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _questions = [];
  int _currentQuestionIndex = 0;
  int _score = 0;
  bool _loading = true;
  bool _answered = false;
  String? _selectedAnswer;
  bool _generatingQuestions = false;
  late AnimationController _animationController;
  late AnimationController _progressController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;

  // Get subject color
  Color get subjectColor => Color(widget.subject['color']);
  Color get subjectColorLight => subjectColor.withOpacity(0.1);
  Color get subjectColorMedium => subjectColor.withOpacity(0.3);

  @override
  void initState() {
    super.initState();
    
    // Main animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    // Progress animation controller
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    // Pulse animation controller
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack));
    
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _loadQuestions();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ... (keep existing AI generation methods the same) ...
  Future<List<Map<String, dynamic>>> _generateQuestionsWithAI(
    String topicTitle,
    int questionsPerTopic,
  ) async {
    try {
      final model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.0-flash',
      );

      final prompt = [
        Content.text('''
Generate exactly $questionsPerTopic multiple choice quiz questions about the topic: "$topicTitle".

Requirements:
- Each question should be educational and test understanding of the topic
- Provide exactly 4 answer options (A, B, C, D) for each question
- Mark one answer as correct
- Questions should be at an appropriate academic level
- Avoid overly easy or overly complex questions
- Make distractors (wrong answers) plausible but clearly incorrect

Format the response as a JSON array with this exact structure:
[
  {
    "question": "Your question text here?",
    "answers": ["Option A", "Option B", "Option C", "Option D"],
    "correctAnswer": "Option B"
  }
]

Topic: $topicTitle
Number of questions needed: $questionsPerTopic

Please ensure the JSON is valid and contains exactly $questionsPerTopic questions.
'''),
      ];

      final response = await model.generateContent(prompt);

      if (response.text != null) {
        String jsonText = response.text!;
        jsonText = jsonText.replaceAll('```json', '').replaceAll('```', '').trim();
        final startIndex = jsonText.indexOf('[');
        final endIndex = jsonText.lastIndexOf(']') + 1;

        if (startIndex != -1 && endIndex != -1) {
          jsonText = jsonText.substring(startIndex, endIndex);
        }

        final List<dynamic> questionsJson = json.decode(jsonText);

        return questionsJson
            .map(
              (q) => {
                'question': q['question']?.toString() ?? '',
                'answers': List<String>.from(q['answers'] ?? []),
                'correctAnswer': q['correctAnswer']?.toString() ?? '',
                'topic': topicTitle,
                'generated': true,
              },
            )
            .toList();
      }
    } catch (e) {
      print('Error generating questions with AI: $e');
      return _generateFallbackQuestions(topicTitle, questionsPerTopic);
    }

    return [];
  }

  List<Map<String, dynamic>> _generateFallbackQuestions(
    String topicTitle,
    int count,
  ) {
    return List.generate(
      count,
      (index) => {
        'question': 'Sample question ${index + 1} about $topicTitle?',
        'answers': [
          'Option A for $topicTitle',
          'Option B for $topicTitle',
          'Option C for $topicTitle',
          'Option D for $topicTitle',
        ],
        'correctAnswer': 'Option A for $topicTitle',
        'topic': topicTitle,
        'generated': true,
      },
    );
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _loading = true;
      _generatingQuestions = false;
    });

    try {
      List<Map<String, dynamic>> allQuestions = [];

      for (var topic in widget.topics) {
        final snapshot = await FirebaseFirestore.instance
            .collection('questions')
            .where('topicId', isEqualTo: topic['id'])
            .get();

        for (var doc in snapshot.docs) {
          final data = doc.data();
          allQuestions.add({
            'id': doc.id,
            'question': data['question'] ?? '',
            'answers': List<String>.from(data['answers'] ?? []),
            'correctAnswer': data['correctAnswer'] ?? '',
            'topic': topic['title'],
            'generated': false,
          });
        }
      }

      if (allQuestions.length < widget.questionCount) {
        setState(() {
          _generatingQuestions = true;
        });

        final questionsNeeded = widget.questionCount - allQuestions.length;
        final questionsPerTopic = (questionsNeeded / widget.topics.length).ceil();

        for (var topic in widget.topics) {
          final existingQuestionsForTopic =
              allQuestions.where((q) => q['topic'] == topic['title']).length;

          if (existingQuestionsForTopic < questionsPerTopic) {
            final additionalNeeded = questionsPerTopic - existingQuestionsForTopic;

            final aiQuestions = await _generateQuestionsWithAI(
              topic['title'],
              additionalNeeded,
            );

            allQuestions.addAll(aiQuestions);

            for (var question in aiQuestions) {
              try {
                await FirebaseFirestore.instance.collection('questions').add({
                  'topicId': topic['id'],
                  'question': question['question'],
                  'answers': question['answers'],
                  'correctAnswer': question['correctAnswer'],
                  'generated': true,
                  'createdAt': FieldValue.serverTimestamp(),
                });
              } catch (e) {
                print('Error saving generated question: $e');
              }
            }
          }
        }
      }

      allQuestions.shuffle();
      _questions = allQuestions.take(widget.questionCount).toList();

      setState(() {
        _loading = false;
        _generatingQuestions = false;
      });
      
      _animationController.forward();
      _progressController.forward();
    } catch (e) {
      setState(() {
        _loading = false;
        _generatingQuestions = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading questions: $e'),
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

  void _selectAnswer(String answer) {
    if (!_answered) {
      setState(() {
        _selectedAnswer = answer;
        _answered = true;
        if (answer == _questions[_currentQuestionIndex]['correctAnswer']) {
          _score++;
        }
      });
    }
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _answered = false;
        _selectedAnswer = null;
      });
      _animationController.reset();
      _animationController.forward();
      
      final progress = (_currentQuestionIndex + 1) / _questions.length;
      _progressController.animateTo(progress);
    } else {
      _showResults();
    }
  }

  void _showResults() {
    final percentage = (_score / _questions.length * 100).round();
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isTablet ? 32 : 24),
        ),
        elevation: 20,
        child: Container(
          padding: EdgeInsets.all(isTablet ? 40 : 32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                percentage >= 70 ? subjectColorLight : Colors.orange.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(isTablet ? 32 : 24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated trophy/medal icon
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 1000),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      padding: EdgeInsets.all(isTablet ? 24 : 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: percentage >= 70 
                              ? [subjectColor, subjectColor.withOpacity(0.7)]
                              : [Colors.orange, Colors.orange.shade400],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (percentage >= 70 ? subjectColor : Colors.orange).withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        percentage >= 70 ? Icons.emoji_events : Icons.insights,
                        color: Colors.white,
                        size: isTablet ? 40 : 32,
                      ),
                    ),
                  );
                },
              ),
              
              SizedBox(height: isTablet ? 24 : 20),
              
              // Title with gradient text
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: percentage >= 70 
                      ? [subjectColor, subjectColor.withOpacity(0.7)]
                      : [Colors.orange, Colors.orange.shade700],
                ).createShader(bounds),
                child: Text(
                  'Quiz Complete!',
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 32 : 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              SizedBox(height: isTablet ? 32 : 24),
              
              // Score display with circular progress
              SizedBox(
                width: isTablet ? 180 : 150,
                height: isTablet ? 180 : 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Circular progress indicator
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 1500),
                      tween: Tween(begin: 0.0, end: percentage / 100),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return SizedBox(
                          width: isTablet ? 180 : 150,
                          height: isTablet ? 180 : 150,
                          child: CircularProgressIndicator(
                            value: value,
                            strokeWidth: isTablet ? 12 : 10,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              percentage >= 70 ? subjectColor : Colors.orange,
                            ),
                          ),
                        );
                      },
                    ),
                    // Score text
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TweenAnimationBuilder<int>(
                          duration: const Duration(milliseconds: 1500),
                          tween: IntTween(begin: 0, end: _score),
                          builder: (context, value, child) {
                            return Text(
                              '$value/${_questions.length}',
                              style: GoogleFonts.inter(
                                fontSize: isTablet ? 28 : 24,
                                fontWeight: FontWeight.w700,
                                color: percentage >= 70 ? subjectColor : Colors.orange,
                              ),
                            );
                          },
                        ),
                        Text(
                          '$percentage%',
                          style: GoogleFonts.inter(
                            fontSize: isTablet ? 18 : 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: isTablet ? 32 : 24),
              
              // Performance message
              Container(
                padding: EdgeInsets.all(isTablet ? 20 : 16),
                decoration: BoxDecoration(
                  color: (percentage >= 70 ? subjectColor : Colors.orange).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (percentage >= 70 ? subjectColor : Colors.orange).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      percentage >= 70 ? Icons.celebration : Icons.lightbulb_outline,
                      color: percentage >= 70 ? subjectColor : Colors.orange,
                      size: isTablet ? 24 : 20,
                    ),
                    SizedBox(width: isTablet ? 12 : 8),
                    Expanded(
                      child: Text(
                        percentage >= 70
                            ? 'Excellent work! You have mastered this material.'
                            : 'Good effort! Review the topics and try again to improve.',
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.w500,
                          color: percentage >= 70 ? subjectColor : Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: isTablet ? 32 : 24),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Try Again',
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isTablet ? 16 : 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: subjectColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 8,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Finish Quiz',
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    if (_loading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [subjectColor, subjectColor.withOpacity(0.8)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Custom app bar
                Padding(
                  padding: EdgeInsets.all(isTablet ? 24 : 16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          _generatingQuestions ? 'Generating Questions...' : 'Preparing Quiz...',
                          style: GoogleFonts.inter(
                            fontSize: isTablet ? 20 : 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(width: isTablet ? 48 : 40),
                    ],
                  ),
                ),
                
                Expanded(
                  child: Center(
                    child: ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        margin: EdgeInsets.all(isTablet ? 40 : 32),
                        padding: EdgeInsets.all(isTablet ? 48 : 40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(isTablet ? 32 : 24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_generatingQuestions) ...[
                              // AI generation animation
                              Container(
                                padding: EdgeInsets.all(isTablet ? 24 : 20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [subjectColor, subjectColor.withOpacity(0.7)],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.auto_awesome,
                                  color: Colors.white,
                                  size: isTablet ? 56 : 48,
                                ),
                              ),
                              SizedBox(height: isTablet ? 32 : 24),
                              ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: [subjectColor, subjectColor.withOpacity(0.7)],
                                ).createShader(bounds),
                                child: Text(
                                  'AI Crafting Your Quiz',
                                  style: GoogleFonts.inter(
                                    fontSize: isTablet ? 24 : 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              SizedBox(height: isTablet ? 16 : 12),
                              Text(
                                'Creating ${widget.questionCount} personalized questions\nfor your selected topics',
                                style: GoogleFonts.inter(
                                  fontSize: isTablet ? 16 : 14,
                                  color: Colors.grey[600],
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: isTablet ? 32 : 24),
                              // Animated progress bar
                              Container(
                                width: isTablet ? 250 : 200,
                                height: isTablet ? 8 : 6,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: TweenAnimationBuilder<double>(
                                  duration: const Duration(seconds: 3),
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  builder: (context, value, child) {
                                    return FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: value,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [subjectColor, subjectColor.withOpacity(0.7)],
                                          ),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ] else ...[
                              // Regular loading
                              Container(
                                padding: EdgeInsets.all(isTablet ? 24 : 20),
                                decoration: BoxDecoration(
                                  color: subjectColorLight,
                                  shape: BoxShape.circle,
                                ),
                                child: CircularProgressIndicator(
                                  color: subjectColor,
                                  strokeWidth: isTablet ? 4 : 3,
                                ),
                              ),
                              SizedBox(height: isTablet ? 32 : 24),
                              Text(
                                'Loading Questions...',
                                style: GoogleFonts.inter(
                                  fontSize: isTablet ? 20 : 18,
                                  fontWeight: FontWeight.w600,
                                  color: subjectColor,
                                ),
                              ),
                              SizedBox(height: isTablet ? 12 : 8),
                              Text(
                                'Gathering existing questions from your topics',
                                style: GoogleFonts.inter(
                                  fontSize: isTablet ? 16 : 14,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.red.shade400, Colors.red.shade600],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Container(
                margin: EdgeInsets.all(isTablet ? 40 : 32),
                padding: EdgeInsets.all(isTablet ? 48 : 40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(isTablet ? 32 : 24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(isTablet ? 24 : 20),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.quiz_outlined,
                        size: isTablet ? 64 : 56,
                        color: Colors.red,
                      ),
                    ),
                    SizedBox(height: isTablet ? 32 : 24),
                    Text(
                      'Unable to Generate Questions',
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 24 : 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.red,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: isTablet ? 16 : 12),
                    Text(
                      'We couldn\'t generate questions for the selected topics. Please check your internet connection and try again.',
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 16 : 14,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: isTablet ? 32 : 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 8,
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Go Back',
                          style: GoogleFonts.inter(
                            fontSize: isTablet ? 16 : 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / _questions.length;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [subjectColor, subjectColor.withOpacity(0.8)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Enhanced app bar with progress
              Container(
                padding: EdgeInsets.all(isTablet ? 24 : 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                                style: GoogleFonts.inter(
                                  fontSize: isTablet ? 18 : 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              if (currentQuestion['generated'] == true) ...[
                                SizedBox(height: isTablet ? 6 : 4),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isTablet ? 12 : 8,
                                    vertical: isTablet ? 4 : 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.auto_awesome,
                                        size: isTablet ? 14 : 12,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: isTablet ? 6 : 4),
                                      Text(
                                        'AI Generated',
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
                        // Score display
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 16 : 12,
                            vertical: isTablet ? 8 : 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$_score/${_currentQuestionIndex + (_answered ? 1 : 0)}',
                            style: GoogleFonts.inter(
                              fontSize: isTablet ? 16 : 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isTablet ? 20 : 16),
                    // Animated progress bar
                    AnimatedBuilder(
                      animation: _progressAnimation,
                      builder: (context, child) {
                        return Container(
                          height: isTablet ? 8 : 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progress,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.5),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              
              // Main content
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        margin: EdgeInsets.all(isTablet ? 24 : 16),
                        child: Column(
                          children: [
                            // Topic badge
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 20 : 16,
                                vertical: isTablet ? 10 : 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                'Topic: ${currentQuestion['topic']}',
                                style: GoogleFonts.inter(
                                  fontSize: isTablet ? 16 : 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            
                            SizedBox(height: isTablet ? 24 : 20),
                            
                            // Question card
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(isTablet ? 32 : 24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(isTablet ? 32 : 24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 30,
                                      offset: const Offset(0, 15),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // Question text
                                    Container(
                                      padding: EdgeInsets.all(isTablet ? 24 : 20),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [subjectColorLight, subjectColorLight],
                                        ),
                                        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
                                      ),
                                      child: Text(
                                        currentQuestion['question'],
                                        style: GoogleFonts.inter(
                                          fontSize: isTablet ? 26 : 22,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black87,
                                          height: 1.4,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    
                                    SizedBox(height: isTablet ? 32 : 24),
                                    
                                    // Answer options
                                    Expanded(
                                      child: ListView.builder(
                                        itemCount: currentQuestion['answers'].length,
                                        itemBuilder: (context, index) {
                                          final answer = currentQuestion['answers'][index];
                                          final isSelected = _selectedAnswer == answer;
                                          final isCorrect = answer == currentQuestion['correctAnswer'];
                                          
                                          Color cardColor = Colors.white;
                                          Color borderColor = Colors.grey[200]!;
                                          Color textColor = Colors.black87;
                                          List<Color> gradientColors = [Colors.white, Colors.white];

                                          if (_answered) {
                                            if (isCorrect) {
                                              gradientColors = [Colors.green.shade50, Colors.green.shade100];
                                              borderColor = Colors.green;
                                              textColor = Colors.green[800]!;
                                            } else if (isSelected && !isCorrect) {
                                              gradientColors = [Colors.red.shade50, Colors.red.shade100];
                                              borderColor = Colors.red;
                                              textColor = Colors.red[800]!;
                                            }
                                          } else if (isSelected) {
                                            gradientColors = [subjectColorLight, subjectColorLight];
                                            borderColor = subjectColor;
                                            textColor = subjectColor;
                                          }

                                          return Container(
                                            margin: EdgeInsets.only(bottom: isTablet ? 16 : 12),
                                            child: GestureDetector(
                                              onTap: () => _selectAnswer(answer),
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 300),
                                                curve: Curves.easeOutCubic,
                                                padding: EdgeInsets.all(isTablet ? 20 : 16),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    colors: gradientColors,
                                                  ),
                                                  borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
                                                  border: Border.all(
                                                    color: borderColor,
                                                    width: isSelected || (_answered && isCorrect) ? 3 : 2,
                                                  ),
                                                  boxShadow: isSelected || (_answered && isCorrect) ? [
                                                    BoxShadow(
                                                      color: borderColor.withOpacity(0.3),
                                                      blurRadius: 15,
                                                      offset: const Offset(0, 8),
                                                    ),
                                                  ] : [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.05),
                                                      blurRadius: 10,
                                                      offset: const Offset(0, 4),
                                                    ),
                                                  ],
                                                ),
                                                child: Row(
                                                  children: [
                                                    // Letter indicator
                                                    AnimatedContainer(
                                                      duration: const Duration(milliseconds: 300),
                                                      width: isTablet ? 40 : 32,
                                                      height: isTablet ? 40 : 32,
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          colors: _answered && isCorrect
                                                              ? [Colors.green, Colors.green.shade600]
                                                              : _answered && isSelected && !isCorrect
                                                                  ? [Colors.red, Colors.red.shade600]
                                                                  : isSelected
                                                                      ? [subjectColor, subjectColor.withOpacity(0.7)]
                                                                      : [Colors.grey[300]!, Colors.grey[400]!],
                                                        ),
                                                        shape: BoxShape.circle,
                                                        boxShadow: isSelected || (_answered && isCorrect) ? [
                                                          BoxShadow(
                                                            color: (isCorrect ? Colors.green : 
                                                                   isSelected ? subjectColor : Colors.red)
                                                                   .withOpacity(0.4),
                                                            blurRadius: 8,
                                                            offset: const Offset(0, 4),
                                                          ),
                                                        ] : [],
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          String.fromCharCode(65 + index),
                                                          style: GoogleFonts.inter(
                                                            fontSize: isTablet ? 18 : 16,
                                                            fontWeight: FontWeight.w700,
                                                            color: isSelected || (_answered && isCorrect)
                                                                ? Colors.white
                                                                : Colors.grey[600],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    
                                                    SizedBox(width: isTablet ? 20 : 16),
                                                    
                                                    // Answer text
                                                    Expanded(
                                                      child: Text(
                                                        answer,
                                                        style: GoogleFonts.inter(
                                                          fontSize: isTablet ? 18 : 16,
                                                          fontWeight: FontWeight.w600,
                                                          color: textColor,
                                                          height: 1.3,
                                                        ),
                                                      ),
                                                    ),
                                                    
                                                    // Result icon
                                                    if (_answered && isCorrect)
                                                      Container(
                                                        padding: EdgeInsets.all(isTablet ? 8 : 6),
                                                        decoration: BoxDecoration(
                                                          color: Colors.green,
                                                          shape: BoxShape.circle,
                                                        ),
                                                        child: Icon(
                                                          Icons.check,
                                                          color: Colors.white,
                                                          size: isTablet ? 20 : 16,
                                                        ),
                                                      )
                                                    else if (_answered && isSelected && !isCorrect)
                                                      Container(
                                                        padding: EdgeInsets.all(isTablet ? 8 : 6),
                                                        decoration: BoxDecoration(
                                                          color: Colors.red,
                                                          shape: BoxShape.circle,
                                                        ),
                                                        child: Icon(
                                                          Icons.close,
                                                          color: Colors.white,
                                                          size: isTablet ? 20 : 16,
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
                            ),
                            
                            // Next button
                            if (_answered) ...[
                              SizedBox(height: isTablet ? 24 : 20),
                              Container(
                                width: double.infinity,
                                height: isTablet ? 64 : 56,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.white, Colors.white.withOpacity(0.9)],
                                  ),
                                  borderRadius: BorderRadius.circular(isTablet ? 32 : 28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.5),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: subjectColor,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(isTablet ? 32 : 28),
                                    ),
                                  ),
                                  onPressed: _nextQuestion,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _currentQuestionIndex < _questions.length - 1
                                            ? 'Next Question'
                                            : 'Finish Quiz',
                                        style: GoogleFonts.inter(
                                          fontSize: isTablet ? 20 : 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      SizedBox(width: isTablet ? 12 : 8),
                                      Icon(
                                        _currentQuestionIndex < _questions.length - 1
                                            ? Icons.arrow_forward_rounded
                                            : Icons.flag_rounded,
                                        size: isTablet ? 28 : 24,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}