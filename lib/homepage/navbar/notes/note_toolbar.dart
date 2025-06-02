import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NoteToolbar extends StatelessWidget {
  final int taskCount;
  final VoidCallback onShowAttachmentOptions;
  final VoidCallback onShowImagePicker;
  
  const NoteToolbar({
    super.key,
    required this.taskCount,
    required this.onShowAttachmentOptions,
    required this.onShowImagePicker,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center, // Center the toolbar
        children: [
          IconButton(
            onPressed: onShowImagePicker,
            icon: Icon(Icons.image, color: Colors.blue.shade600),
            tooltip: 'Add Image',
          ),
          const SizedBox(width: 16), // Add spacing between buttons
          IconButton(
            onPressed: onShowAttachmentOptions,
            icon: Icon(Icons.attach_file, color: Colors.purple.shade600),
            tooltip: 'Add Attachment',
          ),
          // Remove Spacer() and move task count to center as well
          if (taskCount > 0) ...[
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, size: 16, color: Colors.blue.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '$taskCount tasks',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.blue.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ✅ ENHANCED: New enhanced toolbar with subject color support
class EnhancedNoteToolbar extends StatelessWidget {
  final int taskCount;
  final VoidCallback onShowAttachmentOptions;
  final VoidCallback onShowImagePicker;
  final Color? subjectColor;
  
  const EnhancedNoteToolbar({
    super.key,
    required this.taskCount,
    required this.onShowAttachmentOptions,
    required this.onShowImagePicker,
    this.subjectColor,
  });
  
  @override
  Widget build(BuildContext context) {
    final primaryColor = subjectColor ?? Colors.blue;

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
              onTap: onShowImagePicker,
            ),
            const SizedBox(width: 16), // Spacing between buttons
            // File button
            _buildToolbarButton(
              icon: Icons.attach_file_outlined,
              label: 'File',
              color: primaryColor,
              onTap: onShowAttachmentOptions,
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
}