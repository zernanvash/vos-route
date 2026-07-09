import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../providers/trip_provider.dart';
import '../services/action_queue_service.dart';
import '../models/action_entry.dart';

class TripPhotosScreen extends StatefulWidget {
  const TripPhotosScreen({super.key});

  @override
  State<TripPhotosScreen> createState() => _TripPhotosScreenState();
}

class _TripPhotosScreenState extends State<TripPhotosScreen> {
  final List<String> _outboundPhotos = [];
  final List<String> _inboundPhotos = [];
  final ActionQueueService _queue = ActionQueueService();
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final trip = context.watch<TripProvider>().activeTrip;
    final isOutbound = trip?.timeOfDispatch == null;
    final title = isOutbound ? 'Outbound Photos' : 'Inbound Photos';
    final photos = isOutbound ? _outboundPhotos : _inboundPhotos;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isOutbound
                  ? 'Capture cargo condition before departure'
                  : 'Capture cargo condition upon return',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: photos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.photo_camera_outlined,
                            size: 56,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No photos captured',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: photos.length,
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(File(photos[i]), fit: BoxFit.cover),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _capturePhoto,
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text(
                  'Capture Photo',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            if (_isUploading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                borderRadius: BorderRadius.circular(4),
                color: cs.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<String> _saveToPersistentDirectory(String tempPath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(appDir.path, 'photos'));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final newPath = p.join(photosDir.path, fileName);
    await File(tempPath).copy(newPath);
    return newPath;
  }

  Future<void> _capturePhoto() async {
    final trip = context.read<TripProvider>().activeTrip;
    if (trip == null) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (file == null) return;

    final isOutbound = trip.timeOfDispatch == null;

    setState(() {
      if (isOutbound) {
        _outboundPhotos.add(file.path);
      } else {
        _inboundPhotos.add(file.path);
      }
      _isUploading = true;
    });

    try {
      final persistentPath = await _saveToPersistentDirectory(file.path);

      final idx = isOutbound
          ? _outboundPhotos.length - 1
          : _inboundPhotos.length - 1;
      if (isOutbound) {
        _outboundPhotos[idx] = persistentPath;
      } else {
        _inboundPhotos[idx] = persistentPath;
      }
      if (mounted) setState(() {});

      await _queue.enqueue(
        ActionEntry(
          actionType: ActionType.linkTripPhoto,
          payload: {
            'post_dispatch_plan_id': trip.id,
            'local_file_path': persistentPath,
            'type': isOutbound ? 'outbound' : 'inbound',
          },
          endpoint: '/items/post_dispatch_trip_photos',
          httpMethod: 'POST',
          priority: ActionPriority.normal,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
}
