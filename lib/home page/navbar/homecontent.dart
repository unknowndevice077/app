import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'classes.dart'; // Import your ClassModel and ExpandableClassCard

class Homecontent extends StatelessWidget {
  const Homecontent({super.key});

  String getTodayName() {
    final weekday = DateTime.now().weekday;
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final today = getTodayName();
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text("Today's Classes",style: GoogleFonts.dmSerifText(color: Colors.black, fontSize: 28),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      backgroundColor: Colors.white,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('Classes').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'No classes found.',
                style: GoogleFonts.dmSerifText(fontSize: 20, color: Colors.grey),
              ),
            );
          }
          final docs = snapshot.data!.docs;
          final todayClasses = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final List days = data['days'] != null ? List<String>.from(data['days']) : <String>[];
            return days.contains(today);
          }).toList();

          if (todayClasses.isEmpty) {
            return Center(
              child: Text(
                'No classes today!',
                style: GoogleFonts.dmSerifText(fontSize: 22, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: todayClasses.length,
            itemBuilder: (context, index) {
              final doc = todayClasses[index];
              final data = doc.data() as Map<String, dynamic>;
              final classModel = ClassModel(
                title: data['title'] ?? '',
                time: data['time'] ?? '',
                location: data['location'] ?? '',
                teacher: data['teacher'] ?? '',
                notes: data['notes'] ?? '',
                color: Color(data['color'] ?? Colors.white.value),
                days: data['days'] != null ? List<String>.from(data['days']) : <String>[],
              );
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                child: ExpandableClassCard(
                  classModel: classModel,
                  // Don't pass onEdit/onDelete so icons are hidden
                ),
              );
            },
          );
        },
      ),
    );
  }
}
