import 'package:flutter/material.dart';
import 'package:app/home%20page/navbar/Study/timer.dart';
import 'package:google_fonts/google_fonts.dart';
class Study extends StatelessWidget {
  const Study({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      appBar: AppBar(
        centerTitle: true,
        title: Text('Study', style: GoogleFonts.dmSerifText(fontSize: 40)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 24, left: 16),
        child: Align(
          alignment: Alignment.topLeft,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StudyTimerPage()),
              );
            },
            child: Card(
              color: const Color.fromARGB(255, 255, 255, 255),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: SizedBox(
                width: 200,
                height: 120,
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer, color: Colors.black87, size: 32),
                      const SizedBox(width: 12),
                      Text(
                        'Timer',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}