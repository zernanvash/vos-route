import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/trip_provider.dart';
import '../models/stop.dart';
import '../widgets/stop_card.dart';
import '../theme/app_spacing.dart';
import '../theme/app_colors.dart';
import '../core/app_card.dart';
import '../core/app_status_badge.dart';
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

          final groups = trip.groupedStops;
          final hasInvoiceStops = groups.isNotEmpty;
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
                  ...groups.map(
                    (group) => _CustomerGroupCard(group: group, trip: trip),
                  ),
                ],
                if (hasPurchaseStops) ...[
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
    final cs = Theme.of(context).colorScheme;
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
                    ? AppColors.success.withValues(alpha: 0.2)
                    : AppColors.error.withValues(alpha: 0.2))
              : cs.primary.withValues(alpha: 0.15),
          radius: 18,
          child: Text(
            '${group.totalStops}',
            style: TextStyle(
              color: group.allTerminal
                  ? (group.allFulfilled ? AppColors.success : AppColors.error)
                  : cs.primary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          group.customerName ?? group.customerCode,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: hasCoords
            ? Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 11,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'Location pinned',
                    style: TextStyle(color: AppColors.success, fontSize: 11),
                  ),
                ],
              )
            : Text(
                'No coordinates',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
              ),
        trailing: _AggregateIndicator(group: group),
        children: group.stops.map((stop) {
          return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 56, right: Insets.lg),
            title: Text(
              stop.invoiceNo ?? 'INV-#${stop.id}',
              style: TextStyle(color: cs.onSurface, fontSize: 14),
            ),
            subtitle: stop.amount != null
                ? Text(
                    '₱${stop.amount!.toStringAsFixed(2)}',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(child: AppStatusBadge(status: stop.status)),
                const SizedBox(width: 10),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: cs.onSurfaceVariant,
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
          color: AppColors.success.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(Insets.cardRadius),
        ),
        child: Icon(Icons.check_rounded, size: 14, color: AppColors.success),
      );
    }

    if (group.allNotFulfilled) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: Insets.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(Insets.cardRadius),
        ),
        child: Text(
          '${group.notFulfilledCount}',
          style: TextStyle(
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
          color: AppColors.warning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(Insets.cardRadius),
        ),
        child: Text(
          '${group.totalStops - group.fulfilledCount}',
          style: TextStyle(
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
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(Insets.cardRadius),
      ),
      child: Text(
        '${group.totalStops}',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
