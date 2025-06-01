import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePictureProvider extends ChangeNotifier {
  String? _selectedProfilePicture;
  Widget? _profilePictureWidget;
  File? _profilePictureFile; // ✅ Add File support

  String? get selectedProfilePicture => _selectedProfilePicture;
  Widget? get profilePictureWidget => _profilePictureWidget;
  File? get profilePicture => _profilePictureFile; // ✅ Add File getter

  // ✅ Initialize and load saved profile picture
  Future<void> loadProfilePicture() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _selectedProfilePicture = prefs.getString('selected_profile_picture');
      
      if (_selectedProfilePicture != null) {
        // Check if it's a file path or asset path
        if (_selectedProfilePicture!.startsWith('/') || _selectedProfilePicture!.contains('\\')) {
          // It's a file path
          _profilePictureFile = File(_selectedProfilePicture!);
          if (await _profilePictureFile!.exists()) {
            _profilePictureWidget = _buildProfileWidgetFromFile(_profilePictureFile!);
          } else {
            // File doesn't exist, clear it
            _clearProfilePicture();
          }
        } else {
          // It's an asset path
          _profilePictureWidget = _buildProfileWidgetFromAsset(_selectedProfilePicture!);
        }
        notifyListeners();
      }
    } catch (e) {
      print('Error loading profile picture: $e');
    }
  }

  // ✅ Set profile picture from file (camera/gallery)
  Future<void> setProfilePictureFromFile(File imageFile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_profile_picture', imageFile.path);
      
      _selectedProfilePicture = imageFile.path;
      _profilePictureFile = imageFile;
      _profilePictureWidget = _buildProfileWidgetFromFile(imageFile);
      notifyListeners();
    } catch (e) {
      print('Error setting profile picture from file: $e');
    }
  }

  // ✅ Set profile picture from asset
  Future<void> setProfilePictureFromAsset(String assetPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_profile_picture', assetPath);
      
      _selectedProfilePicture = assetPath;
      _profilePictureFile = null; // Clear file when using asset
      _profilePictureWidget = _buildProfileWidgetFromAsset(assetPath);
      notifyListeners();
    } catch (e) {
      print('Error setting profile picture from asset: $e');
    }
  }

  // ✅ Legacy method for backward compatibility
  Future<void> setProfilePicture(String profilePicturePath) async {
    // Determine if it's a file path or asset path
    if (profilePicturePath.startsWith('/') || profilePicturePath.contains('\\')) {
      await setProfilePictureFromFile(File(profilePicturePath));
    } else {
      await setProfilePictureFromAsset(profilePicturePath);
    }
  }

  // ✅ Pick image from camera or gallery
  Future<void> pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      
      if (image != null) {
        await setProfilePictureFromFile(File(image.path));
      }
    } catch (e) {
      print('Error picking image from gallery: $e');
    }
  }

  Future<void> pickImageFromCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      
      if (image != null) {
        await setProfilePictureFromFile(File(image.path));
      }
    } catch (e) {
      print('Error picking image from camera: $e');
    }
  }

  // ✅ Clear profile picture
  Future<void> clearProfilePicture() async {
    await _clearProfilePicture();
    notifyListeners();
  }

  Future<void> _clearProfilePicture() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('selected_profile_picture');
      
      _selectedProfilePicture = null;
      _profilePictureFile = null;
      _profilePictureWidget = null;
    } catch (e) {
      print('Error clearing profile picture: $e');
    }
  }

  // ✅ Build profile widget from File
  Widget _buildProfileWidgetFromFile(File imageFile) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.grey[100],
      backgroundImage: FileImage(imageFile),
      onBackgroundImageError: (exception, stackTrace) {
        print('Error loading profile image file: $exception');
      },
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Build profile widget from Asset
  Widget _buildProfileWidgetFromAsset(String assetPath) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.grey[100],
      backgroundImage: AssetImage(assetPath),
      onBackgroundImageError: (exception, stackTrace) {
        print('Error loading profile image asset: $exception');
      },
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Get profile picture widget with custom options
  Widget getProfilePictureWidget({
    double radius = 30,
    bool showEditIcon = false,
    VoidCallback? onEditTap,
  }) {
    Widget profileWidget;
    
    if (_profilePictureFile != null) {
      // Use File image
      profileWidget = CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[100],
        backgroundImage: FileImage(_profilePictureFile!),
        onBackgroundImageError: (exception, stackTrace) {
          print('Error loading profile image: $exception');
        },
      );
    } else if (_selectedProfilePicture != null) {
      // Use Asset image
      profileWidget = CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[100],
        backgroundImage: AssetImage(_selectedProfilePicture!),
        onBackgroundImageError: (exception, stackTrace) {
          print('Error loading profile image: $exception');
        },
      );
    } else {
      // Default placeholder
      profileWidget = CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[300],
        child: Icon(Icons.person, size: radius * 0.8, color: Colors.grey[600]),
      );
    }

    if (showEditIcon) {
      return GestureDetector(
        onTap: onEditTap,
        child: Stack(
          children: [
            profileWidget,
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: radius * 0.6,
                height: radius * 0.6,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  Icons.edit,
                  color: Colors.white,
                  size: radius * 0.3,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return profileWidget;
  }

  // ✅ Check if user has a profile picture
  bool get hasProfilePicture => _profilePictureFile != null || _selectedProfilePicture != null;
}