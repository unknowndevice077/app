import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_ai/firebase_ai.dart';

class QuizOverviewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> questions;
  final List<Map<String, dynamic>> quizResponses;
  final Map<String, dynamic> subject;
  final int score;
  final int totalQuestions;
  final Duration totalTime;

  const QuizOverviewScreen({
    super.key,
    required this.questions,
    required this.quizResponses,
    required this.subject,
    required this.score,
    required this.totalQuestions,
    required this.totalTime,
  });

  @override
  State<QuizOverviewScreen> createState() => _QuizOverviewScreenState();
}

class _QuizOverviewScreenState extends State<QuizOverviewScreen>
    with TickerProviderStateMixin {
  
  final Map<int, String> _aiExplanations = {};
  final Map<int, bool> _loadingExplanations = {};
  late ScrollController _scrollController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Get subject color
  Color get subjectColor => Color(widget.subject['color']);
  Color get subjectColorLight => subjectColor.withOpacity(0.1);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    
    _fadeController.forward();
    
    // Auto-generate explanations for incorrect answers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateExplanationsForIncorrectAnswers();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _generateExplanationsForIncorrectAnswers() async {
    for (int i = 0; i < widget.quizResponses.length; i++) {
      final response = widget.quizResponses[i];
      if (!response['isCorrect']) {
        _generateAIExplanation(i);
      }
    }
  }

  Future<void> _generateAIExplanation(int questionIndex) async {
    if (_loadingExplanations[questionIndex] == true || 
        _aiExplanations.containsKey(questionIndex)) {
      return;
    }

    setState(() {
      _loadingExplanations[questionIndex] = true;
    });

    try {
      final response = widget.quizResponses[questionIndex];
      final question = widget.questions[questionIndex];
      
      final model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.0-flash',
      );

      final prompt = [
        Content.text('''

dont repeat the question or answers, just provide a clear explanation.
You are an educational AI tutor. A student just answered a quiz question incorrectly. Please provide a clear, helpful explanation.

QUESTION: ${question['question']}

AVAILABLE OPTIONS:
${question['answers'].asMap().entries.map((e) => '${String.fromCharCode(65 + (e.key as int))}. ${e.value}').join('\n')}

STUDENT'S ANSWER: ${response['selectedAnswer']}
CORRECT ANSWER: ${response['correctAnswer']}

Please provide:
1. Why the student's answer is incorrect (be gentle and educational)
2. Why the correct answer is right (explain the reasoning)
3. Key concepts or facts the student should remember
4. A helpful tip or memory aid if applicable

Keep the explanation:
- Clear and concise (2-3 short paragraphs)
- Educational and supportive
- Focused on learning, not criticism
- Age-appropriate for students

Format the response as plain text, no special formatting needed.
'''),
      ];

      final aiResponse = await model.generateContent(prompt);
      
      if (aiResponse.text != null) {
        setState(() {
          _aiExplanations[questionIndex] = aiResponse.text!;
          _loadingExplanations[questionIndex] = false;
        });
      } else {
        throw Exception('No response from AI');
      }
    } catch (e) {
      print('Error generating AI explanation: $e');
      setState(() {
        _aiExplanations[questionIndex] = '''
Unable to generate explanation at this time. 

The correct answer is: ${widget.quizResponses[questionIndex]['correctAnswer']}

Try reviewing your study materials for this topic: ${widget.quizResponses[questionIndex]['topicTitle']}
''';
        _loadingExplanations[questionIndex] = false;
      });
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }

  Widget _buildQuestionCard(int index) {
    final response = widget.quizResponses[index];
    final question = widget.questions[index];
    final isCorrect = response['isCorrect'];
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
        border: Border.all(
          color: isCorrect ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isCorrect ? Colors.green : Colors.red).withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question header
          Container(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isCorrect 
                    ? [Colors.green.shade50, Colors.green.shade100]
                    : [Colors.red.shade50, Colors.red.shade100],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(isTablet ? 20 : 16),
                topRight: Radius.circular(isTablet ? 20 : 16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isTablet ? 12 : 10),
                  decoration: BoxDecoration(
                    color: isCorrect ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCorrect ? Icons.check : Icons.close,
                    color: Colors.white,
                    size: isTablet ? 24 : 20,
                  ),
                ),
                SizedBox(width: isTablet ? 16 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Question ${index + 1}',
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 18 : 16,
                          fontWeight: FontWeight.w700,
                          color: isCorrect ? Colors.green[800] : Colors.red[800],
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.book_outlined,
                            size: isTablet ? 16 : 14,
                            color: Colors.grey[600],
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              response['topicTitle'] ?? 'Unknown Topic',
                              style: GoogleFonts.inter(
                                fontSize: isTablet ? 14 : 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 10 : 8,
                              vertical: isTablet ? 4 : 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${response['timeSpent']}s',
                              style: GoogleFonts.inter(
                                fontSize: isTablet ? 12 : 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Question content
          Padding(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question text
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isTablet ? 20 : 16),
                  decoration: BoxDecoration(
                    color: subjectColorLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    question['question'],
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ),

                SizedBox(height: isTablet ? 20 : 16),

                // Answer options
                ...question['answers'].asMap().entries.map((entry) {
                  final optionIndex = entry.key;
                  final option = entry.value;
                  final isSelected = option == response['selectedAnswer'];
                  final isCorrectAnswer = option == response['correctAnswer'];
                  
                  Color backgroundColor = Colors.grey[50]!;
                  Color borderColor = Colors.grey[200]!;
                  Color textColor = Colors.black87;
                  IconData? icon;
                  Color? iconColor;

                  if (isCorrectAnswer) {
                    backgroundColor = Colors.green.shade50;
                    borderColor = Colors.green;
                    textColor = Colors.green[800]!;
                    icon = Icons.check_circle;
                    iconColor = Colors.green;
                  } else if (isSelected && !isCorrect) {
                    backgroundColor = Colors.red.shade50;
                    borderColor = Colors.red;
                    textColor = Colors.red[800]!;
                    icon = Icons.cancel;
                    iconColor = Colors.red;
                  }

                  return Container(
                    margin: EdgeInsets.only(bottom: isTablet ? 12 : 8),
                    padding: EdgeInsets.all(isTablet ? 16 : 12),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor, width: 2),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: isTablet ? 32 : 28,
                          height: isTablet ? 32 : 28,
                          decoration: BoxDecoration(
                            color: isCorrectAnswer 
                                ? Colors.green 
                                : isSelected 
                                    ? Colors.red 
                                    : Colors.grey[400],
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              String.fromCharCode(65 + (optionIndex as int)),
                              style: GoogleFonts.inter(
                                fontSize: isTablet ? 16 : 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: isTablet ? 16 : 12),
                        Expanded(
                          child: Text(
                            option,
                            style: GoogleFonts.inter(
                              fontSize: isTablet ? 16 : 14,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                        ),
                        if (icon != null)
                          Icon(icon, color: iconColor, size: isTablet ? 24 : 20),
                      ],
                    ),
                  );
                }).toList(),

                // AI Explanation for incorrect answers
                if (!isCorrect) ...[
                  SizedBox(height: isTablet ? 20 : 16),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isTablet ? 20 : 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blue.shade50,
                          Colors.blue.shade100,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(isTablet ? 8 : 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.blue, Colors.blue.shade600],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.psychology,
                                color: Colors.white,
                                size: isTablet ? 20 : 16,
                              ),
                            ),
                            SizedBox(width: isTablet ? 12 : 8),
                            Text(
                              'Studia Tutor Explanation',
                              style: GoogleFonts.inter(
                                fontSize: isTablet ? 18 : 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.blue[800],
                              ),
                            ),
                            Spacer(),
                            if (_loadingExplanations[index] == true)
                              SizedBox(
                                width: isTablet ? 20 : 16,
                                height: isTablet ? 20 : 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: isTablet ? 16 : 12),
                        if (_loadingExplanations[index] == true)
                          Row(
                            children: [
                              SizedBox(
                                width: isTablet ? 16 : 14,
                                height: isTablet ? 16 : 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                ),
                              ),
                              SizedBox(width: isTablet ? 12 : 8),
                              Text(
                                'Generating personalized explanation...',
                                style: GoogleFonts.inter(
                                  fontSize: isTablet ? 14 : 12,
                                  color: Colors.blue[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          )
                        else if (_aiExplanations.containsKey(index))
                          Text(
                            _aiExplanations[index]!,
                            style: GoogleFonts.inter(
                              fontSize: isTablet ? 15 : 13,
                              color: Colors.blue[800],
                              height: 1.5,
                            ),
                          )
                        else
                          TextButton.icon(
                            onPressed: () => _generateAIExplanation(index),
                            icon: Icon(Icons.refresh, size: isTablet ? 18 : 16),
                            label: Text(
                              'Get AI Explanation',
                              style: GoogleFonts.inter(
                                fontSize: isTablet ? 14 : 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final percentage = (widget.score / widget.totalQuestions * 100).round();

    return Scaffold(
      // Remove backgroundColor so gradient shows through
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [subjectColor, subjectColor.withOpacity(0.8)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Modern AppBar
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 24 : 16,
                    vertical: isTablet ? 24 : 16,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.white, size: isTablet ? 28 : 24),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          'Quiz Review',
                          style: GoogleFonts.inter(
                            fontSize: isTablet ? 28 : 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.home, color: Colors.white, size: isTablet ? 28 : 24),
                        onPressed: () {
                          Navigator.popUntil(context, (route) => route.isFirst);
                        },
                      ),
                    ],
                  ),
                ),
                // Blended summary header
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(isTablet ? 28 : 20),
                      boxShadow: [
                        BoxShadow(
                          color: subjectColor.withOpacity(0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(isTablet ? 28 : 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(isTablet ? 18 : 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                percentage >= 70 ? Icons.emoji_events : Icons.insights,
                                color: Colors.white,
                                size: isTablet ? 36 : 28,
                              ),
                            ),
                            SizedBox(width: isTablet ? 24 : 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${widget.score}/${widget.totalQuestions} Correct',
                                    style: GoogleFonts.inter(
                                      fontSize: isTablet ? 32 : 24,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    '$percentage% • ${_formatDuration(widget.totalTime)}',
                                    style: GoogleFonts.inter(
                                      fontSize: isTablet ? 16 : 13,
                                      color: Colors.white.withOpacity(0.92),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isTablet ? 24 : 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'Correct',
                                '${widget.score}',
                                Icons.check_circle,
                                Colors.green,
                                isTablet,
                              ),
                            ),
                            SizedBox(width: isTablet ? 16 : 10),
                            Expanded(
                              child: _buildStatCard(
                                'Incorrect',
                                '${widget.totalQuestions - widget.score}',
                                Icons.cancel,
                                Colors.red,
                                isTablet,
                              ),
                            ),
                            SizedBox(width: isTablet ? 16 : 10),
                            Expanded(
                              child: _buildStatCard(
                                'Avg Time',
                                '${(widget.totalTime.inSeconds / widget.totalQuestions).round()}s',
                                Icons.timer,
                                Colors.orange,
                                isTablet,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: isTablet ? 32 : 20),
                // Questions list
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 16),
                  child: Column(
                    children: List.generate(
                      widget.questions.length,
                      (index) => _buildQuestionCard(index),
                    ),
                  ),
                ),
                SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: isTablet ? 24 : 20),
          SizedBox(height: isTablet ? 8 : 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: isTablet ? 20 : 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: isTablet ? 12 : 10,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}