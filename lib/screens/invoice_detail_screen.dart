import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/stop.dart';
import '../providers/trip_provider.dart';
import '../services/action_queue_service.dart';
import '../models/action_entry.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/app_colors.dart';
import '../core/app_card.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final InvoiceStop stop;

  const InvoiceDetailScreen({super.key, required this.stop});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  final ActionQueueService _queue = ActionQueueService();
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = widget.stop;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Invoice Details'),
        backgroundColor: cs.surface,
        iconTheme: IconThemeData(color: cs.onSurface),
      ),
      body: SingleChildScrollView(
        padding: Insets.cardLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoSection(s),
            Insets.gapXxl,
            _photoSection(context, s),
            Insets.gapXxl,
            _statusSection(),
          ],
        ),
      ),
    );
  }

  Widget _infoSection(InvoiceStop s) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.customerName ?? 'Customer', style: AppTextStyle.heading),
          Insets.gapSm,
          AppInfoRow(label: 'Invoice', value: s.invoiceNo ?? 'N/A'),
          if (s.amount != null)
            AppInfoRow(
              label: 'Amount',
              value: '₱${s.amount!.toStringAsFixed(2)}',
            ),
          AppInfoRow(label: 'Address', value: s.address ?? 'N/A'),
          AppInfoRow(label: 'Status', value: s.status),
          if (s.remarks != null && s.remarks!.isNotEmpty)
            AppInfoRow(label: 'Remarks', value: s.remarks!),
        ],
      ),
    );
  }

  Widget _photoSection(BuildContext context, InvoiceStop s) {
    final trip = context.watch<TripProvider>();
    final photos = trip.getPodPhotos(s.id);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Proof of Delivery Photo',
                  style: AppTextStyle.sectionHeader,
                ),
              ),
              TextButton.icon(
                onPressed: _isUploading ? null : () => _capturePhoto(s),
                icon: const Icon(Icons.add_a_photo, size: 18),
                label: const Text('Add Photo'),
              ),
            ],
          ),
          Insets.gapMd,
          if (photos.isEmpty)
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.border,
                  style: BorderStyle.solid,
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.photo_camera_back,
                      size: 32,
                      color: AppColors.textTertiary,
                    ),
                    Insets.gapSm,
                    Text(
                      'No photos taken yet',
                      style: TextStyle(color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
        ],
      ),
    );
  }

  Widget _statusSection() {
    const statuses = [
      'Fulfilled',
      'Not Fulfilled',
      'Fulfilled with Returns',
      'Fulfilled with Concerns',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Update Invoice Status', style: AppTextStyle.sectionHeader),
        Insets.gapSm,
        ...statuses.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isUploading ? null : () => _updateStatus(s),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(s),
              ),
            ),
          ),
        ),
        if (_isUploading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          ),
      ],
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

  Future<void> _capturePhoto(InvoiceStop s) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() => _isUploading = true);
    try {
      final persistentPath = await _saveToPersistentDirectory(file.path);

      await _queue.enqueue(
        ActionEntry(
          actionType: ActionType.linkTripPhoto,
          payload: {
            'trip_id': context.read<TripProvider>().activeTrip?.id,
            'local_file_path': persistentPath,
            'type': 'invoice',
          },
          endpoint: '/items/post_dispatch_trip_photos',
          httpMethod: 'POST',
          priority: ActionPriority.normal,
        ),
      );

      if (mounted) {
        context.read<TripProvider>().addPodPhoto(
          s.id,
          persistentPath,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to capture photo'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _updateStatus(String status) async {
    final tripProvider = context.read<TripProvider>();
    setState(() => _isUploading = true);

    try {
      await tripProvider.updateStopStatus(widget.stop.id, status);
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
}
