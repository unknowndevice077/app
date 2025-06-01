import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'quiz_overview.dart';
class QuizTakingScreen extends StatefulWidget {
  final List<Map<String, dynamic>> topics;
  final int questionCount;
  final Map<String, dynamic> subject;

  const QuizTakingScreen({
    super.key,
    required this.topics,
    required this.questionCount,
    required this.subject,
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

  // ✅ Quiz session tracking
  String? _quizSessionId;
  final List<Map<String, dynamic>> _quizResponses = [];
  DateTime? _quizStartTime;
  DateTime? _questionStartTime;

  @override
  void initState() {
    super.initState();
    _initializeQuizSession();

    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
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

  void _initializeQuizSession() {
    _quizSessionId = FirebaseFirestore.instance.collection('quiz_sessions').doc().id;
    _quizStartTime = DateTime.now();
    _questionStartTime = DateTime.now();
  }

  // ✅ Method to fetch topic documents and content
  Future<Map<String, String>> _getTopicDocuments(String topicId) async {
    Map<String, String> documentContents = {};
    
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return documentContents;

      // Get documents from the topic
      final documentsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('Classes')
          .doc(widget.subject['classId'] ?? '')
          .collection('topics')
          .doc(topicId)
          .collection('documents')
          .get();

      for (var doc in documentsSnapshot.docs) {
        final data = doc.data();
        final fileName = data['fileName'] ?? 'Unknown Document';
        final content = data['content'] ?? '';
        
        if (content.isNotEmpty) {
          documentContents[fileName] = content;
        }
      }

      print('📄 Found ${documentContents.length} documents with content for topic');
    } catch (e) {
      print('❌ Error fetching documents: $e');
    }

    return documentContents;
  }

  // ✅ Enhanced AI question generation with document content
  Future<List<Map<String, dynamic>>> _generateQuestionsWithAI(
    String topicTitle,
    String topicId,
    int questionsPerTopic,
  ) async {
    try {
      setState(() {
        _generatingQuestions = true;
      });

      // ✅ Fetch document contents for this topic
      final documentContents = await _getTopicDocuments(topicId);
      
      final model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.0-flash',
      );

      // ✅ Build enhanced prompt with document content
      String documentsContext = '';
      if (documentContents.isNotEmpty) {
        documentsContext = '\n\nRELEVANT DOCUMENTS AND MATERIALS:\n';
        documentContents.forEach((fileName, content) {
          documentsContext += '\n--- Document: $fileName ---\n';
          // Limit content length to avoid token limits
          final limitedContent = content.length > 3000 
              ? '${content.substring(0, 3000)}...' 
              : content;
          documentsContext += '$limitedContent\n';
        });
        documentsContext += '\n--- End of Documents ---\n';
      }

      final prompt = [
        Content.text('''
Generate exactly $questionsPerTopic multiple choice quiz questions about the topic: "$topicTitle".

${documentContents.isNotEmpty ? '''
IMPORTANT: Base your questions on the provided documents and materials below. The questions should test understanding of the specific content, concepts, definitions, and information found in these documents.
$documentsContext

Generate questions that:
- Use the illustrions in the documents to create context
- Even if the title of the topic is random focus on the content of the documents
- Test comprehension of the document content
- Ask about specific facts, concepts, or procedures mentioned in the materials
- Require understanding of the relationships between ideas in the documents
- Cover key points and important details from the provided materials
''' : '''
IMPORTANT: Since no documents are provided, generate general educational questions about the topic "$topicTitle" that would be appropriate for academic study.
'''}

Requirements for ALL questions:
- Each question should be educational and test understanding
- Provide exactly 4 answer options (A, B, C, D) for each question
- Mark one answer as correct
- Questions should be at an appropriate academic level
- Make distractors (wrong answers) plausible but clearly incorrect
- Ensure questions are clear and unambiguous
- Questions should be suitable for students studying this subject

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
${documentContents.isNotEmpty ? 'Questions should be based on the provided document content above.' : ''}

Please ensure the JSON is valid and contains exactly $questionsPerTopic questions.
'''),
      ];

      print('🤖 Generating $questionsPerTopic questions for topic: $topicTitle');
      print('📚 Using ${documentContents.length} documents as context');

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

        final generatedQuestions = questionsJson
            .map(
              (q) => {
                'question': q['question']?.toString() ?? '',
                'answers': List<String>.from(q['answers'] ?? []),
                'correctAnswer': q['correctAnswer']?.toString() ?? '',
                'topic': topicTitle,
                'topicId': topicId,
                'generated': true,
                'basedOnDocuments': documentContents.isNotEmpty,
                'documentCount': documentContents.length,
              },
            )
            .toList();

        print('✅ Generated ${generatedQuestions.length} questions${documentContents.isNotEmpty ? ' based on documents' : ''}');
        return generatedQuestions;
      }
    } catch (e) {
      print('❌ Error generating questions with AI: $e');
      return _generateFallbackQuestions(topicTitle, questionsPerTopic);
    }

    return [];
  }

