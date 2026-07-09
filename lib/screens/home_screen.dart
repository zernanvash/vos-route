import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/trip.dart';
import '../providers/trip_provider.dart';
import '../providers/gps_provider.dart';
import '../providers/auth_provider.dart';
import '../config/app_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../core/app_card.dart';
import '../core/app_action_button.dart';
import '../core/app_status_badge.dart';
import '../core/app_gradient_header.dart';
import '../core/app_progress_bar.dart';
import 'quest_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _initials(String? first, String? last) {
    final f = (first != null && first.isNotEmpty) ? first[0] : '';
    final l = (last != null && last.isNotEmpty) ? last[0] : '';
    final r = '$f$l'.toUpperCase();
    return r.isEmpty ? 'DR' : r;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final trip = context.read<TripProvider>();
      trip.fetchActiveTrip();
      trip.fetchPendingPlans();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Consumer<TripProvider>(
                builder: (context, trip, _) {
                  return RefreshIndicator(
                    onRefresh: () async {
                      await trip.fetchActiveTrip(forceRefresh: true);
                      await trip.fetchPendingPlans();
                    },
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _driverHeader(context),
                        const SizedBox(height: 16),
                        _performanceSection(context, trip),
                        const SizedBox(height: 16),
                        _questProgressSection(context, trip),
                        const SizedBox(height: 16),
                        _dpQueueSection(context, trip),
                        const SizedBox(height: 16),
                        _gpsStatusCard(context),
                        const SizedBox(height: 8),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _driverHeader(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final p = auth.profile;
        return AppGradientHeader(
          leadingWidget: CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              p != null ? _initials(p.firstName, p.lastName) : 'DR',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          title: p != null ? '${p.firstName} ${p.lastName}' : 'Driver',
          subtitle: p?.email ?? '',
        );
      },
    );
  }

  // ── Performance ─────────────────────────────────────────────────────────
  Widget _performanceSection(BuildContext context, TripProvider trip) {
    final counts = trip.aggregatedInvoiceStatusCounts;
    final total = counts.values.fold(0, (a, b) => a + b);
    final cs = Theme.of(context).colorScheme;

    final activeStatuses = <MapEntry<String, int>>[];
    final statuses = [
      'Fulfilled',
      'Not Fulfilled',
      'Fulfilled with Returns',
      'Fulfilled with Concerns',
      'Pending',
    ];
    for (final status in statuses) {
      final count = counts[status] ?? 0;
      if (count > 0) activeStatuses.add(MapEntry(status, count));
    }

    final fulfilledCount = counts['Fulfilled'] ?? 0;
    final completionRate = total > 0
        ? (fulfilledCount / total * 100).round()
        : 0;

    return AppCard(
      padding: Insets.cardLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Performance',
                style: TextStyle(
                  color: cs.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              if (total > 0)
                Text(
                  'Tap chart for details',
                  style: TextStyle(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (total == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.pie_chart_outline_rounded,
                      size: 40,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No active dispatch plan',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            _performancePieChart(
              context,
              counts,
              total,
              activeStatuses,
              completionRate,
            ),
        ],
      ),
    );
  }

  Widget _performancePieChart(
    BuildContext context,
    Map<String, int> counts,
    int total,
    List<MapEntry<String, int>> activeStatuses,
    int completionRate,
  ) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _showPerformanceModal(
        context,
        counts,
        total,
        activeStatuses,
        completionRate,
      ),
      child: Center(
        child: SizedBox(
          height: 180,
          width: 180,
          child: Stack(
            children: [
              PieChart(
                PieChartData(
                  sections: activeStatuses.map((e) {
                    return PieChartSectionData(
                      value: e.value.toDouble(),
                      color: _statusColor(e.key),
                      title: '',
                      radius: 40,
                    );
                  }).toList(),
                  centerSpaceRadius: 56,
                  sectionsSpace: 2,
                  pieTouchData: PieTouchData(enabled: false),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$completionRate%',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$total stops',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPerformanceModal(
    BuildContext context,
    Map<String, int> counts,
    int total,
    List<MapEntry<String, int>> activeStatuses,
    int completionRate,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PerformanceModal(
        counts: counts,
        total: total,
        activeStatuses: activeStatuses,
        completionRate: completionRate,
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Fulfilled':
        return AppColors.fulfilled;
      case 'Not Fulfilled':
        return AppColors.notFulfilled;
      case 'Fulfilled with Returns':
        return AppColors.fulfilledWithReturns;
      case 'Fulfilled with Concerns':
        return AppColors.fulfilledWithConcerns;
      default:
        return AppColors.pending;
    }
  }

  // ── Quest progress ───────────────────────────────────────────────────────
  Widget _questProgressSection(BuildContext context, TripProvider trip) {
    final quest = trip.currentQuest;
    if (quest == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.camera_alt_rounded, color: cs.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Photo Quest',
                style: TextStyle(
                  color: cs.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                quest.progressLabel,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppProgressBar(value: quest.progress),
          const SizedBox(height: 6),
          Text(
            '${quest.photosCaptured} / ${quest.totalCount} photos',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
          if (!quest.allComplete) ...[
            const SizedBox(height: 10),
            AppActionButton.quest(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider.value(
                    value: trip,
                    child: const QuestScreen(),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── DP Queue ─────────────────────────────────────────────────────────────
  Widget _dpQueueSection(BuildContext context, TripProvider trip) {
    final plans = <PostDispatchPlan>[];
    if (trip.activeTrip != null) plans.add(trip.activeTrip!);
    for (final p in trip.pendingPlans) {
      if (plans.every((existing) => existing.id != p.id)) {
        plans.add(p);
      }
    }
    final cs = Theme.of(context).colorScheme;

    return AppCard(
      padding: Insets.cardLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dispatch Queue',
            style: TextStyle(
              color: cs.primary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 12),
          if (plans.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No assigned dispatch plans',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
              ),
            )
          else
            ...plans.map(
              (p) =>
                  _queueTile(context, p, isActive: p.id == trip.activeTrip?.id),
            ),
        ],
      ),
    );
  }

  Widget _queueTile(
    BuildContext context,
    PostDispatchPlan p, {
    required bool isActive,
  }) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => context.read<TripProvider>().selectPlan(p),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: Insets.cardInner,
        decoration: BoxDecoration(
          color: isActive
              ? cs.primary.withValues(alpha: 0.08)
              : cs.surfaceContainer,
          borderRadius: BorderRadius.circular(Insets.cardRadius),
          border: Border.all(
            color: isActive
                ? cs.primary.withValues(alpha: 0.4)
                : cs.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isActive ? Icons.local_shipping_rounded : Icons.route_rounded,
              color: isActive ? cs.primary : cs.onSurfaceVariant,
              size: 22,
            ),
            Insets.gapWSm,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.docNo,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'ACTIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.vehicle?.vehiclePlate ?? 'No vehicle',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
            ),
            Insets.gapWSm,
            AppStatusBadge(status: p.status),
          ],
        ),
      ),
    );
  }

  // ── GPS status ───────────────────────────────────────────────────────────
  Widget _gpsStatusCard(BuildContext context) {
    return Consumer<GpsProvider>(
      builder: (context, gps, _) {
        final cs = Theme.of(context).colorScheme;
        final isTracking = gps.isTracking;
        return AppCard(
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isTracking
                      ? AppColors.success.withValues(alpha: 0.12)
                      : cs.surfaceContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isTracking ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
                  color: isTracking ? AppColors.success : cs.onSurfaceVariant,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GPS Tracking',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isTracking
                          ? 'Active — logging every ${AppConfig.gpsIntervalSeconds}s'
                          : 'Inactive — starts when trip departs',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isTracking ? AppColors.success : cs.outlineVariant,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Performance Detail Modal ─────────────────────────────────────────────────
class _PerformanceModal extends StatefulWidget {
  final Map<String, int> counts;
  final int total;
  final List<MapEntry<String, int>> activeStatuses;
  final int completionRate;

  const _PerformanceModal({
    required this.counts,
    required this.total,
    required this.activeStatuses,
    required this.completionRate,
  });

  @override
  State<_PerformanceModal> createState() => _PerformanceModalState();
}

class _PerformanceModalState extends State<_PerformanceModal> {
  int _touchedIndex = -1;

  Color _statusColor(String status) {
    switch (status) {
      case 'Fulfilled':
        return AppColors.fulfilled;
      case 'Not Fulfilled':
        return AppColors.notFulfilled;
      case 'Fulfilled with Returns':
        return AppColors.fulfilledWithReturns;
      case 'Fulfilled with Concerns':
        return AppColors.fulfilledWithConcerns;
      default:
        return AppColors.pending;
    }
  }

  String _shortLabel(String status) {
    switch (status) {
      case 'Fulfilled with Returns':
        return 'With Returns';
      case 'Fulfilled with Concerns':
        return 'With Concerns';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasSelection =
        _touchedIndex >= 0 && _touchedIndex < widget.activeStatuses.length;
    final selectedEntry = hasSelection
        ? widget.activeStatuses[_touchedIndex]
        : null;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Row(
              children: [
                Text(
                  'Performance',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${widget.completionRate}% fulfilled',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Donut chart (larger, interactive)
            SizedBox(
              height: 220,
              child: Stack(
                children: [
                  PieChart(
                    PieChartData(
                      sections: widget.activeStatuses.asMap().entries.map((e) {
                        final isTouched = e.key == _touchedIndex;
                        return PieChartSectionData(
                          value: e.value.value.toDouble(),
                          color: _statusColor(e.value.key),
                          title: isTouched
                              ? '${(e.value.value / widget.total * 100).round()}%'
                              : '',
                          radius: isTouched ? 62 : 52,
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList(),
                      centerSpaceRadius: 68,
                      sectionsSpace: 2,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                response == null ||
                                response.touchedSection == null) {
                              _touchedIndex = -1;
                              return;
                            }
                            _touchedIndex =
                                response.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          hasSelection
                              ? '${selectedEntry!.value}'
                              : '${widget.total}',
                          style: TextStyle(
                            color: hasSelection
                                ? _statusColor(selectedEntry!.key)
                                : cs.onSurface,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasSelection
                              ? _shortLabel(selectedEntry!.key)
                              : 'Total Stops',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Divider
            Divider(color: cs.outlineVariant, height: 1),
            const SizedBox(height: 16),

            // Legend rows
            ...widget.activeStatuses.asMap().entries.map((e) {
              final isSelected = e.key == _touchedIndex;
              final color = _statusColor(
                e.key < widget.activeStatuses.length
                    ? widget.activeStatuses[e.key].key
                    : 'Pending',
              );
              final pct = (e.value.value / widget.total * 100).round();

              return GestureDetector(
                onTap: () =>
                    setState(() => _touchedIndex = isSelected ? -1 : e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? color.withValues(alpha: 0.3)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _shortLabel(e.value.key),
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      Text(
                        '$pct%',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 32,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${e.value.value}',
                          style: TextStyle(
                            color: color,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
