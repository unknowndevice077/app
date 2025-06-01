import 'navbar/classes.dart';
import 'navbar/notes/notes.dart';
import 'navbar/events.dart';
import 'navbar/homecontent.dart';
// TODO: Update the import path below to the correct location of study.dart, or create the file if it doesn't exist.
import 'package:app/homepage/navbar/Study/study.dart';
import 'navbar/userprofile.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/profile_picture_provider.dart';
import 'package:app/providers/theme_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  int _userAvatarIndex = 0;
  String _customUsername = '';
  bool _isEditingNote = false;

  late PageController _pageController;
  List<AnimationController> _pageAnimationControllers = [];
  List<Animation<double>> _pageAnimations = [];
  bool _animationsInitialized = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _initializeAnimations();
    _loadUserData();
  }

  void _initializeAnimations() {
    try {
      _pageAnimationControllers = List.generate(
        5,
        (index) => AnimationController(
          duration: const Duration(milliseconds: 600),
          vsync: this,
        ),
      );
      _pageAnimations = _pageAnimationControllers.map((controller) {
        return Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOut,
        ));
      }).toList();
      _animationsInitialized = true;
      _pageAnimationControllers[0].forward();
    } catch (e) {
      print('Error initializing animations: $e');
    }
  }

  @override
  void dispose() {
    try {
      for (var controller in _pageAnimationControllers) {
        controller.dispose();
      }
      _pageController.dispose();
    } catch (e) {
      print('Error disposing animations: $e');
    }
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userUID = FirebaseAuth.instance.currentUser?.uid;

    if (userUID != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userUID)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              _userAvatarIndex = userData['avatarIndex'] ?? 0;
              _customUsername = userData['username'] ?? '';
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _userAvatarIndex = prefs.getInt('user_avatar_index') ?? 0;
            _customUsername = prefs.getString('custom_username') ?? '';
          });
        }
      }
    }
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex || !_animationsInitialized) return;

    setState(() {
      if (_selectedIndex < _pageAnimationControllers.length) {
        _pageAnimationControllers[_selectedIndex].reset();
      }
      _selectedIndex = index;
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _selectedIndex < _pageAnimationControllers.length) {
          _pageAnimationControllers[_selectedIndex].forward();
        }
      });
    });

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Widget _getAnimatedPage(int index, Widget page) {
    if (!_animationsInitialized || index >= _pageAnimations.length) {
      return page;
    }
    return FadeTransition(
      opacity: _pageAnimations[index],
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _pageAnimationControllers[index],
          curve: Curves.easeOutCubic,
        )),
        child: page,
      ),
    );
  }

  Widget _buildHomePage(ThemeProvider themeProvider) {
    return _getAnimatedPage(
      0,
      Homecontent(
        username: _customUsername.isNotEmpty ? _customUsername : null,
      ),
    );
  }

  Widget _buildNotesPage(ThemeProvider themeProvider) {
    return _getAnimatedPage(
      1,
      NotesScreen(
        onNoteEditingChanged: (isEditing) {
          setState(() {
            _isEditingNote = isEditing;
          });
          print('📝 Note editing changed: $isEditing');
        },
      ),
    );
  }

  Widget _buildStudyPage(ThemeProvider themeProvider) {
    return _getAnimatedPage(2, const Study());
  }

  Widget _buildEventsPage(ThemeProvider themeProvider) {
    return _getAnimatedPage(3, const Events());
  }

  Widget _buildClassesPage(ThemeProvider themeProvider) {
    return _getAnimatedPage(4, const Classes());
  }

  Widget _buildBottomNavbar(ThemeProvider themeProvider) {
    final isDark = themeProvider.isDarkMode;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2C3E50)
            : Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(Icons.home, 'Home', 0, themeProvider),
          _buildNavItem(Icons.note, 'Notes', 1, themeProvider),
          _buildNavItem(Icons.school, 'Study', 2, themeProvider),
          _buildNavItem(Icons.event, 'Events', 3, themeProvider),
          _buildNavItem(Icons.class_, 'Classes', 4, themeProvider),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, ThemeProvider themeProvider) {
    final isSelected = _selectedIndex == index;
    final isDark = themeProvider.isDarkMode;
    final primaryColor = Colors.blue;
    final inactiveColor = isDark
        ? Colors.white.withOpacity(0.6)
        : Colors.grey[600]!;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? primaryColor : inactiveColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? primaryColor : inactiveColor,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(ThemeProvider themeProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';
    final username = _customUsername.isNotEmpty
        ? _customUsername
        : (email.contains('@') ? email.split('@')[0] : email);

    return Drawer(
      backgroundColor: isDark ? Colors.black : Colors.white,
      child: Column(
        children: [
          // Drawer Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: isDark ? Colors.black : Colors.white,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserProfile(),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark 
                              ? Colors.white.withOpacity(0.3)
                              : Colors.grey.withOpacity(0.3),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Consumer<ProfilePictureProvider>(
                        builder: (context, profileProvider, child) {
                          return profileProvider.getProfilePictureWidget(
                            radius: 35,
                            showEditIcon: false,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Username or trimmed email
                  Text(
                    username,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Always show full email below
                  Text(
                    email,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Drawer Items (only Profile remains)
          Expanded(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.person,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  title: Text(
                    'Profile',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UserProfile(),
                      ),
                    );
                  },
                ),
                
                // Add more menu items here if needed in the future
                // ListTile(
                //   leading: Icon(Icons.settings),
                //   title: Text('Settings'),
                //   onTap: () {},
                // ),
              ],
            ),
          ),
          
          // Add some bottom padding for better spacing
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 18) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        return Scaffold(
          backgroundColor: isDark ? Colors.black : Colors.white,
          endDrawer: _buildDrawer(themeProvider),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        if (_selectedIndex < _pageAnimationControllers.length) {
                          _pageAnimationControllers[_selectedIndex].reset();
                        }
                        _selectedIndex = index;
                        if (_selectedIndex < _pageAnimationControllers.length) {
                          _isEditingNote = false;
                          _pageAnimationControllers[_selectedIndex].forward();
                        }
                      });
                    },
                    children: [
                      _buildHomePage(themeProvider),
                      _buildNotesPage(themeProvider),
                      _buildStudyPage(themeProvider),
                      _buildEventsPage(themeProvider),
                      _buildClassesPage(themeProvider),
                    ],
                  ),
                ),
                if (!_isEditingNote)
                  _buildBottomNavbar(themeProvider),
              ],
            ),
          ),
        );
      },
    );
  }
}