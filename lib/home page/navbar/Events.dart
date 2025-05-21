import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Events extends StatelessWidget {
  const Events({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // <-- Set background to white
      appBar: AppBar(
        centerTitle: true,
        title: Text('Events', style: GoogleFonts.dmSerifText(fontSize: 40)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
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
