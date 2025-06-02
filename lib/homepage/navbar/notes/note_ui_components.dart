import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'note_models.dart';
import 'note_data_manager.dart';
import 'note_subject_manager.dart';
import 'image_widget.dart' as img_widget;
import 'attachments.dart' as attach;
import 'todo.dart';
import 'notes.dart' show AddNoteScreen;

class NoteUIComponents {
  final NoteDataManager _dataManager = NoteDataManager();
  final NoteSubjectManager _subjectManager = NoteSubjectManager();

  AppBar buildNotesAppBar({
    required BuildContext context,
    required bool editMode,
    required VoidCallback onAddNote,
    required VoidCallback onEditModeToggle,
  }) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Row(
        children: [
          Expanded(
            child: Text(
              'Notes',
              style: GoogleFonts.dmSerifText(
                fontSize: 24,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.add, color: Colors.blue, size: 28),
          tooltip: "Add Note",
          onPressed: onAddNote,
        ),
        IconButton(
          icon: Icon(
            editMode ? Icons.close : Icons.edit,
            color: Colors.blueGrey,
            size: 24,
          ),
          tooltip: "Edit Notes",
          onPressed: onEditModeToggle,
        ),
        IconButton(
          icon: Icon(Icons.checklist, color: Colors.blueGrey[400]),
          onPressed: () {
            try {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Scaffold(
                    backgroundColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.black
                        : Colors.white,
                    appBar: AppBar(
                      backgroundColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black
                          : Colors.white,
                      elevation: 0,
                      title: Text(
                        'Todo Tasks',
                        style: GoogleFonts.dmSerifText(
                          fontSize: 20,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.blueGrey[900],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      iconTheme: IconThemeData(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                    body: const TodoManager(),
                  ),
                ),
              );
            } catch (e) {
              print('Error navigating to TodoManager: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error opening Todo Tasks: $e')),
              );
            }
          },
          tooltip: "Todo Tasks",
        ),
      ],
    );
  }

  Widget buildNotesList({
    required BuildContext context,
    required bool editMode,
    required Function(String) onDeleteNote,
  }) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please log in to view notes'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _dataManager.getNotesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.note_add, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No notes yet',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap + to create your first note',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final title = data['title'] ?? 'Untitled';
            final content = data['content'] ?? '';
            final subject = data['subject'] ?? '';
            final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now();

