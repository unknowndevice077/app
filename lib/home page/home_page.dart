import 'package:app/home%20page/task_counters.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'class_form.dart';
import 'classes.dart';

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<ClassModel> _classList = [];

  void _addOrEditClass({ClassModel? existing, int? index}) async {
    final result = await showDialog<ClassModel>(
      context: context,
      builder: (_) => ClassFormDialog(existing: existing),
    );

    if (result != null) {
      setState(() {
        if (index != null) {
          _classList[index] = result; // Update
        } else {
          _classList.add(result); // Create
        }
      });
    }
  }

  void _deleteClass(int index) {
    setState(() {
      _classList.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white, // Set the background color of the entire page to white
      child: Scaffold(
        backgroundColor: Colors.white, // Ensure the Scaffold background is also white
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: AssetImage('lib/images/Finn The Human.jpg'),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Good morning",
                        style: TextStyle(fontSize: 12, color: Colors.black),
                      ),
                      const Text(
                        "Jae",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          iconTheme: const IconThemeData(color: Colors.black),
          elevation: 0,
        ),
        endDrawer: Drawer(
          child: Container(
            color: const Color.fromARGB(255, 190, 189, 189), // Uniform background color
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: const BoxDecoration(
                    color: Color.fromARGB(255, 190, 189, 189),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: AssetImage('lib/images/Finn The Human.jpg'),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Hi, Jae',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        FirebaseAuth.instance.currentUser!.email ?? '',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.home, color: Colors.black),
                  title: const Text(
                    'Home',
                    style: TextStyle(color: Colors.black),
                  ),
                  onTap: () {
                    Navigator.pop(context); // Close the drawer
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings, color: Colors.black),
                  title: const Text(
                    'Settings',
                    style: TextStyle(color: Colors.black),
                  ),
                  onTap: () {
                    // Navigate to settings page
                  },
                ),
                const Spacer(), // Push logout to the bottom
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.black),
                  title: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.black),
                  ),
                  onTap: () {
                    FirebaseAuth.instance.signOut();
                    Navigator.pop(context); // Close the drawer
                  },
                ),
              ],
            ),
          ),
        ),
        body: Column(
          children: [
            const SizedBox(height: 40), // Add spacing above the counters
            // Add a container for the counters
            Container(
              height: 100, // Adjust height as needed
              color: Colors.white, // Ensure the counters container is white
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  CounterCard(title: 'Classes', count: _classList.length.toString()),
                  const CounterCard(title: 'Assignments', count: '3'),
                  const CounterCard(title: 'Exams', count: '2'),
                ],
              ),
            ),

            // The container for the class cards
            Expanded(
              child: Container(
                color: Colors.white, // Ensure the class cards container is white
                child: Padding(
                  padding: const EdgeInsets.only(top: 40), // Add padding to lower the cards
                  child: _classList.isEmpty
                      ? Align(
                          alignment: Alignment.topCenter, // Align the text at the top center
                          child: Padding(
                            padding: const EdgeInsets.only(top: 70), // Add some spacing from the top
                            child: const Text(
                              'No classes yet. Add some!',
                              style: TextStyle(color: Colors.black), // Ensure text is visible
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _classList.length,
                          itemBuilder: (context, index) {
                            return ExpandableClassCard(
                              classModel: _classList[index],
                              onEdit: () => _addOrEditClass(existing: _classList[index], index: index),
                              onDelete: () => _deleteClass(index),
                            );
                          },
                        ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 30), // Move the FAB up
          child: FloatingActionButton(
            onPressed: () => _addOrEditClass(),
            child: const Icon(Icons.add),
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: 0, // Default to the first tab
          onTap: (index) {
            // Handle navigation here
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.task),
              label: 'To Do list',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
