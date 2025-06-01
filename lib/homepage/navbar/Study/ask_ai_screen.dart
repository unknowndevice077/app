import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_ai/firebase_ai.dart';

class AskAiScreen extends StatefulWidget {
  const AskAiScreen({super.key});

  @override
  State<AskAiScreen> createState() => _AskAiScreenState();
}

class _AskAiScreenState extends State<AskAiScreen> {
  final List<_ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  bool _isSending = false;
  bool _isTyping = false;
  String _typingText = "";
  bool _skipTyping = false;

  void _addMessage(_ChatMessage message) {
    _messages.add(message);
    _listKey.currentState?.insertItem(_messages.length - 1, duration: const Duration(milliseconds: 350));
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _controller.clear();
      _isSending = true;
    });
    _addMessage(_ChatMessage(text: text, isUser: true));

    try {
      final model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.0-flash',
      );
      final prompt = [
        Content.text(text),
      ];
      final response = await model.generateContent(prompt);

      String aiText = response.text?.trim() ?? "Sorry, I couldn't generate a response.";
      await _showTypingAnimation(aiText);
    } catch (e) {
      _addMessage(_ChatMessage(
        text: "AI Error: $e",
        isUser: false,
      ));
    } finally {
      setState(() {
        _isSending = false;
        _isTyping = false;
        _typingText = "";
      });
    }
  }

  // Update _showTypingAnimation to occasionally auto-skip long responses

  Future<void> _showTypingAnimation(String fullText) async {
    setState(() {
      _isTyping = true;
      _typingText = "";
      _skipTyping = false;
    });

    // If the response is very long, occasionally skip the animation for the rest
    final int maxAnimatedChars = 400; // Animate up to 400 chars, then skip
    bool autoSkipped = false;

    for (int i = 1; i <= fullText.length; i++) {
      // If user taps, skip immediately
      if (_skipTyping) {
        setState(() {
          _typingText = fullText;
        });
        break;
      }
      // If long and not yet auto-skipped, skip after maxAnimatedChars
      if (!autoSkipped && fullText.length > maxAnimatedChars && i == maxAnimatedChars) {
        await Future.delayed(const Duration(milliseconds: 100));
        setState(() {
          _typingText = fullText;
        });
        autoSkipped = true;
        break;
      }
      await Future.delayed(const Duration(milliseconds: 8));
      setState(() {
        _typingText = fullText.substring(0, i);
      });
    }
    _addMessage(_ChatMessage(text: fullText, isUser: false));
    setState(() {
      _isTyping = false;
      _typingText = "";
      _skipTyping = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Ask AI', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty && !_isTyping
                ? Center(
                    child: Text(
                      "What can I help you with?",
                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 18),
                    ),
                  )
                : AnimatedList(
                    key: _listKey,
                    initialItemCount: _messages.length,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    itemBuilder: (context, idx, animation) {
                      final msg = _messages[idx];
                      return SizeTransition(
                        sizeFactor: animation,
                        axisAlignment: 0.0,
                        child: Align(
                          alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOut,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: msg.isUser ? Colors.blue[700] : Colors.grey[900],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              msg.text,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_isTyping)
            GestureDetector(
              onTap: () {
                setState(() {
                  _skipTyping = true;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            _typingText,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                          margin: const EdgeInsets.only(left: 2),
                          width: 10,
                          height: 18,
                          child: _isTyping
                              ? const BlinkingCursor()
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Container(
            color: Colors.black,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Type your question...",
                      hintStyle: TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _isSending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                  onPressed: _isSending ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  _ChatMessage({required this.text, required this.isUser});
}

class BlinkingCursor extends StatefulWidget {
  const BlinkingCursor({super.key});
  @override
  State<BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<BlinkingCursor> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 1, end: 0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 8,
        height: 18,
        color: Colors.white,
      ),
    );
  }
}