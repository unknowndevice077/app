import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';

class AttachmentManager {
  static Future<String?> pickAndSaveImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      return image?.path;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  static Future<String?> pickAndSaveFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      return result?.files.single.path;
    } catch (e) {
      print('Error picking file: $e');
      return null;
    }
  }

  static void openFileAttachment(BuildContext context, Map<String, dynamic> attachment) async {
    final type = (attachment['type'] ?? '').toLowerCase();
    final path = attachment['path'];
    if (type.contains('image')) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          child: InteractiveViewer(
            child: Image.file(
              File(path),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 80),
            ),
          ),
        ),
      );
    } else {
      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open file: ${result.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class AttachmentOptionsBottomSheet extends StatelessWidget {
  final Future<void> Function()? onPickImage;
  final Future<void> Function()? onPickFile;

  const AttachmentOptionsBottomSheet({
    super.key,
    this.onPickImage,
    this.onPickFile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Add Attachment',
            style: GoogleFonts.dmSerifText(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildOption(Icons.image, 'Image', Colors.blue, onPickImage),
              _buildOption(Icons.attach_file, 'File', Colors.green, onPickFile),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOption(IconData icon, String label, Color color, Future<void> Function()? onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}

class AttachmentList extends StatelessWidget {
  final List<Map<String, dynamic>> attachments;
  final Set<int> selectedAttachments;
  final Function(int) onToggleSelection;
  final VoidCallback onRemoveSelected;

  const AttachmentList({
    super.key,
    required this.attachments,
    required this.selectedAttachments,
    required this.onToggleSelection,
    required this.onRemoveSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Text(
          'Attachments (${attachments.length})',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: attachments.length,
          itemBuilder: (context, index) {
            final attachment = attachments[index];
            final isImage = (attachment['type']?.toLowerCase() ?? '').contains('image');
            return ListTile(
              title: isImage
                  ? GestureDetector(
                      onTap: () => _openAttachment(context, attachment),
                      child: Image.file(
                        File(attachment['path']),
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
                      ),
                    )
                  : Text(attachment['path'].split('/').last),
              subtitle: isImage
                  ? null
                  : Text(attachment['type'].toUpperCase()),
              onTap: () => _openAttachment(context, attachment),
            );
          },
        ),
      ],
    );
  }

  static void _openAttachment(BuildContext context, Map<String, dynamic> attachment) async {
    final type = (attachment['type'] ?? '').toLowerCase();
    final path = attachment['path'];
    if (type.contains('image')) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          child: InteractiveViewer(
            child: Image.file(
              File(path),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 80),
            ),
          ),
        ),
      );
    } else {
      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open file: ${result.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}