import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/trip.dart';
import 'package:intl/intl.dart';
import '../core/app_card.dart';
import '../core/app_status_badge.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _api = ApiService();
  final AuthService _auth = AuthService();
  List<PostDispatchPlan> _trips = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _auth.getProfile();
      if (profile == null) throw Exception('Not authenticated');

      final response = await _api.getDirectus(
        '/items/post_dispatch_plan',
        queryParams: {
          'filter[driver_id][_eq]': profile.userId,
          'filter[status][_in]': 'For Inbound,For Clearance,Posted',
          'sort': '-date_encoded',
          'limit': 20,
        },
      );
      final data = response.data['data'] as List<dynamic>;
      _trips = data
          .map((e) => PostDispatchPlan.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _trips = [];
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Trip History',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.surface,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _trips.isEmpty
          ? Center(child: Text('No past trips', style: AppTextStyle.caption))
          : RefreshIndicator(
              onRefresh: _fetchHistory,
              child: ListView.builder(
                padding: Insets.cardLg,
                itemCount: _trips.length,
                itemBuilder: (_, i) {
                  final t = _trips[i];
                  final fmt = DateFormat('MMM dd, yyyy');
                  return AppCard(
                    margin: EdgeInsets.only(bottom: Insets.sm),
                    child: ListTile(
                      title: Text(t.docNo, style: AppTextStyle.subheading),
                      subtitle: Text(
                        '${t.vehicle?.vehiclePlate ?? "N/A"} | ${fmt.format(t.dateEncoded)}',
                        style: AppTextStyle.caption,
                      ),
                      trailing: AppStatusBadge(status: t.status),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
