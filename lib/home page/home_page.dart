import 'package:app/home%20page/navbar/classes.dart';
import 'package:app/home%20page/navbar/notes.dart';
import 'package:app/home%20page/navbar/Events.dart';
import 'package:app/home%20page/navbar/homecontent.dart'; // <-- Add this import
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:app/home%20page/navbar/Study/study.dart'; // <-- Add this import
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
      bodyContent = const Homecontent(); // <-- Show Homecontent here
    } else if (_selectedIndex == 1) {
      // Notes tab
      appBar = null; // Notes widget has its own AppBar
      bodyContent = Notes();
    } else if (_selectedIndex == 2) {
      bodyContent = const Study(); // Study is now center
    } else if (_selectedIndex == 3) {
      bodyContent = const Events();
    } else if (_selectedIndex == 4) {
      bodyContent = const Classes();
    } else {
      bodyContent = const Study(); // <-- Add this line for Study tab
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: appBar,
      body: bodyContent,
      endDrawer: Drawer(
        child: Container(
          color: Colors.white,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  color: Colors.white,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundImage: AssetImage('lib/images/Finn The Human.jpg'),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hi, Jae',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            FirebaseAuth.instance.currentUser?.email ?? '',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.home_outlined, color: Colors.black),
                title: const Text(
                  'Home',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined, color: Colors.black),
                title: const Text(
                  'Settings',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  // Navigate to settings page
                },
              ),
              const Divider(height: 32, thickness: 1.2, indent: 18, endIndent: 18),
              SizedBox(height: 500), // Adjust this value as needed for your layout
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.black),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
                ),
                onTap: () async {
                  final shouldLogout = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      title: const Text('Logout Confirmation'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );
                  if (shouldLogout == true) {
                    FirebaseAuth.instance.signOut();
                    Navigator.pop(context);
                  }
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        height: 90, // Navbar container height
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 10), // <-- Lower the icons
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              selectedItemColor: Colors.black,
              unselectedItemColor: Colors.grey[400],
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
              elevation: 0,
              showUnselectedLabels: true,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.home, size: 24),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.doc_text, size: 24),
                  label: 'Notes',
                ),
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.book, size: 24), // Study is now center
                  label: 'Study',
                ),
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.calendar, size: 24),
                  label: 'Events', // <-- Changed from 'Calendar' to 'Events'
                ),
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.collections, size: 24),
                  label: 'Classes',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
