import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../services/emergency_service.dart';
import '../models/emergency_report.dart';
import '../providers/auth_provider.dart';
import '../providers/trip_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text('Emergency SOS', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.errorDark,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: Insets.cardLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: Insets.cardLg,
              decoration: BoxDecoration(
                color: AppColors.errorDark.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(Insets.cardRadius),
                border: Border.all(color: AppColors.error),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: AppColors.error, size: 32),
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
            Text('Incident Type', style: AppTextStyle.caption),
            Insets.gapSm,
            DropdownButtonFormField<String>(
              initialValue: _incidentType,
              items: _incidentTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _incidentType = v ?? 'Accident'),
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(),
            ),
            Insets.gapLg,
            Text('Severity', style: AppTextStyle.caption),
            Insets.gapSm,
            DropdownButtonFormField<String>(
              initialValue: _severity,
              items: _severities
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _severity = v ?? 'High'),
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(),
            ),
            Insets.gapLg,
            TextField(
              controller: _descriptionController,
              style: const TextStyle(color: Colors.white),
              maxLines: 4,
              decoration: _inputDecoration(hint: 'Describe the situation...'),
            ),
            Insets.gapLg,
            TextField(
              controller: _contactNameController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(hint: 'Contact person (optional)'),
            ),
            Insets.gapLg,
            TextField(
              controller: _contactPhoneController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.phone,
              decoration: _inputDecoration(hint: 'Contact phone (optional)'),
            ),
            Insets.gapSm,
            if (_lat != null)
              Padding(
                padding: EdgeInsets.only(bottom: Insets.sm),
                child: Text(
                  'Location: $_lat, $_lng',
                  style: AppTextStyle.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            Insets.gapLg,
            SizedBox(
              width: double.infinity,
              height: Insets.buttonHeight,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitSos,
                icon: const Icon(Icons.warning, size: 24),
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

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textTertiary),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Insets.smallRadius),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _submitSos() async {
    if (_descriptionController.text.trim().isEmpty) return;

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
          content: Text('Emergency report submitted'),
          backgroundColor: AppColors.successDark,
        ),
      );
      Navigator.pop(context);
    }
  }
}
