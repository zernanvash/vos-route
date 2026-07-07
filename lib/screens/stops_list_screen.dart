import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/trip_provider.dart';
import '../models/stop.dart';
import '../widgets/stop_card.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/app_colors.dart';
import '../core/app_card.dart';
import '../core/app_status_badge.dart';
import '../core/app_section_header.dart';

class StopsListScreen extends StatelessWidget {
  const StopsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Stops', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          Consumer<TripProvider>(
            builder: (context, trip, _) {
              if (trip.selectedPlan == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: Insets.lg),
                child: Center(
                  child: Text(
                    '${trip.completedStops} / ${trip.totalStops} Done',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
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
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(Insets.xxl),
                child: AppCard(
                  child: Padding(
                    padding: EdgeInsets.all(Insets.lg),
                    child: Text(
                      'Please select a dispatch plan from Home',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textTertiary),
                    ),
                  ),
                ),
              ),
            );
          }

          final groups = trip.groupedStops;
          final hasInvoiceStops = groups.isNotEmpty;
          final hasPurchaseStops = trip.purchaseStops.isNotEmpty;
          final hasOtherStops = trip.otherStops.isNotEmpty;
          final hasStops = hasInvoiceStops || hasPurchaseStops || hasOtherStops;

          if (!hasStops) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(Insets.xxl),
                child: Text(
                  'No stops loaded for this plan',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textTertiary),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => trip.fetchActiveTrip(forceRefresh: true),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: Insets.sm),
              children: [
                if (hasInvoiceStops) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: Insets.lg,
                      vertical: Insets.sm,
                    ),
                    child: AppSectionHeader(title: 'Delivery Stops'),
                  ),
                  ...groups.map(
                    (group) => _CustomerGroupCard(group: group, trip: trip),
                  ),
                ],
                if (hasPurchaseStops) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(
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
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: Insets.lg,
                      vertical: Insets.sm,
                    ),
                    child: AppSectionHeader(title: 'Other Stops'),
                  ),
                  ...trip.otherStops.map(
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
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CustomerGroupCard extends StatelessWidget {
  final StopGroup group;
  final TripProvider trip;

  const _CustomerGroupCard({required this.group, required this.trip});

  @override
  Widget build(BuildContext context) {
    final hasCoords = group.latitude != null && group.longitude != null;
    return AppCard(
      margin: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.xs,
      ),
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: !group.allTerminal,
        tilePadding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.xs,
        ),
        childrenPadding: const EdgeInsets.only(bottom: Insets.sm),
        leading: CircleAvatar(
          backgroundColor: group.allTerminal
              ? (group.allFulfilled
                    ? AppColors.successDark
                    : AppColors.errorDark)
              : AppColors.primaryDark,
          radius: 18,
          child: Text(
            '${group.totalStops}',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
        title: Text(
          group.customerName ?? group.customerCode,
          style: AppTextStyle.subheading,
        ),
        subtitle: hasCoords
            ? Row(
                children: const [
                  Icon(Icons.location_on, size: 11, color: AppColors.success),
                  SizedBox(width: 3),
                  Text(
                    'Location pinned',
                    style: TextStyle(color: AppColors.success, fontSize: 11),
                  ),
                ],
              )
            : const Text(
                'No coordinates',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
              ),
        trailing: _AggregateIndicator(group: group),
        children: group.stops.map((stop) {
          return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 56, right: Insets.lg),
            title: Text(
              stop.invoiceNo ?? 'INV-#${stop.id}',
              style: AppTextStyle.body,
            ),
            subtitle: stop.amount != null
                ? Text(
                    '₱${stop.amount!.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(child: AppStatusBadge(status: stop.status)),
                const SizedBox(width: 10),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            onTap: () {
              Navigator.pushNamed(context, '/stop-detail', arguments: stop);
            },
          );
        }).toList(),
      ),
    );
  }
}

class _AggregateIndicator extends StatelessWidget {
  final StopGroup group;

  const _AggregateIndicator({required this.group});

  @override
  Widget build(BuildContext context) {
    if (group.allFulfilled) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: Insets.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.successDark,
          borderRadius: BorderRadius.circular(Insets.cardRadius),
        ),
        child: const Icon(Icons.check, size: 14, color: AppColors.success),
      );
    }

    if (group.allNotFulfilled) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: Insets.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.errorDark,
          borderRadius: BorderRadius.circular(Insets.cardRadius),
        ),
        child: Text(
          '${group.notFulfilledCount}',
          style: const TextStyle(
            color: AppColors.error,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (group.hasMixed) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: Insets.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.warningDark,
          borderRadius: BorderRadius.circular(Insets.cardRadius),
        ),
        child: Text(
          '${group.totalStops - group.fulfilledCount}',
          style: const TextStyle(
            color: AppColors.warning,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: Insets.xs),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(Insets.cardRadius),
      ),
      child: Text(
        '${group.totalStops}',
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