  // Fallback question generation
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
        'basedOnDocuments': false,
        'documentCount': 0,
      },
    );
  }

  // ✅ Load questions with document-based generation
  Future<void> _loadQuestions() async {
    setState(() {
      _loading = true;
      _generatingQuestions = false;
    });

    try {
      List<Map<String, dynamic>> allQuestions = [];

      // First, try to load existing questions from Firebase
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
            'topicId': topic['id'],
            'generated': data['generated'] ?? false,
            'basedOnDocuments': data['basedOnDocuments'] ?? false,
            'documentCount': data['documentCount'] ?? 0,
          });
        }
      }

      // If we don't have enough questions, generate new ones using AI + documents
      if (allQuestions.length < widget.questionCount) {
        setState(() {
          _generatingQuestions = true;
        });

        final questionsNeeded = widget.questionCount - allQuestions.length;
        final questionsPerTopic = (questionsNeeded / widget.topics.length).ceil();

        for (var topic in widget.topics) {
          final existingQuestionsForTopic =
              allQuestions.where((q) => q['topicId'] == topic['id']).length;

          if (existingQuestionsForTopic < questionsPerTopic) {
            final additionalNeeded = questionsPerTopic - existingQuestionsForTopic;

            // ✅ Pass topic ID to enable document reading
            final aiQuestions = await _generateQuestionsWithAI(
              topic['title'],
              topic['id'], // ✅ Pass topic ID
              additionalNeeded,
            );

            allQuestions.addAll(aiQuestions);

            // Save generated questions to Firebase with document metadata
            for (var question in aiQuestions) {
              try {
                await FirebaseFirestore.instance.collection('questions').add({
                  'topicId': topic['id'],
                  'question': question['question'],
                  'answers': question['answers'],
                  'correctAnswer': question['correctAnswer'],
                  'generated': true,
                  'basedOnDocuments': question['basedOnDocuments'],
                  'documentCount': question['documentCount'],
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

  // ✅ Record answer and save to database
  void _selectAnswer(String answer) {
    if (!_answered) {
      final questionEndTime = DateTime.now();
      final timeSpent = questionEndTime.difference(_questionStartTime!).inSeconds;
      final isCorrect = answer == _questions[_currentQuestionIndex]['correctAnswer'];
      
      setState(() {
        _selectedAnswer = answer;
        _answered = true;
        if (isCorrect) {
          _score++;
        }
      });

      // ✅ Record this response
      final response = {
        'questionIndex': _currentQuestionIndex,
        'questionId': _questions[_currentQuestionIndex]['id'],
        'question': _questions[_currentQuestionIndex]['question'],
        'topicId': _questions[_currentQuestionIndex]['topicId'],
        'topicTitle': _questions[_currentQuestionIndex]['topic'],
        'selectedAnswer': answer,
        'correctAnswer': _questions[_currentQuestionIndex]['correctAnswer'],
        'isCorrect': isCorrect,
        'timeSpent': timeSpent,
        'answeredAt': questionEndTime,
        'basedOnDocuments': _questions[_currentQuestionIndex]['basedOnDocuments'] ?? false,
        'documentCount': _questions[_currentQuestionIndex]['documentCount'] ?? 0,
      };

      _quizResponses.add(response);

      // ✅ Save individual response to database immediately
      _saveQuestionResponse(response);
    }
  }

  // ✅ Save individual question response
  Future<void> _saveQuestionResponse(Map<String, dynamic> response) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('quiz_responses')
          .add({
        'quizSessionId': _quizSessionId,
        'classId': widget.subject['classId'],
        'className': widget.subject['title'],
        'classColor': widget.subject['color'],
        ...response,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ Saved question response for question ${response['questionIndex'] + 1}');
    } catch (e) {
      print('❌ Error saving question response: $e');
    }
  }

  // ✅ Next question with timing tracking
  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _answered = false;
        _selectedAnswer = null;
        _questionStartTime = DateTime.now(); // ✅ Reset question timer
      });
      _animationController.reset();
      _animationController.forward();
      
      final progress = (_currentQuestionIndex + 1) / _questions.length;
      _progressController.animateTo(progress);
    } else {
      _showResults();
    }
  }

  // ✅ Enhanced results with database recording
  void _showResults() {
    final percentage = (_score / _questions.length * 100).round();
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final quizEndTime = DateTime.now();
    final totalQuizTime = quizEndTime.difference(_quizStartTime!);

    // ✅ Save complete quiz session
    _saveCompleteQuizSession(percentage, totalQuizTime);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isTablet ? 32 : 24),
        ),
        elevation: 20,
        child: SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.all(isTablet ? 25 : 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue[50]!, // very light blue
                  Colors.blue[100]!, // light blue
                ],
              ),
              borderRadius: BorderRadius.circular(isTablet ? 32 : 24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Trophy icon with blue circle
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 1000),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        padding: EdgeInsets.all(isTablet ? 24 : 20),
                        decoration: BoxDecoration(
                          color: subjectColor, // solid blue
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: subjectColor.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.emoji_events,
                          color: Colors.white,
                          size: isTablet ? 40 : 32,
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: isTablet ? 24 : 20),

                // Title with strong contrast
                Text(
                  'Quiz Complete!',
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 32 : 28,
                    fontWeight: FontWeight.w800,
                    color: subjectColor, // strong blue
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: isTablet ? 32 : 24),

                // Score display with circular progress
                SizedBox(
                  width: isTablet ? 180 : 150,
                  height: isTablet ? 180 : 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
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
                              backgroundColor: Colors.blue[100],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                subjectColor,
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
                                  color: subjectColor,
                                ),
                              );
                            },
                          ),
                          Text(
                            '$percentage%',
                            style: GoogleFonts.inter(
                              fontSize: isTablet ? 18 : 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: isTablet ? 32 : 24),

                // Motivational message
                Container(
                  padding: EdgeInsets.all(isTablet ? 20 : 16),
                  decoration: BoxDecoration(
                    color: subjectColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: subjectColor.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        percentage >= 70 ? Icons.celebration : Icons.lightbulb_outline,
                        color: subjectColor,
                        size: isTablet ? 24 : 20,
                      ),
                      SizedBox(width: isTablet ? 12 : 8),
                      Expanded(
                        child: Text(
                          percentage >= 70
                              ? 'Excellent work! You have mastered this material.'
                              : 'Good effort! Review the explanations to improve.',
                          style: GoogleFonts.inter(
                            fontSize: isTablet ? 16 : 14,
                            fontWeight: FontWeight.w500,
                            color: subjectColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: isTablet ? 32 : 24),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Try Again button
                    Container(
                      width: isTablet ? 200 : 150,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: subjectColor,
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

                    // Review Results button
                    Container(
                      width: isTablet ? 200 : 150,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: subjectColor.withOpacity(0.15),
                          foregroundColor: subjectColor,
                          padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context); // Close the dialog
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => QuizOverviewScreen(
                                questions: _questions,
                                quizResponses: _quizResponses,
                                subject: widget.subject,
                                score: _score,
                                totalQuestions: _questions.length,
                                totalTime: DateTime.now().difference(_quizStartTime!),
                              ),
                            ),
                          );
                        },
                        child: Text(
                          'Review Results',
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
      ));
  }

  // ✅ Save complete quiz session
  Future<void> _saveCompleteQuizSession(int percentage, Duration totalTime) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Calculate analytics
      final correctAnswers = _quizResponses.where((r) => r['isCorrect']).length;
      final avgTimePerQuestion = totalTime.inSeconds / _questions.length;
      final documentBasedQuestions = _getDocumentBasedCount();
      final documentBasedCorrect = _quizResponses
          .where((r) => r['basedOnDocuments'] == true && r['isCorrect'] == true)
          .length;

      // Topic performance breakdown
      Map<String, Map<String, dynamic>> topicPerformance = {};
      for (var response in _quizResponses) {
        final topicId = response['topicId'] ?? 'unknown';
        final topicTitle = response['topicTitle'] ?? 'Unknown Topic';
        
        if (!topicPerformance.containsKey(topicId)) {
          topicPerformance[topicId] = {
            'total': 0,
            'correct': 0,
            'title': topicTitle,
          };
        }
        
        topicPerformance[topicId]!['total'] = (topicPerformance[topicId]!['total'] ?? 0) + 1;
        if (response['isCorrect']) {
          topicPerformance[topicId]!['correct'] = (topicPerformance[topicId]!['correct'] ?? 0) + 1;
        }
      }

      // Save quiz session summary
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('quiz_sessions')
          .doc(_quizSessionId)
          .set({
        'classId': widget.subject['classId'],
        'className': widget.subject['title'],
        'classColor': widget.subject['color'],
        'totalQuestions': _questions.length,
        'correctAnswers': correctAnswers,
        'score': _score,
        'percentage': percentage,
        'totalTimeSeconds': totalTime.inSeconds,
        'avgTimePerQuestion': avgTimePerQuestion,
        'documentBasedQuestions': documentBasedQuestions,
        'documentBasedCorrect': documentBasedCorrect,
        'topicPerformance': topicPerformance.map((key, value) => MapEntry(key, {
          'topicTitle': value['title'],
          'total': value['total'],
          'correct': value['correct'],
          'percentage': value['total']! > 0 ? (value['correct']! / value['total']! * 100).round() : 0,
        })),
        'quizStartTime': Timestamp.fromDate(_quizStartTime!),
        'quizEndTime': FieldValue.serverTimestamp(),
        'topics': widget.topics.map((t) => t['title']).toList(),
        'topicIds': widget.topics.map((t) => t['id']).toList(),
        'passed': percentage >= 70,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ✅ Update user's overall stats
      await _updateUserQuizStats(percentage >= 70);

      print('✅ Saved complete quiz session: $_quizSessionId');
      print('📊 Score: $correctAnswers/$_questions.length ($percentage%)');
      print('⏱️ Total time: ${_formatDuration(totalTime)}');
    } catch (e) {
      print('❌ Error saving quiz session: $e');
    }
  }

  // ✅ Update user's overall quiz statistics
  Future<void> _updateUserQuizStats(bool passed) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final userStatsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('stats')
          .doc('quiz_stats');

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final doc = await transaction.get(userStatsRef);
        
        if (doc.exists) {
          final data = doc.data()!;
          transaction.update(userStatsRef, {
            'totalQuizzes': (data['totalQuizzes'] ?? 0) + 1,
            'totalQuestionsSeen': (data['totalQuestionsSeen'] ?? 0) + _questions.length,
            'totalCorrectAnswers': (data['totalCorrectAnswers'] ?? 0) + _score,
            'quizzesPassed': (data['quizzesPassed'] ?? 0) + (passed ? 1 : 0),
            'lastQuizDate': FieldValue.serverTimestamp(),
            'classesStudied': FieldValue.arrayUnion([widget.subject['classId']]),
          });
        } else {
          transaction.set(userStatsRef, {
            'totalQuizzes': 1,
            'totalQuestionsSeen': _questions.length,
            'totalCorrectAnswers': _score,
            'quizzesPassed': passed ? 1 : 0,
            'lastQuizDate': FieldValue.serverTimestamp(),
            'classesStudied': [widget.subject['classId']],
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });

      print('✅ Updated user quiz statistics');
    } catch (e) {
      print('❌ Error updating user stats: $e');
    }
  }

  // ✅ Helper methods
  int _getDocumentBasedCount() {
    return _questions.where((q) => q['basedOnDocuments'] == true).length;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: subjectColor),
        SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // ✅ Helper method for progress steps
  Widget _buildProgressStep(String icon, String label, bool active) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: active ? subjectColor.withOpacity(0.2) : Colors.grey[200],
            shape: BoxShape.circle,
          ),
          child: Text(
            icon,
            style: TextStyle(fontSize: 20),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: active ? subjectColor : Colors.grey[500],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildProgressArrow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Icon(
        Icons.arrow_forward,
        color: Colors.grey[400],
        size: 16,
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
                          _generatingQuestions ? 'Analyzing Documents & Generating Questions...' : 'Preparing Quiz...',
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
                              // ✅ Enhanced AI generation animation with document context
                              Container(
                                padding: EdgeInsets.all(isTablet ? 24 : 20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [subjectColor, subjectColor.withOpacity(0.7)],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.description, // ✅ Document icon
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
                                  'Analyzing Your Materials', // ✅ Updated text
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
                                'Reading uploaded documents and creating\n${widget.questionCount} personalized questions based on your study materials', // ✅ Updated description
                                style: GoogleFonts.inter(
                                  fontSize: isTablet ? 16 : 14,
                                  color: Colors.grey[600],
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: isTablet ? 32 : 24),
                              // Progress indicators
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildProgressStep('📄', 'Reading\nDocuments', true),
                                  _buildProgressArrow(),
                                  _buildProgressStep('🤖', 'Generating\nQuestions', true),
                                  _buildProgressArrow(),
                                  _buildProgressStep('✨', 'Preparing\nQuiz', false),
                                ],
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
              // App bar and progress
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
                                          fontWeight: FontWeight.w500,
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
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Next Question button in a separate container
              if (_answered)
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.symmetric(
                    horizontal: isTablet ? 40 : 20,
                    vertical: isTablet ? 24 : 16,
                  ),
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
                              : Icons.analytics_rounded,
                          size: isTablet ? 28 : 24,
                        ),
                      ],
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