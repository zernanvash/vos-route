import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/trip_provider.dart';
import '../core/app_card.dart';
import '../core/app_status_badge.dart';
import '../theme/app_spacing.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Trip History')),
      body: Consumer<TripProvider>(
        builder: (context, trip, _) {
          final trips = trip.cachedHistory;

          if (trips.isEmpty) {
            return Center(
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
            );
          }

          return RefreshIndicator(
            onRefresh: () => trip.fetchCachedHistory(),
            child: ListView.builder(
              padding: Insets.cardLg,
              itemCount: trips.length,
              itemBuilder: (_, i) {
                final t = trips[i];
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
          );
        },
      ),
    );
  }
}
