import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

// Attachment Manager Class
class AttachmentManager {
  static Future<String?> pickAndSaveImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      
      if (pickedFile != null) {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedPath = '${directory.path}/$fileName';
        
        await File(pickedFile.path).copy(savedPath);
        return savedPath;
      }
    } catch (e) {
      print('Error picking image: $e');
    }
    return null;
  }

  static Future<String?> pickAndSaveFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final directory = await getApplicationDocumentsDirectory();
        final fileName = 'file_${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';
        final savedPath = '${directory.path}/$fileName';
        
        await file.copy(savedPath);
        return savedPath;
      }
    } catch (e) {
      print('Error picking file: $e');
    }
    return null;
  }

  static Future<String?> recordAudio(FlutterSoundRecorder recorder) async {
    try {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        return null;
      }

      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.aac';
      final audioPath = '${directory.path}/$fileName';

      await recorder.startRecorder(toFile: audioPath);
      return audioPath;
    } catch (e) {
      print('Error starting recording: $e');
      return null;
    }
  }

  static Future<void> stopRecording(FlutterSoundRecorder recorder) async {
    try {
      await recorder.stopRecorder();
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  static String getAttachmentIcon(String type) {
    switch (type.toLowerCase()) {
      case 'image':
        return '🖼️';
      case 'file':
        return '📄';
      case 'audio':
        return '🎵';
      default:
        return '📎';
    }
  }

  static String getAttachmentName(String path) {
    return path.split('/').last;
  }
}

// Attachment Toolbar Widget
class AttachmentToolbar extends StatelessWidget {
  final VoidCallback onShowAttachmentOptions;

  const AttachmentToolbar({
    super.key,
    required this.onShowAttachmentOptions,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.attach_file, color: Colors.black, size: 28),
      onPressed: onShowAttachmentOptions,
      tooltip: 'Add Attachment',
    );
  }
}

// Attachment Options Bottom Sheet
class AttachmentOptionsBottomSheet extends StatelessWidget {
  final bool isRecording;
  final VoidCallback onPickImage;
  final VoidCallback onPickFile;
  final VoidCallback onToggleRecording;

  const AttachmentOptionsBottomSheet({
    super.key,
    required this.isRecording,
    required this.onPickImage,
    required this.onPickFile,
    required this.onToggleRecording,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Add Attachment',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _AttachmentOption(
                icon: Icons.image,
                label: 'Image',
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(context);
                  onPickImage();
                },
              ),
              _AttachmentOption(
                icon: Icons.attach_file,
                label: 'File',
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  onPickFile();
                },
              ),
              _AttachmentOption(
                icon: isRecording ? Icons.stop : Icons.mic,
                label: isRecording ? 'Stop' : 'Record',
                color: isRecording ? Colors.red : Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  onToggleRecording();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(
              icon,
              color: color,
              size: 30,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

// Attachment List Widget
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

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Attachments (${attachments.length})',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (selectedAttachments.isNotEmpty)
                TextButton(
                  onPressed: onRemoveSelected,
                  child: Text(
                    'Remove (${selectedAttachments.length})',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...attachments.asMap().entries.map((entry) {
            final index = entry.key;
            final attachment = entry.value;
            final isSelected = selectedAttachments.contains(index);
            
            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getAttachmentColor(attachment['type']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getAttachmentIcon(attachment['type']),
                    color: _getAttachmentColor(attachment['type']),
                  ),
                ),
                title: Text(
                  AttachmentManager.getAttachmentName(attachment['path']),
                  style: const TextStyle(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  attachment['type'].toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                trailing: Checkbox(
                  value: isSelected,
                  onChanged: (_) => onToggleSelection(index),
                ),
                selected: isSelected,
                selectedTileColor: Colors.red.withOpacity(0.1),
                onTap: () => onToggleSelection(index),
              ),
            );
          }),
        ],
      ),
    );
  }

  IconData _getAttachmentIcon(String type) {
    switch (type.toLowerCase()) {
      case 'image':
        return Icons.image;
      case 'file':
        return Icons.attach_file;
      case 'audio':
        return Icons.audiotrack;
      default:
        return Icons.attachment;
    }
  }

  Color _getAttachmentColor(String type) {
    switch (type.toLowerCase()) {
      case 'image':
        return Colors.blue;
      case 'file':
        return Colors.green;
      case 'audio':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}