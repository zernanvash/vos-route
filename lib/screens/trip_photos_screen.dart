import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/trip_provider.dart';
import '../services/upload_service.dart';
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
  final UploadService _uploadService = UploadService();
  final ActionQueueService _queue = ActionQueueService();
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    final trip = context.watch<TripProvider>().activeTrip;
    final isOutbound = trip?.timeOfDispatch == null;
    final title = isOutbound ? 'Outbound Photos' : 'Inbound Photos';
    final photos = isOutbound ? _outboundPhotos : _inboundPhotos;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey.shade900,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isOutbound
                  ? 'Capture cargo condition before departure'
                  : 'Capture cargo condition upon return',
              style: TextStyle(color: Colors.grey.shade400),
            ),
            SizedBox(height: 16),
            Expanded(
              child: photos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.photo_camera,
                            size: 64,
                            color: Colors.grey.shade600,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No photos captured',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: photos.length,
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(photos[i]), fit: BoxFit.cover),
                      ),
                    ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _capturePhoto,
                icon: Icon(Icons.camera_alt),
                label: Text('Capture Photo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            if (_isUploading) ...[
              SizedBox(height: 12),
              LinearProgressIndicator(backgroundColor: Colors.grey.shade800),
            ],
          ],
        ),
      ),
    );
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
      final uuid = await _uploadService.uploadFile(file.path);
      if (uuid != null) {
        await _queue.enqueue(
          ActionEntry(
            actionType: ActionType.linkTripPhoto,
            payload: {
              'post_dispatch_plan_id': trip.id,
              'file': uuid,
              'type': isOutbound ? 'outbound' : 'inbound',
            },
            endpoint: '/items/post_dispatch_trip_photos',
            httpMethod: 'POST',
            priority: ActionPriority.normal,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
}
