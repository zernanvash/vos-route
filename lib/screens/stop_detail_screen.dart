import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/stop.dart';
import '../providers/trip_provider.dart';
import '../services/map_launch_service.dart';
import '../services/action_queue_service.dart';
import '../models/action_entry.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/app_colors.dart';
import '../core/app_card.dart';
import '../config/app_config.dart';

class StopDetailScreen extends StatefulWidget {
  final Object stop;

  const StopDetailScreen({super.key, required this.stop});

  @override
  State<StopDetailScreen> createState() => _StopDetailScreenState();
}

class _StopDetailScreenState extends State<StopDetailScreen> {
  String? _localPhotoPath;
  final ActionQueueService _queue = ActionQueueService();
  bool _isUploading = false;
  MapLibreMapController? _mapController;

  InvoiceStop? get _invoiceStop =>
      widget.stop is InvoiceStop ? widget.stop as InvoiceStop : null;

  OtherStop? get _otherStop =>
      widget.stop is OtherStop ? widget.stop as OtherStop : null;

  PurchaseStop? get _purchaseStop =>
      widget.stop is PurchaseStop ? widget.stop as PurchaseStop : null;

  double? get _latitude {
    if (_invoiceStop != null) return _invoiceStop!.latitude;
    if (_otherStop != null) return _otherStop!.latitude;
    return null;
  }

  double? get _longitude {
    if (_invoiceStop != null) return _invoiceStop!.longitude;
    if (_otherStop != null) return _otherStop!.longitude;
    return null;
  }

  String _getName() {
    if (_invoiceStop != null) return _invoiceStop!.customerName ?? 'Customer';
    if (_otherStop != null) return _otherStop!.remarks ?? 'Other Stop';
    if (_purchaseStop != null) return _purchaseStop!.supplierName ?? 'Supplier';
    return 'Stop';
  }

  Future<Uint8List> _createMarkerImage({
    required Color color,
    double radius = 10.0,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(radius, 0);
    path.arcToPoint(Offset(0, radius), radius: Radius.circular(radius));
    path.lineTo(radius, radius * 2.5);
    path.lineTo(radius * 2, radius);
    path.arcToPoint(Offset(radius, 0), radius: Radius.circular(radius));
    path.close();

    canvas.drawPath(path, paint);

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(radius, radius), radius * 0.4, whitePaint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(
      (radius * 2).toInt(),
      (radius * 2.5).toInt(),
    );
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _onStyleLoaded() async {
    final controller = _mapController;
    if (controller == null) return;

    try {
      final double? lat = _latitude;
      final double? lng = _longitude;
      if (lat != null && lng != null) {
        final color = widget.stop is OtherStop
            ? AppColors.warning
            : AppColors.primary;
        final markerBytes = await _createMarkerImage(color: color);
        await controller.addImage('stop-marker', markerBytes);

        await controller.addSymbol(
          SymbolOptions(
            geometry: LatLng(lat, lng),
            iconImage: 'stop-marker',
            iconSize: 1.0,
            textField: _getName(),
            textSize: 10,
            textColor: '#FFFFFF',
            textHaloColor: '#000000',
            textHaloWidth: 1.0,
            textOffset: const Offset(0, -2.5),
          ),
        );
      }
    } catch (e) {
      debugPrint('[StopDetailScreen] Failed to add map symbol: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(_getTitle(), style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.surface,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: Insets.cardLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _mapSection(),
            Insets.gapLg,
            _infoSection(),
            if (_invoiceStop != null) ...[
              Insets.gapXxl,
              _photoSection(),
              Insets.gapXxl,
              _statusSection(),
            ],
            if (_otherStop != null) ...[Insets.gapXxl, _otherStatusSection()],
          ],
        ),
      ),
    );
  }

  String _getTitle() {
    if (widget.stop is InvoiceStop) return 'Delivery Stop';
    if (widget.stop is PurchaseStop) return 'Pick-up Stop';
    if (widget.stop is OtherStop) return 'Other Stop';
    return 'Stop';
  }

  Widget _mapSection() {
    final lat = _latitude;
    final lng = _longitude;
    if (lat == null || lng == null) {
      return AppCard(
        child: Padding(
          padding: const EdgeInsets.all(Insets.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.location_off, color: AppColors.textTertiary),
              SizedBox(width: 8),
              Text(
                'No location coordinates available',
                style: TextStyle(color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Insets.cardRadius),
          child: SizedBox(
            height: 220,
            width: double.infinity,
            child: RepaintBoundary(
              child: ExcludeSemantics(
                child: MapLibreMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(lat, lng),
                    zoom: 15,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  onStyleLoadedCallback: _onStyleLoaded,
                  styleString: AppConfig.mapStyleUrl,
                  scrollGesturesEnabled: false,
                  zoomGesturesEnabled: false,
                  rotateGesturesEnabled: false,
                  doubleClickZoomEnabled: false,
                ),
              ),
            ),
          ),
        ),
        Insets.gapMd,
        _navigateButtons(lat: lat, lng: lng, label: _getName()),
      ],
    );
  }

