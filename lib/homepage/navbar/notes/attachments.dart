import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AttachmentManager {
  // ✅ Pick and save any file as attachment
  static Future<Map<String, dynamic>?> pickAndSaveFile({
    required BuildContext context,
    String? noteId,
  }) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        final fileSize = await file.length();

        // Check file size (reduce limit)
        if (fileSize > 5 * 1024 * 1024) { // ✅ Reduced from 10MB to 5MB
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File too large (${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB). Maximum size is 5MB.'),
              backgroundColor: Colors.red,
            ),
          );
          return null;
        }

        // Convert to Base64
        final bytes = await file.readAsBytes();
        final base64String = base64Encode(bytes);

        Navigator.of(context).pop();

        // Return attachment data
        return {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'name': fileName,
          'base64': base64String,
          'size': fileSize,
          'type': _getFileType(fileName),
          'mimeType': _getMimeType(fileName),
          'addedAt': DateTime.now().toIso8601String(),
        };
      }

      Navigator.of(context).pop();
      return null;
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      print('Error picking file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking file: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }
  
  // ✅ Pick PDF file specifically
  static Future<Map<String, dynamic>?> pickPDFFile({
    required BuildContext context,
    String? noteId,
  }) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Processing PDF...'),
              ],
            ),
          ),
        ),
      );

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        final fileSize = await file.length();

        if (fileSize > 10 * 1024 * 1024) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF too large. Maximum size is 10MB.'),
              backgroundColor: Colors.red,
            ),
          );
          return null;
        }

        final bytes = await file.readAsBytes();
        final base64String = base64Encode(bytes);

        Navigator.of(context).pop();

        return {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'name': fileName,
          'base64': base64String,
          'size': fileSize,
          'type': 'PDF Document',
          'mimeType': 'application/pdf',
          'addedAt': DateTime.now().toIso8601String(),
        };
      }

      Navigator.of(context).pop();
      return null;
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      print('Error picking PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }
  
  // ✅ Open file attachment
  static void openFileAttachment(BuildContext context, Map<String, dynamic> attachment) {
    final base64String = attachment['base64'] as String?;
    final fileName = attachment['name'] as String? ?? 'Unknown File';
    final fileType = attachment['type'] as String? ?? 'File';

    if (base64String == null || base64String.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File data not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // For images, show in a dialog
      if (fileType.toLowerCase().contains('image') || 
          attachment['mimeType']?.toString().startsWith('image/') == true) {
        final bytes = base64Decode(base64String);
        _showFullScreenImage(context, bytes, fileName);
        return;
      }

      // For other files, show options dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(_getFileIcon(fileType), color: _getFileTypeColor(fileType)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  fileName,
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'File Type: $fileType',
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
              ),
              SizedBox(height: 4),
              Text(
                'Size: ${_formatFileSize(attachment['size'] ?? 0)}',
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
              ),
              SizedBox(height: 16),
              Text(
                'What would you like to do with this file?',
                style: GoogleFonts.inter(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _saveFileToDevice(context, base64String, fileName);
              },
              icon: Icon(Icons.download, size: 18),
              label: Text('Save to Device'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // ✅ Delete attachment
  static void deleteAttachment(Map<String, dynamic> attachment) {
    print('Deleting attachment: ${attachment['name']}');
  }

  // ✅ Helper methods
  static String _getFileType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return 'PDF Document';
      case 'doc':
      case 'docx':
        return 'Word Document';
      case 'xls':
      case 'xlsx':
        return 'Excel Spreadsheet';
      case 'ppt':
      case 'pptx':
        return 'PowerPoint';
      case 'txt':
        return 'Text File';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return 'Image';
      default:
        return 'File';
    }
  }

  static String _getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  static Color _getFileTypeColor(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf document':
        return Colors.red;
      case 'word document':
        return Colors.blue;
      case 'excel spreadsheet':
        return Colors.green;
      case 'powerpoint':
        return Colors.orange;
      case 'image':
        return Colors.purple;
      case 'text file':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  static IconData _getFileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf document':
        return Icons.picture_as_pdf;
      case 'word document':
        return Icons.description;
      case 'excel spreadsheet':
        return Icons.table_chart;
      case 'powerpoint':
        return Icons.slideshow;
      case 'image':
        return Icons.image;
      case 'text file':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static void _showFullScreenImage(BuildContext context, Uint8List bytes, String fileName) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(20),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width,
            maxHeight: MediaQuery.of(context).size.height,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        fileName,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: InteractiveViewer(
                    panEnabled: true,
                    boundaryMargin: EdgeInsets.all(100),
                    minScale: 0.5,
                    maxScale: 3.0,
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _saveFileToDevice(BuildContext context, String base64String, String fileName) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.info, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'File saving feature needs path_provider package',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: EdgeInsets.all(16),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// ✅ AttachmentsList Widget
class AttachmentsList extends StatelessWidget {
  final List<Map<String, dynamic>> attachments;
  final Function(Map<String, dynamic>) onAttachmentTap;
  final Function(int) onAttachmentDelete;
  final Function(int, int) onReorder;
  
  const AttachmentsList({
    super.key,
    required this.attachments,
    required this.onAttachmentTap,
    required this.onAttachmentDelete,
    required this.onReorder,
  });
  
  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: attachments.length,
      onReorder: onReorder,
      itemBuilder: (context, index) {
        final attachment = attachments[index];
        return Container(
          key: ValueKey(attachment['id'] ?? index),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AttachmentManager._getFileTypeColor(attachment['type'] ?? 'File').withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                AttachmentManager._getFileIcon(attachment['type'] ?? 'File'),
                color: AttachmentManager._getFileTypeColor(attachment['type'] ?? 'File'),
                size: 24,
              ),
            ),
            title: Text(
              attachment['name'] ?? 'Unknown File',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment['type'] ?? 'Unknown Type',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (attachment['size'] != null)
                  Text(
                    AttachmentManager._formatFileSize(attachment['size']),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.open_in_new, size: 20, color: Colors.blue.shade600),
                  onPressed: () => onAttachmentTap(attachment),
                  tooltip: 'Open file',
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade600),
                  onPressed: () => onAttachmentDelete(index),
                  tooltip: 'Remove file',
                ),
              ],
            ),
            onTap: () => onAttachmentTap(attachment),
          ),
        );
      },
    );
  }
}