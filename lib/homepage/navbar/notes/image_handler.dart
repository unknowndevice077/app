import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ImageHandler {
  static final ImagePicker _picker = ImagePicker();

  // ✅ Pick and upload image for notes
  static Future<String?> pickAndUploadImage({
    required BuildContext context,
    ImageSource source = ImageSource.gallery,
    String? noteId,
  }) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Pick image
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image == null) {
        Navigator.of(context).pop(); // Close loading
        return null;
      }

      // Convert to base64
      final File imageFile = File(image.path);
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final String base64String = base64Encode(imageBytes);

      // Save to Firestore
      final String imageId = await _saveImageToFirestore(base64String, noteId);

      Navigator.of(context).pop(); // Close loading
      return imageId;

    } catch (e) {
      Navigator.of(context).pop(); // Close loading
      print('Error picking/uploading image: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading image: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  // ✅ Save image to Firestore
  static Future<String> _saveImageToFirestore(String base64String, String? noteId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final imageDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('images')
        .doc();

    await imageDoc.set({
      'base64Data': base64String,
      'noteId': noteId,
      'uploadedAt': FieldValue.serverTimestamp(),
      'uploadedBy': user.uid,
      'fileSize': base64String.length,
    });

    return imageDoc.id;
  }

  // ✅ Load image from Firestore
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
        final base64String = data['base64Data'] as String;
        return base64Decode(base64String);
      }
      return null;
    } catch (e) {
      print('Error loading image: $e');
      return null;
    }
  }

  // ✅ Delete image from Firestore
  static Future<void> deleteImageFromFirestore(String imageId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('images')
          .doc(imageId)
          .delete();
    } catch (e) {
      print('Error deleting image: $e');
    }
  }

  // ✅ Get all images for a note
  static Future<List<Map<String, dynamic>>> getImagesForNote(String noteId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('images')
          .where('noteId', isEqualTo: noteId)
          .orderBy('uploadedAt', descending: false)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting images for note: $e');
      return [];
    }
  }
}