            return FutureBuilder<Color>(
              future: subject.isNotEmpty 
                  ? _subjectManager.getClassColor(subject) 
                  : Future.value(Colors.blueGrey[400]!),
              builder: (context, colorSnapshot) {
                final classColor = colorSnapshot.data ?? Colors.blueGrey[400]!;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: classColor, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: classColor.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        print('Opening note: $title with ID: ${doc.id}');
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddNoteScreen(
                              onBack: () => Navigator.pop(context),
                              docId: doc.id,
                              initialTitle: title,
                              initialSubject: subject,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: classColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: GoogleFonts.dmSerifText(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey[900],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (editMode)
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                    onPressed: () => onDeleteNote(doc.id),
                                  ),
                              ],
                            ),
                            if (subject.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: classColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: classColor.withOpacity(0.3), width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.book, color: classColor, size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      subject,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: classColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (content.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                content,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.blueGrey[600],
                                  height: 1.4,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDateTime(updatedAt),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                const Spacer(),
                                if (data['tasks'] != null && (data['tasks'] as List).isNotEmpty) ...[
                                  Icon(Icons.check_circle_outline, size: 14, color: classColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${(data['tasks'] as List).length} tasks',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: classColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ));
              },
            );
          },
        );
      },
    );
  }

  Widget buildAddNoteScreen({
    required BuildContext context,
    required TextEditingController titleController,
    required TextEditingController contentController,
    required FocusNode titleFocusNode,
    required FocusNode contentFocusNode,
    required String? selectedSubject,
    required List<String> uploadedImageIds,
    required bool isLoadingImages,
    required List<Map<String, dynamic>> attachments,
    required List<Task> tasks,
    required VoidCallback onBack,
    required VoidCallback onSaveAndExit,
    required VoidCallback onSubjectSelection,
    required VoidCallback onImagePicker,
    required Function(String) onImageRemove,
    required VoidCallback onAttachmentOptions,
    required Function(Map<String, dynamic>) onAttachmentOpen,
    required Function(int) onAttachmentRemove,
    required bool isEditing, // <-- Add this line
  }) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
        title: Text(
          isEditing ? 'Edit Note' : 'Add Note',
          style: GoogleFonts.dmSerifText(
            fontSize: 24,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.menu_book, color: Colors.black, size: 28),
                tooltip: 'Select Subject',
                onPressed: onSubjectSelection,
              ),
              if (selectedSubject != null && selectedSubject.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(left: 4, right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _subjectManager.getSubjectColor(selectedSubject).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _subjectManager.getSubjectColor(selectedSubject),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _subjectManager.getSubjectColor(selectedSubject),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        selectedSubject.length > 8 
                            ? '${selectedSubject.substring(0, 8)}...'
                            : selectedSubject,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _subjectManager.getSubjectColor(selectedSubject),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.check, color: Colors.black),
            tooltip: 'Save & Close',
            onPressed: onSaveAndExit,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Title Field
                  TextField(
                    controller: titleController,
                    focusNode: titleFocusNode,
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Note Title...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[400],
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                      contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                    ),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 20),
                  
                  // Content Field
                  TextField(
                    controller: contentController,
                    focusNode: contentFocusNode,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Start Writing Your Note...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 16,
                        color: Colors.grey[400],
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                      contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                  ),
                  
                  // Images Section using your ImageWidget
                  if (uploadedImageIds.isNotEmpty || isLoadingImages)
                    _buildImagesSection(
                      context,
                      uploadedImageIds,
                      isLoadingImages,
                      selectedSubject,
                      onImageRemove,
                    ),
                  
                  // Attachments Section using your AttachmentsList
                  if (attachments.isNotEmpty)
                    _buildAttachmentsSection(
                      context,
                      attachments,
                      selectedSubject,
                      onAttachmentOpen,
                      onAttachmentRemove,
                    ),
                ],
              ),
            ),
          ),
          
          // Toolbar using your design
          _buildToolbar(
            context,
            selectedSubject,
            tasks,
            onImagePicker,
            onAttachmentOptions,
          ),
        ],
      ),
    );
  }

  Widget _buildImagesSection(
    BuildContext context,
    List<String> uploadedImageIds,
    bool isLoadingImages,
    String? selectedSubject,
    Function(String) onImageRemove,
  ) {
    final primaryColor = selectedSubject != null && selectedSubject.isNotEmpty
        ? _subjectManager.getSubjectColor(selectedSubject)
        : Colors.blue.shade600;

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.image, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Images (${uploadedImageIds.length})',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLoadingImages)
            SizedBox(
              height: 120,
              child: const Center(child: CircularProgressIndicator()),
            )
          else
            SizedBox(
              height: 180,
              child: uploadedImageIds.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'No images added yet',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: uploadedImageIds.length,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: const EdgeInsets.only(right: 12),
                          child: img_widget.ImageWidget(
                            imageId: uploadedImageIds[index],
                            width: 160,
                            height: 160,
                            fit: BoxFit.cover,
                            onDelete: () => onImageRemove(uploadedImageIds[index]),
                          ),
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsSection(
    BuildContext context,
    List<Map<String, dynamic>> attachments,
    String? selectedSubject,
    Function(Map<String, dynamic>) onAttachmentOpen,
    Function(int) onAttachmentRemove,
  ) {
    final primaryColor = selectedSubject != null && selectedSubject.isNotEmpty
        ? _subjectManager.getSubjectColor(selectedSubject)
        : Colors.purple.shade600;

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.attach_file, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Attachments (${attachments.length})',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          attach.AttachmentsList(
            attachments: attachments,
            onAttachmentTap: onAttachmentOpen,
            onAttachmentDelete: onAttachmentRemove,
            onReorder: (oldIndex, newIndex) {
              // Handle reordering if needed
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(
    BuildContext context,
    String? selectedSubject,
    List<Task> tasks,
    VoidCallback onImagePicker,
    VoidCallback onAttachmentOptions,
  ) {
    final primaryColor = selectedSubject != null && selectedSubject.isNotEmpty
        ? _subjectManager.getSubjectColor(selectedSubject)
        : Colors.blue;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: primaryColor.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center, // Center horizontally
          crossAxisAlignment: CrossAxisAlignment.center, // Center vertically
          children: [
            // Photo button
            _buildToolbarButton(
              icon: Icons.image_outlined,
              label: 'Photo',
              color: primaryColor,
              onTap: onImagePicker,
            ),
            const SizedBox(width: 16), // Spacing between buttons
            // File button
            _buildToolbarButton(
              icon: Icons.attach_file_outlined,
              label: 'File',
              color: primaryColor,
              onTap: onAttachmentOptions,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: color.withOpacity(0.8),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: color.withOpacity(0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      final hour = dateTime.hour == 0 ? 12 : dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = dateTime.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[dateTime.weekday - 1];
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}