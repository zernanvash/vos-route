import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/trip_provider.dart';
import '../models/stop.dart';
import '../theme/app_spacing.dart';
import '../theme/app_colors.dart';
import '../core/app_card.dart';
import '../core/app_status_badge.dart';
import 'invoice_detail_screen.dart';

class InvoicesScreen extends StatelessWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Invoices'),
      ),
      body: Consumer<TripProvider>(
        builder: (context, trip, _) {
          final groups = trip.groupedStops;

          if (groups.isEmpty) {
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
                          Icons.receipt_long_outlined,
                          size: 40,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No invoices loaded for this plan',
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

          final totalInvoices =
              groups.fold(0, (sum, g) => sum + g.totalStops);
          final terminalInvoices =
              groups.fold(0, (sum, g) => sum + g.terminalCount);
          final allTerminal = terminalInvoices == totalInvoices && totalInvoices > 0;

          return RefreshIndicator(
            onRefresh: () => trip.fetchActiveTrip(forceRefresh: true),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.lg, Insets.sm, Insets.lg, Insets.sm,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '$terminalInvoices / $totalInvoices Done',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${groups.length} customers',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: Insets.sm),
                    children: groups.map(
                      (group) => _InvoiceGroupCard(group: group),
                    ).toList(),
                  ),
                ),
                _ConfirmBar(trip: trip, allTerminal: allTerminal),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InvoiceGroupCard extends StatelessWidget {
  final StopGroup group;

  const _InvoiceGroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
        trailing: _AggregateIndicator(group: group),
        children: group.stops.map((stop) {
          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InvoiceDetailScreen(stop: stop),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(left: 56, right: Insets.md),
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            stop.invoiceNo ?? 'INV-#${stop.id}',
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 14,
                            ),
                          ),
                          if (stop.amount != null)
                            Text(
                              '₱${stop.amount!.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                    AppStatusBadge(status: stop.status),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
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

class _ConfirmBar extends StatelessWidget {
  final TripProvider trip;
  final bool allTerminal;

  const _ConfirmBar({required this.trip, required this.allTerminal});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (trip.invoicesConfirmed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          border: Border(
            top: BorderSide(color: AppColors.success.withValues(alpha: 0.3)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 20, color: AppColors.success),
            const SizedBox(width: 8),
            Text(
              'Invoices Confirmed',
              style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.md,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: Insets.buttonHeight,
        child: ElevatedButton.icon(
          onPressed: allTerminal
              ? () {
                  trip.confirmInvoices();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invoices confirmed. You can now mark arrived at base.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              : null,
          icon: const Icon(Icons.checklist_rounded),
          label: Text(
            allTerminal
                ? 'Confirm Invoices'
                : 'Complete all invoice statuses first',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: allTerminal ? AppColors.primaryLight : null,
            foregroundColor: Colors.white,
            disabledForegroundColor: cs.onSurfaceVariant,
            disabledBackgroundColor: cs.surfaceContainerHighest,
          ),
        ),
      ),
    );
  }
}
