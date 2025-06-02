import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'note_models.dart';

class NoteDataManager {
  Future<bool> saveNote({
    required NoteData noteData,
    String? docId,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final firestoreData = noteData.toFirestore();
      firestoreData['updatedAt'] = FieldValue.serverTimestamp();
      firestoreData['userId'] = user.uid;

      if (docId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('Notes')
            .doc(docId)
            .set(firestoreData, SetOptions(merge: true));
      } else {
        firestoreData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('Notes')
            .add(firestoreData);
      }

      return true;
    } catch (e) {
      print('Error saving note: $e');
      return false;
    }
  }

  Future<NoteData?> loadExistingData(String docId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('Notes')
          .doc(docId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          return NoteData.fromFirestore(data);
        }
      }
      return null;
    } catch (e) {
      print('Error loading existing data: $e');
      return null;
    }
  }

  Future<bool> deleteNote(String docId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('Notes')
          .doc(docId)
          .delete();

      return true;
    } catch (e) {
      print('Error deleting note: $e');
      return false;
    }
  }

  Stream<QuerySnapshot> getNotesStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('Notes')
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }
}