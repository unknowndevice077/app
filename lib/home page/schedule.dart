import 'package:flutter/material.dart';

void main() => runApp(MaterialApp(home: ClassSchedulePage()));

class ClassSchedulePage extends StatefulWidget {
  const ClassSchedulePage({super.key});

  @override
  State<ClassSchedulePage> createState() => _ClassSchedulePageState();
}

class _ClassSchedulePageState extends State<ClassSchedulePage> {
  List<Map<String, String>> classes = [];

  void _showAddClassForm() {
    final _formKey = GlobalKey<FormState>();
    String title = '', teacher = '', time = '', date = '', room = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Form(
            key: _formKey,
            child: Wrap(
              children: [
                const Text("Add Class", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Class Title'),
                  onChanged: (val) => title = val,
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Date (e.g. 24 March)'),
                  onChanged: (val) => date = val,
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Time (e.g. 18:00 - 19:00)'),
                  onChanged: (val) => time = val,
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Teacher Name'),
                  onChanged: (val) => teacher = val,
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Room'),
                  onChanged: (val) => room = val,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  onPressed: () {
                    if (title.isEmpty || time.isEmpty) return;
                    Navigator.pop(context);
                    setState(() {
                      classes.add({
                        'title': title,
                        'date': date,
                        'time': time,
                        'teacher': teacher,
                        'room': room,
                      });
                    });
                  },
                  child: const Text("Save Class"),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Classes")),
      body: ListView(
        children: classes.map((cls) {
          return ExpandableClassCard(
            title: cls['title'] ?? '',
            teacher: cls['teacher'] ?? '',
            time: cls['time'] ?? '',
            date: cls['date'] ?? '',
            room: cls['room'] ?? '',
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddClassForm,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ExpandableClassCard extends StatefulWidget {
  final String title;
  final String teacher;
  final String time;
  final String date;
  final String room;

  const ExpandableClassCard({
    super.key,
    required this.title,
    required this.teacher,
    required this.time,
    required this.date,
    required this.room,
  });

  @override
  State<ExpandableClassCard> createState() => _ExpandableClassCardState();
}

class _ExpandableClassCardState extends State<ExpandableClassCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orangeAccent.shade100,
          borderRadius: BorderRadius.circular(20),
          boxShadow: _isExpanded
              ? [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.more_horiz, color: Colors.white),
              ],
            ),
            const SizedBox(height: 4),
            Text("${widget.date}, ${widget.time}", style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 12),
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, color: Colors.orange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.teacher, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      const Text("Professor", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            if (_isExpanded) ...[
              const SizedBox(height: 16),
              const Divider(color: Colors.white54),
              Text("Room: ${widget.room}", style: const TextStyle(color: Colors.white70)),
              const Text("This class covers the basics and more.", style: TextStyle(color: Colors.white)),
            ]
          ],
        ),
      ),
    );
  }
}
