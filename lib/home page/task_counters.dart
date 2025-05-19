import 'package:flutter/material.dart';

class Counters extends StatelessWidget {
  const Counters({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Task Counters',
          style: TextStyle(color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Container(
        color: const Color.fromARGB(255, 255, 255, 255), // Set the new background color
        child: Column(
          children: [
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                CounterCard(title: 'Classes', count: '5'),
                CounterCard(title: 'Assignments', count: '3'),
                CounterCard(title: 'Exams', count: '2'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CounterCard extends StatelessWidget {
  final String title;
  final String count;
  final double width;
  final double height;
  const CounterCard({
    super.key,
    required this.title,
    required this.count,
    this.width = 100,
    this.height = 100,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 100,
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 0, 0, 0),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            count,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
