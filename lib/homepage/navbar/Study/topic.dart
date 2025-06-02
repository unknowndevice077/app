import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:app/homepage/navbar/Study/classtimer.dart';

class TopicScreen extends StatefulWidget {
  final String classId;
  final Map<String, dynamic> classData;
  final Color classColor;
  final String classTitle;

  const TopicScreen({
    super.key,
    required this.classId,
    required this.classData,
    required this.classColor,
    required this.classTitle,
  });

  @override
  State<TopicScreen> createState() => _TopicScreenState();
}

class _TopicScreenState extends State<TopicScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isLoading = false;
  bool _isEditMode = false; // Add this line

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _showAddTopicDialog() async {
    final isTablet = MediaQuery.of(context).size.width > 600;
    String topicTitle = '';
    String topicDescription = '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Title
            Text(
              'New Topic',
              style: GoogleFonts.inter(
                fontSize: isTablet ? 28 : 24,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a new topic to organize your study materials',
              style: GoogleFonts.inter(
                fontSize: isTablet ? 16 : 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),

            // Topic title field
            TextField(
              onChanged: (value) => topicTitle = value,
              style: GoogleFonts.inter(fontSize: isTablet ? 16 : 14),
              decoration: InputDecoration(
                labelText: 'Topic Title',
                hintText: 'Enter topic name',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: widget.classColor, width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 20 : 16,
                  vertical: isTablet ? 20 : 16,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Description field
            TextField(
              onChanged: (value) => topicDescription = value,
              maxLines: 3,
              style: GoogleFonts.inter(fontSize: isTablet ? 16 : 14),
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Brief description of the topic',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: widget.classColor, width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 20 : 16,
                  vertical: isTablet ? 20 : 16,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (topicTitle.trim().isNotEmpty) {
                        await _addTopic(topicTitle.trim(), topicDescription.trim());
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.classColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Create Topic',
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addTopic(String title, String description) async {
    try {
      setState(() => _isLoading = true);
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('Classes')
          .doc(widget.classId)
          .collection('topics')
          .add({
        'title': title,
        'description': description,
        'createdAt': FieldValue.serverTimestamp(),
        'fileCount': 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('Topic created successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('Error creating topic'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _startStudySession() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ClassTimer(
          classId: widget.classId,
          topicId: '', // You can pass a specific topicId if needed
          topicTitle: widget.classTitle, // Pass the class title
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: animation.drive(
              Tween(begin: const Offset(1.0, 0.0), end: Offset.zero).chain(
                CurveTween(curve: Curves.easeOutCubic),
              ),
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  // Add this method to toggle edit mode
  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
    });
  }

  // Add this method to delete a topic
  Future<void> _deleteTopic(String topicId, String topicTitle) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete Topic'),
          content: Text('Are you sure you want to delete "$topicTitle"?\n\nThis will also delete all files in this topic.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        print('=== DELETING TOPIC: $topicId ===');

        // First, delete all files in this topic
        final filesSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('Classes')
            .doc(widget.classId)
            .collection('topics')
            .doc(topicId)
            .collection('files')
            .get();

        print('Found ${filesSnapshot.docs.length} files to delete');

        // Delete all file documents
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in filesSnapshot.docs) {
          print('Deleting file: ${doc.id}');
          batch.delete(doc.reference);
        }

        // Delete the topic document itself
        final topicRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('Classes')
            .doc(widget.classId)
            .collection('topics')
            .doc(topicId);
      
        print('Deleting topic document: $topicId');
        batch.delete(topicRef);

        await batch.commit();
        print('Batch delete completed');

        // Run cleanup to remove any orphaned documents
        print('Running cleanup after deletion...');
        await _cleanupInvalidDocuments();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Text('Topic deleted successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      print('Error deleting topic: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Error deleting topic: $e'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  // Add this method to _TopicScreenState class
  Future<void> _cleanupInvalidDocuments() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No user found for cleanup');
        return;
      }

      print('Starting cleanup for class: ${widget.classId}');

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('Classes')
          .doc(widget.classId)
          .collection('topics')
          .get();

      print('Found ${snapshot.docs.length} total documents in topics collection');

      final batch = FirebaseFirestore.instance.batch();
      int deleteCount = 0;
      int validTopicCount = 0;
      List<Map<String, dynamic>> analysis = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        
        // Detailed analysis of each document
        bool hasTitle = data.containsKey('title') && data['title'] != null && data['title'].toString().trim().isNotEmpty;
        bool hasCreatedAt = data.containsKey('createdAt');
        bool hasFileName = data.containsKey('fileName');
        bool hasName = data.containsKey('name');
        bool hasPath = data.containsKey('path');
        bool hasAddedAt = data.containsKey('addedAt');
        
        bool isValidTopic = hasTitle && hasCreatedAt && !hasFileName && !hasPath && !hasAddedAt;
        
        analysis.add({
          'docId': doc.id,
          'data': data,
          'hasTitle': hasTitle,
          'hasCreatedAt': hasCreatedAt,
          'hasFileName': hasFileName,
          'hasName': hasName,
          'hasPath': hasPath,
          'hasAddedAt': hasAddedAt,
          'isValidTopic': isValidTopic,
        });
        
        if (isValidTopic) {
          validTopicCount++;
          print('✅ Valid topic: ${doc.id} - "${data['title']}"');
        } else {
          print('❌ Invalid document: ${doc.id}');
          print('   Data: $data');
          print('   Reason: ${!hasTitle ? 'No title' : !hasCreatedAt ? 'No createdAt' : hasFileName ? 'Has fileName' : hasPath ? 'Has path' : 'Has addedAt'}');
          
          batch.delete(doc.reference);
          deleteCount++;
        }
      }

      print('=== CLEANUP SUMMARY ===');
      print('Total documents: ${snapshot.docs.length}');
      print('Valid topics: $validTopicCount');
      print('Invalid documents to delete: $deleteCount');

      if (deleteCount > 0) {
        await batch.commit();
        print('✅ Successfully deleted $deleteCount invalid documents');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cleaned up $deleteCount invalid documents'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        print('✅ No invalid documents found');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Database is clean - no invalid documents found'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error during cleanup: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during cleanup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            // Updated app bar with edit button
            SliverAppBar(
              expandedHeight: isTablet ? 200 : 160,
              floating: false,
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                // Add edit button here
                IconButton(
                  onPressed: _toggleEditMode,
                  icon: Icon(
                    _isEditMode ? Icons.done : Icons.edit,
                    color: _isEditMode ? Colors.green : Colors.grey[600],
                  ),
                ),
                SizedBox(width: 8),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  color: Colors.white,
                  padding: EdgeInsets.fromLTRB(
                    isTablet ? 24 : 20,
                    isTablet ? 100 : 80,
                    isTablet ? 24 : 20,
                    isTablet ? 32 : 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        widget.classTitle,
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 32 : 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: widget.classColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.classData['teacher'] ?? 'No teacher',
                            style: GoogleFonts.inter(
                              fontSize: isTablet ? 16 : 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.classData['time'] ?? 'No time',
                            style: GoogleFonts.inter(
                              fontSize: isTablet ? 16 : 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Action buttons section
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                isTablet ? 24 : 20,
                isTablet ? 32 : 24,
                isTablet ? 24 : 20,
                0,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Show edit mode banner when in edit mode
                  if (_isEditMode) ...[
                    Container(
                      padding: EdgeInsets.all(isTablet ? 20 : 16),
                      margin: EdgeInsets.only(bottom: isTablet ? 20 : 16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red[100]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Delete Mode - Tap topics to delete them',
                              style: GoogleFonts.inter(
                                fontSize: isTablet ? 16 : 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  // Action buttons (hide in edit mode)
                  if (!_isEditMode) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _MinimalActionButton(
                            title: 'Study',
                            icon: Icons.play_circle_outlined,
                            color: widget.classColor,
                            onTap: _startStudySession,
                            isTablet: isTablet,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MinimalActionButton(
                            title: 'Add Topic',
                            icon: Icons.add,
                            color: Colors.grey[800]!,
                            onTap: _showAddTopicDialog,
                            isTablet: isTablet,
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  SizedBox(height: isTablet ? 40 : 32),
                  
                  // Topics header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Topics',
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 24 : 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(FirebaseAuth.instance.currentUser?.uid)
                            .collection('Classes')
                            .doc(widget.classId)
                            .collection('topics')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();
                          
                          // Filter to count only valid topics, not files
                          int validTopicCount = 0;
                          for (var doc in snapshot.data!.docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            
                            // A valid topic should have:
                            // 1. A title field
                            // 2. A createdAt field
                            // 3. NOT have file-specific fields
                            bool isValidTopic = data.containsKey('title') && 
                                               data['title'] != null && 
                                               data['title'].toString().trim().isNotEmpty &&
                                               data.containsKey('createdAt') &&
                                               !data.containsKey('fileName') && // Files have this
                                               !data.containsKey('name') && // Files might have this instead of title
                                               !data.containsKey('path') && // Files have this
                                               !data.containsKey('addedAt'); // Files use this instead of createdAt
                            
                            if (isValidTopic) {
                              validTopicCount++;
                            }
                          }
                          
                          return Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 16 : 12,
                              vertical: isTablet ? 8 : 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$validTopicCount',
                              style: GoogleFonts.inter(
                                fontSize: isTablet ? 14 : 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: isTablet ? 20 : 16),
                ]),
              ),
            ),

            // Topics list
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser?.uid)
                  .collection('Classes')
                  .doc(widget.classId)
                  .collection('topics')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: widget.classColor,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading topics',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return SliverFillRemaining(
                    child: _EmptyState(
                      classColor: widget.classColor,
                      onAddTopic: _showAddTopicDialog,
                      isTablet: isTablet,
                    ),
                  );
                }

                return SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final doc = snapshot.data!.docs[index];
                        final topicData = doc.data() as Map<String, dynamic>;
                        
                        return _MinimalTopicCard(
                          topicId: doc.id,
                          topicData: topicData,
                          classId: widget.classId,
                          classColor: widget.classColor,
                          classTitle: widget.classTitle,
                          isTablet: isTablet,
                          index: index,
                          isEditMode: _isEditMode, // Pass edit mode
                          onDelete: () => _deleteTopic(doc.id, topicData['title'] ?? 'Untitled'), // Pass delete function
                        );
                      },
                      childCount: snapshot.data!.docs.length,
                    ),
                  ),
                );
              },
            ),

            SliverPadding(
              padding: EdgeInsets.only(bottom: isTablet ? 40 : 24),
            ),
          ],
        ),
      ),
    );
  }
}

// Minimal action button
class _MinimalActionButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isTablet;

  const _MinimalActionButton({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: isTablet ? 20 : 16,
          horizontal: isTablet ? 24 : 20,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: isTablet ? 20 : 18,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Minimal topic card
class _MinimalTopicCard extends StatelessWidget {
  final String topicId;
  final Map<String, dynamic> topicData;
  final String classId;
  final Color classColor;
  final String classTitle;
  final bool isTablet;
  final int index;
  final bool isEditMode; // Add this
  final VoidCallback? onDelete; // Add this

  const _MinimalTopicCard({
    required this.topicId,
    required this.topicData,
    required this.classId,
    required this.classColor,
    required this.classTitle,
    required this.isTablet,
    required this.index,
    this.isEditMode = false, // Add this
    this.onDelete, // Add this
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 12 : 8),
      child: GestureDetector(
        onTap: () {
          // If in edit mode, show delete confirmation, otherwise navigate
          if (isEditMode && onDelete != null) {
            onDelete!();
          } else if (!isEditMode) {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    TopicDetailScreen(
                  topicId: topicId,
                  topicData: topicData,
                  classId: classId,
                  classColor: classColor,
                  classTitle: classTitle,
                ),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position: animation.drive(
                      Tween(begin: const Offset(1.0, 0.0), end: Offset.zero).chain(
                        CurveTween(curve: Curves.easeOutCubic),
                      ),
                    ),
                    child: child,
                  );
                },
                transitionDuration: const Duration(milliseconds: 400),
              ),
            );
          }
        },
        child: Container(
          padding: EdgeInsets.all(isTablet ? 20 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isEditMode ? Colors.red[200]! : Colors.grey[100]!,
              width: isEditMode ? 2 : 1,
            ),
            // Add red tint when in edit mode
            boxShadow: isEditMode ? [
              BoxShadow(
                color: Colors.red.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ] : null,
          ),
          child: Row(
            children: [
              Container(
                width: isTablet ? 48 : 40,
                height: isTablet ? 48 : 40,
                decoration: BoxDecoration(
                  color: isEditMode 
                      ? Colors.red.withOpacity(0.1) 
                      : classColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isEditMode ? Icons.delete_outline : Icons.topic_outlined,
                  color: isEditMode ? Colors.red : classColor,
                  size: isTablet ? 24 : 20,
                ),
              ),
              SizedBox(width: isTablet ? 16 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topicData['title'] ?? 'Untitled Topic',
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 18 : 16,
                        fontWeight: FontWeight.w600,
                        color: isEditMode ? Colors.red[700] : Colors.black87,
                      ),
                    ),
                    if (topicData['description'] != null && 
                        topicData['description'].toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        topicData['description'],
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 14 : 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isEditMode && (topicData['fileCount'] ?? 0) > 0) ...[
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 12 : 8,
                        vertical: isTablet ? 6 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${topicData['fileCount']}',
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 12 : 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Icon(
                    isEditMode ? Icons.remove_circle_outline : Icons.chevron_right,
                    color: isEditMode ? Colors.red : Colors.grey[400],
                    size: isTablet ? 20 : 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Empty state
class _EmptyState extends StatelessWidget {
  final Color classColor;
  final VoidCallback onAddTopic;
  final bool isTablet;

  const _EmptyState({
    required this.classColor,
    required this.onAddTopic,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: isTablet ? 80 : 64,
            height: isTablet ? 80 : 64,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.topic_outlined,
              size: isTablet ? 40 : 32,
              color: Colors.grey[400],
            ),
          ),
          SizedBox(height: isTablet ? 24 : 20),
          Text(
            'No topics yet',
            style: GoogleFonts.inter(
              fontSize: isTablet ? 24 : 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first topic to get started',
            style: GoogleFonts.inter(
              fontSize: isTablet ? 16 : 14,
              color: Colors.grey[500],
            ),
          ),
          SizedBox(height: isTablet ? 32 : 24),
          TextButton.icon(
            onPressed: onAddTopic,
            icon: Icon(Icons.add, size: isTablet ? 20 : 18),
            label: const Text('Add Topic'),
            style: TextButton.styleFrom(
              foregroundColor: classColor,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 24 : 20,
                vertical: isTablet ? 12 : 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Topic Detail Screen
class TopicDetailScreen extends StatefulWidget {
  final String topicId;
  final Map<String, dynamic> topicData;
  final String classId;
  final Color classColor;
  final String classTitle;

  const TopicDetailScreen({
    super.key,
    required this.topicId,
    required this.topicData,
    required this.classId,
    required this.classColor,
    required this.classTitle,
  });

  @override
  State<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends State<TopicDetailScreen> {
  bool _isLoading = false;
  bool _isEditMode = false;

  Future<void> _addFile() async {
    try {
      setState(() => _isLoading = true);

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final fileName = result.files.single.name;
        final filePath = result.files.single.path!;
        final fileSize = result.files.single.size;

        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

         // IMPORTANT: Save file to the 'files' subcollection, NOT to 'topics'
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('Classes')
            .doc(widget.classId)
            .collection('topics')
            .doc(widget.topicId)
            .collection('files')  // This ensures files are in subcollection
            .add({
          'name': fileName,
          'path': filePath,
          'addedAt': FieldValue.serverTimestamp(),
          'size': fileSize,
          'type': 'file', // Add type field to distinguish from topics
        });

        // Update file count in the parent topic document
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('Classes')
            .doc(widget.classId)
            .collection('topics')
            .doc(widget.topicId)
            .update({
          'fileCount': FieldValue.increment(1),
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Text('File added successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('Error adding file'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openFile(String path) async {
    try {
      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done) {
        throw 'Could not open file: ${result.message}';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('Cannot open file'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
    });
  }

  Future<void> _deleteFile(String fileId, String fileName) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete File'),
          content: Text('Are you sure you want to delete "$fileName"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('Classes')
            .doc(widget.classId)
            .collection('topics')
            .doc(widget.topicId)
            .collection('files')
            .doc(fileId)
            .delete();

        // Update file count
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('Classes')
            .doc(widget.classId)
            .collection('topics')
            .doc(widget.topicId)
            .update({
          'fileCount': FieldValue.increment(-1),
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Text('File deleted successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Error deleting file'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  // Add this method to _TopicDetailScreenState class
  Future<void> _renameTopic() async {
  String newTitle = widget.topicData['title'] ?? '';
  String newDescription = widget.topicData['description'] ?? '';

  final result = await showModalBottomSheet<Map<String, String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final isTablet = MediaQuery.of(context).size.width > 600;
      final titleController = TextEditingController(text: newTitle);
      final descriptionController = TextEditingController(text: newDescription);

      return Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Title
            Text(
              'Rename Topic',
              style: GoogleFonts.inter(
                fontSize: isTablet ? 28 : 24,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Update the topic name and description',
              style: GoogleFonts.inter(
                fontSize: isTablet ? 16 : 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),

            // Topic title field
            TextField(
              controller: titleController,
              style: GoogleFonts.inter(fontSize: isTablet ? 16 : 14),
              decoration: InputDecoration(
                labelText: 'Topic Title',
                hintText: 'Enter topic name',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: widget.classColor, width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 20 : 16,
                  vertical: isTablet ? 20 : 16,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Description field
            TextField(
              controller: descriptionController,
              maxLines: 3,
              style: GoogleFonts.inter(fontSize: isTablet ? 16 : 14),
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Brief description of the topic',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: widget.classColor, width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 20 : 16,
                  vertical: isTablet ? 20 : 16,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      final title = titleController.text.trim();
                      if (title.isNotEmpty) {
                        Navigator.pop(context, {
                          'title': title,
                          'description': descriptionController.text.trim(),
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.classColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Update Topic',
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );

  if (result != null) {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('Classes')
          .doc(widget.classId)
          .collection('topics')
          .doc(widget.topicId)
          .update({
        'title': result['title']!,
        'description': result['description']!,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('Topic renamed successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('Error renaming topic'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.topicData['title'] ?? 'Topic',
              style: GoogleFonts.inter(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            Text(
              widget.classTitle,
              style: GoogleFonts.inter(
                fontSize: isTablet ? 14 : 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: widget.classColor),
            onPressed: _addFile,
          ),
          IconButton(
            onPressed: _toggleEditMode,
            icon: Icon(
              _isEditMode ? Icons.done : Icons.edit,
              color: _isEditMode ? Colors.green : Colors.grey[600],
            ),
          ),
          SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .collection('Classes')
            .doc(widget.classId)
            .collection('topics')
            .doc(widget.topicId)
            .collection('files')
            .orderBy('addedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: widget.classColor,
                strokeWidth: 2,
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: isTablet ? 80 : 64,
                    height: isTablet ? 80 : 64,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.insert_drive_file_outlined,
                      size: isTablet ? 40 : 32,
                      color: Colors.grey[400],
                    ),
                  ),
                  SizedBox(height: isTablet ? 24 : 20),
                  Text(
                    'No files yet',
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 24 : 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add files to organize your study materials',
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 16 : 14,
                      color: Colors.grey[500],
                    ),
                  ),
                  SizedBox(height: isTablet ? 32 : 24),
                  TextButton.icon(
                    onPressed: _addFile,
                    icon: Icon(Icons.add, size: isTablet ? 20 : 18),
                    label: const Text('Add File'),
                    style: TextButton.styleFrom(
                      foregroundColor: widget.classColor,
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 24 : 20,
                        vertical: isTablet ? 12 : 10,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(isTablet ? 24 : 20),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final fileData = doc.data() as Map<String, dynamic>;

              return Container(
                margin: EdgeInsets.only(bottom: isTablet ? 12 : 8),
                child: ListTile(
                  leading: Container(
                    width: isTablet ? 48 : 40,
                    height: isTablet ? 48 : 40,
                    decoration: BoxDecoration(
                      color: widget.classColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getFileIcon(fileData['name'] ?? ''),
                      color: widget.classColor,
                      size: isTablet ? 24 : 20,
                    ),
                  ),
                  title: Text(
                    fileData['name'] ?? 'Unnamed File',
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    _formatFileSize(fileData['size'] ?? 0),
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 14 : 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  trailing: _isEditMode 
                      ? IconButton(
                          onPressed: () => _deleteFile(doc.id, fileData['name']),
                          icon: Icon(Icons.delete, color: Colors.red),
                        )
                      : Icon(Icons.chevron_right, color: Colors.grey[400]),
                  onTap: _isEditMode ? null : () => _openFile(fileData['path']),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tileColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 20 : 16,
                    vertical: isTablet ? 8 : 4,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
        return Icons.audio_file;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}