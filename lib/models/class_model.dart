import 'package:flutter/material.dart'; // ✅ Add this import

class ClassModel {
  final String title;
  final String time;
  final String location;
  final String teacher;
  final String notes;
  final Color color;  // ✅ Now Color is recognized
  final List<String> days;

  ClassModel({
    required this.title,
    required this.time,
    required this.location,
    required this.teacher,
    required this.notes,
    required this.color,
    required this.days,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'time': time,
      'location': location,
      'teacher': teacher,
      'notes': notes,
      'color': color.value,
      'days': days,
    };
  }

  factory ClassModel.fromFirestore(Map<String, dynamic> data) {
    return ClassModel(
      title: data['title'] ?? '',
      time: data['time'] ?? '',
      location: data['location'] ?? '',
      teacher: data['teacher'] ?? '',
      notes: data['notes'] ?? '',
      color: Color(data['color'] ?? Colors.white.value), // ✅ Now works
      days: data['days'] != null ? List<String>.from(data['days']) : <String>[],
    );
  }
}