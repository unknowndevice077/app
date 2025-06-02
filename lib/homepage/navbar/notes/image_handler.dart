import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

class ImageHandler {
  static Future<String?> pickAndUploadImage({
    required BuildContext context,
    required ImageSource source,
    required String noteId,
  }) async {
    try {
      // Show loading dialog

      final XFile? image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );

      if (image == null) {
        _safelyCloseDialog(context);
        return null;
      }

      final File imageFile = File(image.path);
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final String base64String = base64Encode(imageBytes);

      final String imageId = await _saveImageToFirestore(
        base64String,
        noteId,
        image.name,
        imageBytes.length,
      );

      _safelyCloseDialog(context);
      
      return imageId;
    } catch (e) {
      _safelyCloseDialog(context);
      
      _safelyShowSnackBar(context, 'Error uploading image: $e');
      return null;
    }
  }

  // Safe method to close dialog
  static void _safelyCloseDialog(BuildContext? context) {
    try {
      if (context != null && context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } catch (e) {
      // Silently catch any navigation errors
      print('Error closing dialog: $e');
    }
  }

  // Safe method to show snackbar
  static void _safelyShowSnackBar(BuildContext? context, String message) {
    try {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Silently catch any snackbar errors
      print('Error showing snackbar: $e');
    }
  }

  static Future<String> _saveImageToFirestore(
    String base64String,
    String noteId,
    String fileName,
    int fileSize,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final imageId = DateTime.now().millisecondsSinceEpoch.toString();
    
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('images')
        .doc(imageId)
        .set({
      'noteId': noteId,
      'fileName': fileName,
      'base64Data': base64String,
      'fileSize': fileSize,
      'uploadedAt': FieldValue.serverTimestamp(),
      'mimeType': 'image/jpeg',
    });

    return imageId;
  }

  static Future<Uint8List?> loadImageFromFirestore(String imageId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final imageDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('images')
          .doc(imageId)
          .get();

      if (imageDoc.exists) {
        final data = imageDoc.data() as Map<String, dynamic>;
        final base64String = data['base64Data'] as String? ?? data['base64'] as String?;
        if (base64String != null) {
          return base64Decode(base64String);
        }
      }
      return null;
    } catch (e) {
      print('Error loading image: $e');
      return null;
    }
  }
}