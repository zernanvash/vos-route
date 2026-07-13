import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/trip_provider.dart';
import '../models/stop.dart';
import '../widgets/stop_card.dart';
import '../theme/app_spacing.dart';
import '../core/app_card.dart';
import '../core/app_section_header.dart';

class StopsListScreen extends StatelessWidget {
  const StopsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Stops'),
        actions: [
          Consumer<TripProvider>(
            builder: (context, trip, _) {
              if (trip.selectedPlan == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: Insets.lg),
                child: Center(
                  child: Text(
                    '${trip.completedStops} / ${trip.totalStops} Done',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<TripProvider>(
        builder: (context, trip, _) {
          if (trip.selectedPlan == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(Insets.xxl),
                child: AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(Insets.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 40,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Please select a dispatch plan from Home',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          final hasInvoiceStops = trip.invoiceStops.isNotEmpty;
          final hasPurchaseStops = trip.purchaseStops.isNotEmpty;
          final hasOtherStops = trip.otherStops.isNotEmpty;
          final hasStops = hasInvoiceStops || hasPurchaseStops || hasOtherStops;

          if (!hasStops) {
            return Center(
              child: Text(
                'No stops loaded for this plan',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => trip.fetchActiveTrip(forceRefresh: true),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: Insets.sm),
              children: [
                if (hasInvoiceStops) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Insets.lg,
                      vertical: Insets.sm,
                    ),
                    child: AppSectionHeader(title: 'Delivery Stops'),
                  ),
                  ...trip.invoiceStops.map(
                    (stop) => StopCard(
                      stop: stop,
                      sequence: stop.sequence,
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/stop-detail',
                          arguments: stop,
                        );
                      },
                    ),
                  ),
                ],
                if (hasPurchaseStops) ...[
                  Insets.gapMd,
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Insets.lg,
                      vertical: Insets.sm,
                    ),
                    child: AppSectionHeader(title: 'Pick-up Stops'),
                  ),
                  ...trip.purchaseStops.map(
                    (stop) => StopCard(
                      stop: stop,
                      sequence: stop.sequence,
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/stop-detail',
                          arguments: stop,
                        );
                      },
                    ),
                  ),
                ],
                if (hasOtherStops) ...[
                  Insets.gapMd,
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Insets.lg,
                      vertical: Insets.sm,
                    ),
                    child: AppSectionHeader(title: 'Other Stops'),
                  ),
                  ...trip.otherStops.map(
                    (stop) => StopCard(
                      stop: stop,
                      sequence: stop.sequence,
                      onTap: () => _showOtherStopStatusDialog(context, stop),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

void _showOtherStopStatusDialog(BuildContext context, OtherStop stop) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(stop.remarks ?? 'Other Stop'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Update fulfillment status:'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.read<TripProvider>().updateOtherStopStatus(
                  stop.id,
                  'Fulfilled',
                );
              },
              child: const Text('Fulfilled'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(ctx);
                context.read<TripProvider>().updateOtherStopStatus(
                  stop.id,
                  'Not Fulfilled',
                );
              },
              child: const Text('Not Fulfilled'),
            ),
          ),
        ],
      ),
    ),
  );
}
