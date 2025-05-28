import 'navbar/classes.dart';
import 'navbar/notes/notes.dart';
import 'navbar/Events.dart'; 
import 'navbar/homecontent.dart';
import 'navbar/Study/study.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

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

    // AppBar with menu icon always shown (except for Notes tab)
    appBar = AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: const Text(''),
      actions: [
        Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            tooltip: 'Open Menu',
            onPressed: () {
              Scaffold.of(context).openEndDrawer();
            },
          ),
        ),
      ],
    );

    if (_selectedIndex == 0) {
      bodyContent = const Homecontent();
    } else if (_selectedIndex == 1) {
      appBar = null; // Notes has its own AppBar
      bodyContent = const Notes();
    } else if (_selectedIndex == 2) {
      appBar = null;
      bodyContent = const Study();
    } else if (_selectedIndex == 3) {
      appBar = null;
      bodyContent = const Events();
    } else if (_selectedIndex == 4) {
      appBar = null;
      bodyContent = const Classes();
    } else {
      appBar = null;
      bodyContent = const Study();
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
              SizedBox(height: 500),
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
                    await FirebaseAuth.instance.signOut();
                    // ✅ Check mounted before navigation
                    if (mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/login', 
                        (route) => false, // Remove all previous routes
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        height: 90,
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
            padding: const EdgeInsets.only(top: 10),
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
                  icon: Icon(CupertinoIcons.book, size: 24),
                  label: 'Study',
                ),
                BottomNavigationBarItem(
                  icon: Icon(CupertinoIcons.calendar, size: 24),
                  label: 'Events',
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
