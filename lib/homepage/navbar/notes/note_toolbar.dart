import 'package:flutter/material.dart';

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ToolbarButton(
            icon: Icons.attach_file,
            onTap: onShowAttachmentOptions,
            tooltip: 'Attach File',
          ),
          _ToolbarButton(
            icon: Icons.image,
            onTap: onShowImagePicker,
            tooltip: 'Add Image',
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  final String? badge;

  const _ToolbarButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          icon: Icon(icon, color: Colors.grey[600]),
          onPressed: onTap,
          tooltip: tooltip,
        ),
        if (badge != null)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}