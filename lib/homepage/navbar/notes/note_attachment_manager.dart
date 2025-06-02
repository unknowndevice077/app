import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class NoteAttachmentManager {
  void showAttachmentOptions(
    BuildContext context,
    Function(Map<String, dynamic>?) onAttachmentSelected,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 20),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Add Attachment',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 24),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _AttachmentOption(
                    icon: Icons.insert_drive_file,
                    label: 'Any File',
                    subtitle: 'Documents, images, etc.',
                    color: Colors.purple,
                    onTap: () async {
                      Navigator.pop(context);
                      final attachment = await _pickAndProcessFile();
                      onAttachmentSelected(attachment);
                    },
                  ),
                  SizedBox(height: 12),
                  _AttachmentOption(
                    icon: Icons.picture_as_pdf,
                    label: 'PDF Only',
                    subtitle: 'Select PDF documents',
                    color: Colors.red,
                    onTap: () async {
                      Navigator.pop(context);
                      final attachment = await _pickAndProcessPDF();
                      onAttachmentSelected(attachment);
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void openAttachment(BuildContext context, Map<String, dynamic> attachment) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Opening file...'),
              ],
            ),
          ),
        ),
      );

      // Decode base64 and save to temporary file
      final base64String = attachment['base64'] as String;
      final bytes = base64Decode(base64String);
      
      final tempDir = await getTemporaryDirectory();
      final fileName = attachment['name'] as String;
      final tempFile = File('${tempDir.path}/$fileName');
      
      await tempFile.writeAsBytes(bytes);

      // Close loading dialog
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Open the file
      final result = await OpenFilex.open(tempFile.path);
      
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open file: ${result.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static Future<Map<String, dynamic>?> _pickAndProcessFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        final fileSize = await file.length();

        // Check file size (max 10MB)
        if (fileSize > 10 * 1024 * 1024) {
          return null;
        }

        // Convert to Base64
        final bytes = await file.readAsBytes();
        final base64String = base64Encode(bytes);

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
      return null;
    } catch (e) {
      print('Error picking file: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _pickAndProcessPDF() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        final fileSize = await file.length();

        // Check file size (max 10MB)
        if (fileSize > 10 * 1024 * 1024) {
          return null;
        }

        // Convert to Base64
        final bytes = await file.readAsBytes();
        final base64String = base64Encode(bytes);

        return {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'name': fileName,
          'base64': base64String,
          'size': fileSize,
          'type': 'PDF',
          'mimeType': 'application/pdf',
          'addedAt': DateTime.now().toIso8601String(),
        };
      }
      return null;
    } catch (e) {
      print('Error picking PDF: $e');
      return null;
    }
  }

  static String _getFileType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return 'PDF';
      case 'doc':
      case 'docx':
        return 'Word Document';
      case 'jpg':
      case 'jpeg':
      case 'png':
        return 'Image';
      case 'txt':
        return 'Text File';
      default:
        return 'File';
    }
  }

  static String _getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }
}

class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: color),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: color.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}