import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Add Firestore import
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/profile_picture_provider.dart';
import 'package:app/login/auth.dart'; // Adjust the path according to your project structure

class UserProfile extends StatefulWidget {
  const UserProfile({super.key});

  @override
  State<UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> with TickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  int _selectedAvatarIndex = 0;
  bool _isLoading = false;
  bool _isEditMode = false;
  bool _showAvatarSelector = false;
  String? _selectedProfilePicture;

  // ✅ Updated avatar options
  final List<Map<String, dynamic>> _avatarOptions = [
    {'path': 'assets/images/avatars/1.jpg', 'name': 'Avatar 1'},
    {'path': 'assets/images/avatars/2.jpg', 'name': 'Avatar 2'},
    {'path': 'assets/images/avatars/3.jpg', 'name': 'Avatar 3'},
    {'path': 'assets/images/avatars/4.jpg', 'name': 'Avatar 4'},
    {'path': 'assets/images/avatars/5.jpg', 'name': 'Avatar 5'},
    {'path': 'assets/images/avatars/6.jpg', 'name': 'Avatar 6'},
    {'path': 'assets/images/avatars/7.jpg', 'name': 'Avatar 7'},
    {'path': 'assets/images/avatars/8.jpg', 'name': 'Avatar 8'},
    {'path': 'assets/images/avatars/9.jpg', 'name': 'Avatar 9'},
    {'path': 'assets/images/avatars/10.jpg', 'name': 'Avatar 10'},
    {'path': 'assets/images/avatars/11.jpg', 'name': 'Avatar 11'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ✅ Load user data from Firestore and SharedPreferences
  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && mounted) {
      setState(() {
        _emailController.text = user.email ?? '';
      });

      try {
        // ✅ Try to load from Firestore first
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists && mounted) {
          final data = doc.data()!;
          setState(() {
            _usernameController.text = data['username'] ?? user.email?.split('@').first ?? '';
            _phoneController.text = data['phone'] ?? '';
            _selectedAvatarIndex = data['avatarIndex'] ?? 0;
          });

          // ✅ Also save to SharedPreferences for offline access
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('username_${user.uid}', _usernameController.text);
          await prefs.setString('phone_${user.uid}', _phoneController.text);
          await prefs.setInt('avatarIndex_${user.uid}', _selectedAvatarIndex);
        } else {
          // ✅ Fallback to SharedPreferences if Firestore data doesn't exist
          final prefs = await SharedPreferences.getInstance();
          if (mounted) {
            setState(() {
              _usernameController.text = prefs.getString('username_${user.uid}') ?? user.email?.split('@').first ?? '';
              _phoneController.text = prefs.getString('phone_${user.uid}') ?? '';
              _selectedAvatarIndex = prefs.getInt('avatarIndex_${user.uid}') ?? 0;
            });
          }
        }
      } catch (e) {
        if (kDebugMode) print('Error loading user data: $e');
        // ✅ Fallback to SharedPreferences on error
        try {
          final prefs = await SharedPreferences.getInstance();
          if (mounted) {
            setState(() {
              _usernameController.text = prefs.getString('username_${user.uid}') ?? user.email?.split('@').first ?? '';
              _phoneController.text = prefs.getString('phone_${user.uid}') ?? '';
              _selectedAvatarIndex = prefs.getInt('avatarIndex_${user.uid}') ?? 0;
            });
          }
        } catch (e) {
          if (kDebugMode) print('Error loading from SharedPreferences: $e');
        }
      }
    }
  }

  // ✅ Save profile to both Firestore and SharedPreferences
  Future<void> _saveProfile() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final userId = user.uid;
      
      // ✅ Prepare user data
      final userData = {
        'username': _usernameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'avatarIndex': _selectedAvatarIndex,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      // ✅ Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set(userData, SetOptions(merge: true));

      // ✅ Also save to SharedPreferences for offline access
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username_$userId', _usernameController.text.trim());
      await prefs.setString('phone_$userId', _phoneController.text.trim());
      await prefs.setString('email_$userId', _emailController.text.trim());
      await prefs.setInt('avatarIndex_$userId', _selectedAvatarIndex);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isEditMode = false;
          _showAvatarSelector = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile saved successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

 

  // ✅ Updated avatar selector without bottom spacing
  Widget _buildAvatarSelector() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: _showAvatarSelector ? 320 : 0, // Increased height for bigger container
      child: _showAvatarSelector
          ? Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24), // Slightly larger corners
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.05),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.face,
                          color: const Color(0xFF3B82F6),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Choose Your Avatar',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showAvatarSelector = false;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // ✅ Scrollable avatar grid
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(), // ✅ Always scrollable
                        child: Column(
                          children: [
                            // ✅ Grid with proper spacing and scrolling
                            GridView.builder(
                              shrinkWrap: true, // ✅ Important for nested scroll
                              physics: const NeverScrollableScrollPhysics(), // ✅ Let parent handle scrolling
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4, // ✅ Better spacing with 4 columns
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.0,
                              ),
                              itemCount: _avatarOptions.length,
                              itemBuilder: (context, index) {
                                final isSelected = _selectedAvatarIndex == index;
                                return _buildAvatarOption(index, isSelected);
                              },
                            ),
                            
                            // ✅ Add some bottom padding for better scrolling
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ) : const SizedBox(),
    );
  }

  // ✅ Separate method for building avatar options
  Widget _buildAvatarOption(int index, bool isSelected) {
    return GestureDetector(
      onTap: () async {
        setState(() {
          _selectedAvatarIndex = index;
          _showAvatarSelector = false;
        });

        // ✅ Update the profile picture provider as well!
        final profileProvider = Provider.of<ProfilePictureProvider>(context, listen: false);
        await profileProvider.setProfilePicture(_avatarOptions[index]['path']);

        // Optional: Haptic feedback
        HapticFeedback.lightImpact();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : Colors.grey[300]!,
            width: isSelected ? 3 : 2,
          ),
          boxShadow: [
            if (isSelected) ...[
              BoxShadow(
                color: const Color(0xFF3B82F6).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ] else ...[
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ]
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? const Color(0xFF3B82F6).withOpacity(0.1) : Colors.transparent,
        ),
        child: CircleAvatar(
          radius: 28, // ✅ Good size for 4-column grid
          backgroundColor: Colors.grey[200],
          backgroundImage: AssetImage(_avatarOptions[index]['path']),
          onBackgroundImageError: (error, stackTrace) {
            if (kDebugMode) print('Avatar image error: $error');
          },
          child: isSelected 
            ? Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF3B82F6).withOpacity(0.2),
                ),
                child: const Icon(
                  Icons.check,
                  color: Color(0xFF3B82F6),
                  size: 20,
                ),
              )
            : null,
        ),
      ),
    ));
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required bool enabled,
    TextInputType? keyboardType,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF3B82F6),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    enabled: enabled,
                    keyboardType: keyboardType,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: enabled ? Colors.black : Colors.grey[600],
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Enter $label',
                      hintStyle: GoogleFonts.inter(
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add this method to select profile picture
  void _selectProfilePicture(String imagePath) async {
    try {
      // ✅ Use provider to set profile picture
      final profileProvider = Provider.of<ProfilePictureProvider>(context, listen: false);
      await profileProvider.setProfilePicture(imagePath);
      
      setState(() {
        _selectedProfilePicture = imagePath;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profile picture updated!',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile picture'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  // Add this method to handle sign out with confirmation:
  Future<void> _showSignOutConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.logout,
                color: Colors.red[600],
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Sign Out',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to sign out of your account?',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                'Sign Out',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _performSignOut();
    }
  }

  // Add this method to perform the actual sign out:
  Future<void> _performSignOut() async {
    try {
      // Clear any cached data if needed
      final prefs = await SharedPreferences.getInstance();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Clear user-specific cache
        await prefs.remove('username_${user.uid}');
        await prefs.remove('phone_${user.uid}');
        await prefs.remove('email_${user.uid}');
        await prefs.remove('avatarIndex_${user.uid}');
      }

      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();

      // Clear profile picture provider
      final profileProvider = Provider.of<ProfilePictureProvider>(context, listen: false);
      await profileProvider.clearProfilePicture();

      // ✅ Navigate directly to Auth screen and clear navigation stack
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const Auth(), // Redirect to Auth widget
          ),
          (route) => false, // Clear all previous routes
        );
      }

    } catch (e) {
      // Show simple error snackbar instead of dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Failed to sign out. Please try again.',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _performSignOut,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('_isEditMode: $_isEditMode');
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // ✅ Blue Header Section
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF3B82F6),
                      const Color(0xFF1E40AF),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      children: [
                        // Header with back button and edit button
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                              const Spacer(),
                              Text(
                                'Profile',
                                style: GoogleFonts.inter(
                                  fontSize: isTablet ? 24 : 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: Icon(
                                  _isEditMode ? Icons.check : Icons.edit,
                                  color: Colors.white,
                                ),
                                onPressed: _isEditMode
                                    ? _saveProfile
                                    : () {
                                        setState(() {
                                          _isEditMode = true;
                                          _showAvatarSelector = false;
                                        });
                                      },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Profile Picture with small edit icon "mounted" at the bottom right
                        GestureDetector(
                          onTap: _isEditMode
                              ? () {
                                  setState(() {
                                    _showAvatarSelector = !_showAvatarSelector;
                                  });
                                }
                              : null,
                          child: SizedBox(
                            width: 140,
                            height: 140,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Align(
                                  alignment: Alignment.center,
                                  child: SizedBox(
                                    width: 120,
                                    height: 120,
                                    child: Consumer<ProfilePictureProvider>(
                                      builder: (context, profileProvider, child) {
                                        return ClipOval(
                                          child: profileProvider.profilePictureWidget ??
                                              CircleAvatar(
                                                radius: 60,
                                                backgroundColor: Colors.white.withOpacity(0.2),
                                                child: Icon(
                                                  Icons.person,
                                                  size: 48,
                                                  color: Colors.white.withOpacity(0.8),
                                                ),
                                              ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                // --- Small edit icon "mounted" at the bottom right of the profile picture ---
                                if (_isEditMode)
                                  Positioned(
                                    bottom: 8,
                                    right: 15,
                                    child: Container(
                                      width: 32, // Adjust this for the circle size
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.08),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.edit, color: Color(0xFF3B82F6), size: 18),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () {
                                          setState(() {
                                            _showAvatarSelector = !_showAvatarSelector;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                // --- End edit icon ---
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Username
                        Text(
                          _usernameController.text.isNotEmpty 
                              ? _usernameController.text 
                              : 'Your Name',
                          style: GoogleFonts.inter(
                            fontSize: isTablet ? 24 : 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _emailController.text,
                          style: GoogleFonts.inter(
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ✅ Avatar Selector (compact design)
              _buildAvatarSelector(),

              // ✅ White Content Section
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                ),
                child: Padding(
                  padding: EdgeInsets.all(isTablet ? 32 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Personal Information',
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 24 : 20,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Username Field
                      _buildInfoCard(
                        icon: Icons.person_outline,
                        label: 'Username',
                        controller: _usernameController,
                        enabled: _isEditMode,
                      ),

                      // Email Field (Read-only)
                      _buildInfoCard(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        controller: _emailController,
                        enabled: false,
                        keyboardType: TextInputType.emailAddress,
                      ),

                      // Phone Field
                      _buildInfoCard(
                        icon: Icons.phone_outlined,
                        label: 'Phone Number',
                        controller: _phoneController,
                        enabled: _isEditMode,
                        keyboardType: TextInputType.phone,
                      ),

                      const SizedBox(height: 32),

                      // Info Card about Cloud Storage
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.cloud_done_outlined, color: Colors.green[600], size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Your profile data is safely stored in the cloud and synced across devices',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.green[800],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Action Buttons
                      if (_isEditMode) ...[
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _isEditMode = false;
                                    _showAvatarSelector = false;
                                  });
                                  _loadUserData();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[300],
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'Cancel',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _saveProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B82F6),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        'Save Changes',
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // ✅ Sign Out Button Section (always visible at bottom)
                      const SizedBox(height: 32),
                      
                      // Divider
                      Container(
                        height: 1,
                        color: Colors.grey[200],
                        margin: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      
                      // Sign Out Button
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.red[200]!),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: _showSignOutConfirmation,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red[50],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.logout,
                                      color: Colors.red[600],
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Sign Out',
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.red[700],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'You will be signed out of your account',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            color: Colors.red[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: Colors.red[400],
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // Bottom spacing
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}