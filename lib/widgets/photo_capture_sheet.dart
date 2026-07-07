import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PhotoCaptureSheet extends StatelessWidget {
  final ValueChanged<XFile> onPhotoTaken;

  const PhotoCaptureSheet({super.key, required this.onPhotoTaken});

  void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      builder: (_) => this,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Capture Photo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _button(
                  context,
                  Icons.camera_alt,
                  'Camera',
                  ImageSource.camera,
                ),
                _button(
                  context,
                  Icons.photo_library,
                  'Gallery',
                  ImageSource.gallery,
                ),
              ],
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _button(
    BuildContext context,
    IconData icon,
    String label,
    ImageSource source,
  ) {
    return GestureDetector(
      onTap: () async {
        final picker = ImagePicker();
        final file = await picker.pickImage(source: source, imageQuality: 85);
        if (file != null) {
          onPhotoTaken(file);
        }
        if (context.mounted) Navigator.pop(context);
      },
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade800,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 36),
          ),
          SizedBox(height: 8),
          Text(label, style: TextStyle(color: Colors.grey.shade300)),
        ],
      ),
    );
  }
}
