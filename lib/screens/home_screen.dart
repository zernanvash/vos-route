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
import '../theme/app_typography.dart';
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
  int _touchedIndex = -1;

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
    return Scaffold(
      backgroundColor: Colors.black,
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
                        Insets.gapLg,
                        _performanceSection(trip),
                        Insets.gapLg,
                        _questProgressSection(trip),
                        Insets.gapLg,
                        _dpQueueSection(trip),
                        Insets.gapLg,
                        _gpsStatusCard(context),
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
            radius: 28,
            backgroundColor: Colors.white24,
            child: const Icon(Icons.person, color: Colors.white, size: 32),
          ),
          title: p != null ? '${p.firstName} ${p.lastName}' : 'Driver',
          subtitle: p?.email ?? 'Tap sync to refresh',
        );
      },
    );
  }

  Widget _performanceSection(TripProvider trip) {
    final counts = trip.invoiceStatusCounts;
    final total = counts.values.fold(0, (a, b) => a + b);

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
      if (count > 0) {
        activeStatuses.add(MapEntry(status, count));
      }
    }

    final hasSelection =
        _touchedIndex >= 0 && _touchedIndex < activeStatuses.length;
    final centerLabel = hasSelection
        ? activeStatuses[_touchedIndex].key
        : 'Total Stops';
    final centerValue = hasSelection
        ? '${activeStatuses[_touchedIndex].value}'
        : '$total';
    final centerColor = hasSelection
        ? _getInvoiceStatusColor(activeStatuses[_touchedIndex].key)
        : AppColors.primary;

    return AppCard.info(
      title: 'Performance',
      children: [
        if (total == 0)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No active dispatch plan',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          Row(
            children: [
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 160,
                  child: Stack(
                    children: [
                      PieChart(_pieChartData(counts, total, activeStatuses)),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              centerLabel,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Insets.gapXs,
                            Text(
                              centerValue,
                              style: TextStyle(
                                color: centerColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Insets.gapWSm,
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legendItem(
                      'Fulfilled',
                      counts['Fulfilled']!,
                      Colors.green,
                    ),
                    _legendItem(
                      'Not Fulfilled',
                      counts['Not Fulfilled']!,
                      Colors.red,
                    ),
                    _legendItem(
                      'With Returns',
                      counts['Fulfilled with Returns']!,
                      Colors.orange,
                    ),
                    _legendItem(
                      'With Concerns',
                      counts['Fulfilled with Concerns']!,
                      Colors.amber,
                    ),
                    _legendItem('Pending', counts['Pending']!, Colors.grey),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Color _getInvoiceStatusColor(String status) {
    switch (status) {
      case 'Fulfilled':
        return Colors.green;
      case 'Not Fulfilled':
        return Colors.red;
      case 'Fulfilled with Returns':
        return Colors.orange;
      case 'Fulfilled with Concerns':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  PieChartData _pieChartData(
    Map<String, int> counts,
    int total,
    List<MapEntry<String, int>> activeStatuses,
  ) {
    final sections = <PieChartSectionData>[];
    for (int i = 0; i < activeStatuses.length; i++) {
      final entry = activeStatuses[i];
      final isTouched = i == _touchedIndex;
      sections.add(
        PieChartSectionData(
          value: entry.value.toDouble(),
          color: _getInvoiceStatusColor(entry.key),
          title: isTouched ? '${entry.value}' : '',
          radius: isTouched ? 46.0 : 36.0,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return PieChartData(
      sections: sections,
      centerSpaceRadius: 44,
      sectionsSpace: 2,
      pieTouchData: PieTouchData(
        touchCallback: (FlTouchEvent event, pieTouchResponse) {
          setState(() {
            if (!event.isInterestedForInteractions ||
                pieTouchResponse == null ||
                pieTouchResponse.touchedSection == null) {
              _touchedIndex = -1;
              return;
            }
            _touchedIndex =
                pieTouchResponse.touchedSection!.touchedSectionIndex;
          });
        },
      ),
    );
  }

  Widget _legendItem(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Insets.gapWSm,
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _questProgressSection(TripProvider trip) {
    final quest = trip.currentQuest;
    if (quest == null) return const SizedBox.shrink();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.camera_alt, color: AppColors.primary, size: 20),
              Insets.gapWSm,
              Text('Photo Quest', style: AppTextStyle.sectionHeader),
              const Spacer(),
              Text(
                quest.progressLabel,
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
              ),
            ],
          ),
          Insets.gapMd,
          AppProgressBar(value: quest.progress),
          Insets.gapSm,
          Text(
            '${quest.photosCaptured} photos · ${quest.signaturesCaptured} signatures',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
          ),
          if (!quest.allComplete) ...[
            Insets.gapSm,
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

  Widget _dpQueueSection(TripProvider trip) {
    final plans = <PostDispatchPlan>[];
    if (trip.activeTrip != null) plans.add(trip.activeTrip!);
    plans.addAll(trip.pendingPlans);

    return AppCard.info(
      title: 'Dispatch Queue',
      children: [
        if (plans.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'No assigned dispatch plans',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ...plans.map(
            (p) => _queueTile(p, isActive: p.id == trip.activeTrip?.id),
          ),
      ],
    );
  }

  Widget _queueTile(PostDispatchPlan p, {required bool isActive}) {
    return GestureDetector(
      onTap: () => context.read<TripProvider>().selectPlan(p),
      child: AppCard(
        margin: const EdgeInsets.only(bottom: 8),
        color: isActive
            ? Colors.blue.shade900.withValues(alpha: 0.3)
            : AppColors.surfaceVariant,
        borderColor: isActive ? Colors.blue.shade700 : null,
        borderWidth: isActive ? 1 : 0,
        padding: Insets.cardInner,
        child: Row(
          children: [
            Icon(
              isActive ? Icons.local_shipping : Icons.route,
              color: isActive ? AppColors.primary : AppColors.textTertiary,
              size: 24,
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade700,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'ACTIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Insets.gapXs,
                  Text(
                    p.vehicle?.vehiclePlate ?? 'No vehicle',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
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

  Widget _gpsStatusCard(BuildContext context) {
    return Consumer<GpsProvider>(
      builder: (context, gps, _) {
        return AppCard(
          child: Row(
            children: [
              Icon(
                gps.isTracking ? Icons.gps_fixed : Icons.gps_off,
                color: gps.isTracking
                    ? Colors.green.shade400
                    : AppColors.textTertiary,
                size: 28,
              ),
              Insets.gapWSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GPS Tracking',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    Text(
                      gps.isTracking
                          ? 'Active — logging every ${AppConfig.gpsIntervalSeconds}s'
                          : 'Inactive — starts when trip departs',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
