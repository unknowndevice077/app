import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NoteSubjectManager {
  Future<List<String>> fetchSubjects() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];
      
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('Classes')
          .get();
      
      return snapshot.docs.map((doc) => doc['title'] as String).toList();
    } catch (e) {
      print('Error fetching subjects: $e');
      return [];
    }
  }

  Color getSubjectColor(String subject) {
    try {
      if (subject.isEmpty) return Colors.blueGrey[400]!;
      final hash = subject.toLowerCase().hashCode;
      final colors = [
        Colors.blue, Colors.green, Colors.orange, Colors.purple,
        Colors.red, Colors.teal, Colors.indigo, Colors.pink,
        Colors.amber, Colors.cyan, Colors.deepOrange, Colors.lightGreen,
      ];
      return colors[hash.abs() % colors.length];
    } catch (e) {
      print('Error getting subject color: $e');
      return Colors.blueGrey[400]!;
    }
  }

  Future<Color> getClassColor(String className) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return getSubjectColor(className);

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('Classes')
          .where('title', isEqualTo: className)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final classData = snapshot.docs.first.data();
        final colorValue = classData['color'] as int?;
        if (colorValue != null) {
          return Color(colorValue);
        }
      }
      return getSubjectColor(className);
    } catch (e) {
      return getSubjectColor(className);
    }
  }

  void showSubjectSelection(
    BuildContext context,
    List<String> subjects,
    String? selectedSubject,
    bool subjectsLoading,
    Function(String?) onSubjectSelected,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Select Subject',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: subjectsLoading
              ? const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                )
              : subjects.isEmpty
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.school_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No subjects found',
                          style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600]),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Create classes first to add subjects',
                          style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[500]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: 300),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: subjects.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return ListTile(
                              leading: Icon(Icons.clear, color: Colors.grey[600]),
                              title: Text(
                                'No Subject',
                                style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600]),
                              ),
                              trailing: selectedSubject == null
                                  ? Icon(Icons.check, color: Colors.grey[600])
                                  : null,
                              onTap: () {
                                onSubjectSelected(null);
                                Navigator.pop(context);
                              },
                            );
                          }

                          final subject = subjects[index - 1];
                          final color = getSubjectColor(subject);

                          return ListTile(
                            leading: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            title: Text(
                              subject,
                              style: GoogleFonts.inter(fontSize: 16),
                            ),
                            trailing: selectedSubject == subject
                                ? Icon(Icons.check, color: color)
                                : null,
                            onTap: () {
                              onSubjectSelected(subject);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: Colors.grey[600], fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}