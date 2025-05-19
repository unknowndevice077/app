import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Calendar extends StatelessWidget {
  const Calendar({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Calendar', style: GoogleFonts.dmSerifText(fontSize: 40)),
      ),
      body: const Center(
        child: Text(
          'No events yet.',
          style: TextStyle(fontSize: 18, color: Colors.black54),
        ),
      ),
    );
  }
}
