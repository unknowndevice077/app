import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'image_handler.dart';

class FirestoreImageWidget extends StatefulWidget {
  final String imageId;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool showDeleteButton;
  final VoidCallback? onDelete;

  const FirestoreImageWidget({
    super.key,
    required this.imageId,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.showDeleteButton = false,
    this.onDelete,
  });

  @override
  State<FirestoreImageWidget> createState() => _FirestoreImageWidgetState();
}

class _FirestoreImageWidgetState extends State<FirestoreImageWidget> {
  Uint8List? _imageBytes;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final imageBytes = await ImageHandler.loadImageFromFirestore(widget.imageId);
      if (mounted) {
        setState(() {
          _imageBytes = imageBytes;
          _isLoading = false;
          _error = imageBytes == null ? 'Image not found' : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading image: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        width: widget.width ?? 200,
        height: widget.height ?? 200,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Container(
        width: widget.width ?? 200,
        height: widget.height ?? 200,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        GestureDetector(
          onTap: () => _showFullScreenImage(context),
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                _imageBytes!,
                width: widget.width,
                height: widget.height,
                fit: widget.fit,
              ),
            ),
          ),
        ),
        if (widget.showDeleteButton)
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => _showDeleteConfirmation(context),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showFullScreenImage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.memory(_imageBytes!),
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Image'),
        content: const Text('Are you sure you want to delete this image?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await ImageHandler.deleteImageFromFirestore(widget.imageId);
              widget.onDelete?.call();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}