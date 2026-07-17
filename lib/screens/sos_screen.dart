import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../services/emergency_service.dart';
import '../models/emergency_report.dart';
import '../providers/auth_provider.dart';
import '../providers/trip_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  final _descriptionController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _emergencyService = EmergencyService();
  String _incidentType = 'Accident';
  String _severity = 'High';
  double? _lat;
  double? _lng;
  bool _isSubmitting = false;

  final _incidentTypes = [
    'Accident',
    'Breakdown',
    'Medical',
    'Security',
    'Weather',
    'Other',
  ];
  final _severities = ['Low', 'Medium', 'High', 'Critical'];

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null) {
        setState(() {
          _lat = pos.latitude;
          _lng = pos.longitude;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency SOS'),
        backgroundColor: AppColors.errorDark,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: SingleChildScrollView(
        padding: Insets.cardLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Warning banner ───────────────────────────────────────
            Container(
              padding: Insets.cardLg,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(Insets.cardRadius),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_rounded, color: AppColors.error, size: 28),
                  Insets.gapWMd,
                  Expanded(
                    child: Text(
                      'Use this only for genuine emergencies. This will alert the dispatcher immediately.',
                      style: TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            Insets.gapXl,
            Text(
              'Incident Type',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Insets.gapSm,
            DropdownButtonFormField<String>(
              initialValue: _incidentType,
              items: _incidentTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _incidentType = v ?? 'Accident'),
              decoration: const InputDecoration(),
            ),
            Insets.gapLg,
            Text(
              'Severity',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Insets.gapSm,
            DropdownButtonFormField<String>(
              initialValue: _severity,
              items: _severities
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _severity = v ?? 'High'),
              decoration: const InputDecoration(),
            ),
            Insets.gapLg,
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Describe the situation...',
              ),
            ),
            Insets.gapLg,
            TextField(
              controller: _contactNameController,
              decoration: const InputDecoration(
                hintText: 'Contact person (optional)',
              ),
            ),
            Insets.gapLg,
            TextField(
              controller: _contactPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: 'Contact phone (optional)',
              ),
            ),
            if (_lat != null)
              Padding(
                padding: const EdgeInsets.only(top: Insets.sm),
                child: Text(
                  'Location: ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
              ),
            Insets.gapXl,
            SizedBox(
              width: double.infinity,
              height: Insets.buttonHeight,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitSos,
                icon: const Icon(Icons.warning_rounded, size: 22),
                label: Text(
                  _isSubmitting ? 'Submitting...' : 'SEND SOS',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.errorDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Insets.cardRadius),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitSos() async {
    if (_descriptionController.text.trim().isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send emergency report?'),
        content: const Text(
          'This will queue an SOS report with your current trip and location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Queue SOS'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);

    final auth = context.read<AuthProvider>();
    final trip = context.read<TripProvider>();

    final report = EmergencyReport(
      reportNo: 'SOS-${DateTime.now().millisecondsSinceEpoch}',
      incidentType: _incidentType,
      severity: _severity,
      description: _descriptionController.text.trim(),
      latitude: _lat,
      longitude: _lng,
      vehicleId: trip.activeTrip?.vehicleId,
      dispatchPlanId: trip.activeTrip?.id,
      driverUserId: auth.profile?.userId,
      contactName: _contactNameController.text.trim().isNotEmpty
          ? _contactNameController.text.trim()
          : null,
      contactPhone: _contactPhoneController.text.trim().isNotEmpty
          ? _contactPhoneController.text.trim()
          : null,
    );

    await _emergencyService.submitReport(report);

    if (mounted) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Emergency report queued'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      Navigator.pop(context);
    }
  }
}
