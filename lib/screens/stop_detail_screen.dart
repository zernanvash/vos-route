import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../models/stop.dart';
import '../services/map_launch_service.dart';
import '../theme/app_spacing.dart';
import '../theme/app_colors.dart';
import '../config/app_config.dart';

class StopDetailScreen extends StatefulWidget {
  final Object stop;

  const StopDetailScreen({super.key, required this.stop});

  @override
  State<StopDetailScreen> createState() => _StopDetailScreenState();
}

class _StopDetailScreenState extends State<StopDetailScreen> {
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
    final cs = Theme.of(context).colorScheme;
    final lat = _latitude;
    final lng = _longitude;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(_getName()),
        backgroundColor: cs.surface,
        iconTheme: IconThemeData(color: cs.onSurface),
      ),
      body: lat == null || lng == null
          ? _noLocationView()
          : Column(
              children: [
                Expanded(child: _mapView(lat, lng)),
                _navigateButtons(cs: cs, lat: lat, lng: lng, label: _getName()),
              ],
            ),
    );
  }

  Widget _noLocationView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.location_off,
            size: 48,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            'No location coordinates available',
            style: TextStyle(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _mapView(double lat, double lng) {
    return RepaintBoundary(
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
          scrollGesturesEnabled: true,
          zoomGesturesEnabled: true,
          rotateGesturesEnabled: true,
          doubleClickZoomEnabled: true,
        ),
      ),
    );
  }

  Widget _navigateButtons({
    required ColorScheme cs,
    required double lat,
    required double lng,
    required String label,
  }) {
    return Container(
      padding: Insets.cardLg,
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
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
              onTap: () => MapLaunchService.openGeneric(
                lat: lat,
                lng: lng,
                query: label,
              ),
            ),
          ),
        ],
      ),
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
}
