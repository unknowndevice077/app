import 'package:app/home%20page/navbar/classes.dart';
import 'package:app/home%20page/navbar/notes.dart';
import 'package:app/home%20page/navbar/calendar.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;



  
  @override
  Widget build(BuildContext context) {
    Widget bodyContent;
    PreferredSizeWidget? appBar;

    if (_selectedIndex == 0) {
      // Home tab
      appBar = AppBar(
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
      );
      bodyContent = Center(
        child: Text(
          'Home Content Here',
          style: TextStyle(fontSize: 24, color: Colors.black),
        ),
      );
    } else if (_selectedIndex == 1) {
      // Notes tab
      appBar = null; // Notes widget has its own AppBar
      bodyContent = Notes();
    } else if (_selectedIndex == 2) {

      bodyContent = const Calendar();
    } else {
      bodyContent = const Classes();
    }

    return Scaffold(
      backgroundColor: Colors.white, // <-- Set background color to white
      appBar: appBar,
      body: bodyContent,
      endDrawer: Drawer(
        child: Container(
          color: Colors.white, // <-- Set drawer background to white
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  color: Colors.white, // <-- Set drawer header background to white
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: AssetImage(
                        'lib/images/Finn The Human.jpg',
                      ),
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
      floatingActionButton:
          _selectedIndex == 0
              ? Padding(
                padding: const EdgeInsets.only(bottom: 50),
                child: FloatingActionButton(
                  onPressed: () {
                    // Implement your add class logic here
                  },
                  child: const Icon(Icons.add),
                ),
              )
              : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home, size: 22),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.note, size: 22),
            label: 'Notes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today, size: 22),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.class_, size: 22),
            label: 'Classes',
          ),
        ],
      ),
    );
  }
}
