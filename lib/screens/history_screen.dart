import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/trip.dart';
import 'package:intl/intl.dart';
import '../core/app_card.dart';
import '../core/app_status_badge.dart';
import '../theme/app_spacing.dart';

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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Trip History')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trips.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 48,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No past trips',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            )
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
                      leading: CircleAvatar(
                        backgroundColor: cs.primary.withValues(alpha: 0.1),
                        child: Icon(
                          Icons.route_rounded,
                          color: cs.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        t.docNo,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${t.vehicle?.vehiclePlate ?? "N/A"} · ${fmt.format(t.dateEncoded)}',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
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