  Widget _infoSection() {
    if (widget.stop is InvoiceStop) {
      final s = widget.stop as InvoiceStop;
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
          ],
        ),
      );
    }
    if (widget.stop is PurchaseStop) {
      final s = widget.stop as PurchaseStop;
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.supplierName ?? 'Supplier', style: AppTextStyle.heading),
            Insets.gapSm,
            AppInfoRow(label: 'PO No', value: s.poNo ?? 'N/A'),
            AppInfoRow(label: 'Status', value: s.status),
          ],
        ),
      );
    }
    if (widget.stop is OtherStop) {
      final s = widget.stop as OtherStop;
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.remarks ?? 'Other Stop', style: AppTextStyle.heading),
            Insets.gapSm,
            AppInfoRow(label: 'Sequence', value: '${s.sequence}'),
            if (s.distance != null)
              AppInfoRow(
                label: 'Distance',
                value: '${s.distance!.toStringAsFixed(2)} km',
              ),
            AppInfoRow(label: 'Status', value: s.status),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _navigateButtons({
    required double lat,
    required double lng,
    required String label,
  }) {
    return Row(
      children: [
        Expanded(
          child: _navButton(
            icon: Icons.map,
            label: 'Google Maps',
            color: Colors.red.shade700,
            onTap: () => MapLaunchService.openInGoogleMaps(
              lat: lat,
              lng: lng,
              query: label,
            ),
          ),
        ),
        Insets.gapWSm,
        Expanded(
          child: _navButton(
            icon: Icons.directions_car,
            label: 'Waze',
            color: Colors.blue.shade700,
            onTap: () =>
                MapLaunchService.openInWaze(lat: lat, lng: lng, query: label),
          ),
        ),
        Insets.gapWSm,
        Expanded(
          child: _navButton(
            icon: Icons.open_in_new,
            label: 'Other',
            color: AppColors.border,
            onTap: () =>
                MapLaunchService.openGeneric(lat: lat, lng: lng, query: label),
          ),
        ),
      ],
    );
  }

  Widget _navButton({
    required IconData icon,
    required String label,
    required Color color,
    required Future<bool> Function() onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: () async {
        final ok = await onTap();
        if (!ok && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('No map app available')));
        }
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      ),
      icon: Icon(icon, size: 18),
      label: FittedBox(child: Text(label)),
    );
  }

  Widget _photoSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Proof of Delivery Photo', style: AppTextStyle.sectionHeader),
          Insets.gapMd,
          if (_localPhotoPath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(_localPhotoPath!),
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            GestureDetector(
              onTap: _capturePhoto,
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.border,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.camera_alt,
                        size: 40,
                        color: AppColors.textTertiary,
                      ),
                      Insets.gapSm,
                      const Text(
                        'Tap to capture photo',
                        style: TextStyle(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusSection() {
    final statuses = [
      'Fulfilled',
      'Not Fulfilled',
      'Fulfilled with Returns',
      'Fulfilled with Concerns',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Update Stop Status', style: AppTextStyle.sectionHeader),
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

  Widget _otherStatusSection() {
    final s = _otherStop!;
    final statuses = ['Fulfilled', 'Not Fulfilled'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Update Stop Status', style: AppTextStyle.sectionHeader),
        Insets.gapSm,
        ...statuses.map(
          (status) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isUploading
                    ? null
                    : () async {
                        setState(() => _isUploading = true);
                        try {
                          await context
                              .read<TripProvider>()
                              .updateOtherStopStatus(s.id, status);
                          if (mounted) Navigator.pop(context);
                        } catch (_) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to update status'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isUploading = false);
                        }
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(status),
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

  Future<void> _capturePhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (file != null) {
      final persistentPath = await _saveToPersistentDirectory(file.path);
      setState(() => _localPhotoPath = persistentPath);
    }
  }

  Future<void> _updateStatus(String status) async {
    if (_invoiceStop == null) return;

    final tripProvider = context.read<TripProvider>();
    setState(() => _isUploading = true);

    try {
      if (_localPhotoPath != null) {
        await _queue.enqueue(
          ActionEntry(
            actionType: ActionType.linkPodPhoto,
            payload: {
              'post_dispatch_invoice_id': _invoiceStop!.id,
              'local_file_path': _localPhotoPath!,
              'doc_no': _invoiceStop!.invoiceNo,
            },
            endpoint: '/items/post_dispatch_nte',
            httpMethod: 'POST',
            priority: ActionPriority.normal,
          ),
        );
      }

      await tripProvider.updateStopStatus(_invoiceStop!.id, status);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
}
