import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/trip.dart';
import '../providers/trip_provider.dart';
import '../providers/gps_provider.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../core/app_card.dart';
import '../core/app_action_button.dart';
import '../core/app_status_badge.dart';
import '../core/app_dialog.dart';
import '../core/app_progress_bar.dart';
import '../core/app_gradient_header.dart';
import '../core/app_section_header.dart';
import 'quest_screen.dart';

class DispatchPlansScreen extends StatelessWidget {
  const DispatchPlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Dispatch Plans',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.grey.shade900,
      ),
      body: SafeArea(
        child: Column(children: [Expanded(child: _body(context))]),
      ),
    );
  }

  Widget _body(BuildContext context) {
    return Consumer<TripProvider>(
      builder: (context, trip, _) {
        if (trip.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: () async {
            await trip.fetchActiveTrip();
            await trip.fetchPendingPlans();
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (trip.selectedPlan != null)
                ..._activeTripSection(context, trip)
              else
                _noActiveTripCard(),
              if (trip.pendingPlans.isNotEmpty) ...[
                Insets.gapLg,
                _pendingPlansSection(context, trip),
              ],
            ],
          ),
        );
      },
    );
  }

  List<Widget> _activeTripSection(BuildContext context, TripProvider trip) {
    final t = trip.selectedPlan!;
    final fmt = DateFormat('MMM dd, yyyy HH:mm');

    final showDeparture =
        t.status == 'For Dispatch' &&
        (trip.activeTrip == null || trip.activeTrip?.id == t.id);
    final showArrival =
        t.status == 'For Inbound' && trip.activeTrip?.id == t.id;

    return [
      if (trip.activeTrip != null && t.id != trip.activeTrip?.id)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => trip.selectPlan(trip.activeTrip!),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade900.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade800),
              ),
              child: Row(
                children: [
                  Icon(Icons.arrow_back, color: Colors.blue.shade300, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Viewing historical/pending plan. Tap to view active trip.',
                      style: TextStyle(
                        color: Colors.blue.shade300,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      AppGradientHeader(
        title: t.docNo,
        trailing: t.status,
        leadingIcon: Icons.directions_car,
        leadingText: t.vehicle?.vehiclePlate ?? 'N/A',
      ),
      Insets.gapLg,
      if (showDeparture)
        AppActionButton.departure(
          onPressed: () => _confirmDeparture(context, t),
        ),
      if (showArrival) Insets.gapMd,
      if (showArrival)
        AppActionButton.quest(onPressed: () => _openQuest(context)),
      if (showArrival) Insets.gapSm,
      if (showArrival)
        AppActionButton.arrival(onPressed: () => _markArrived(context, t)),
      Insets.gapLg,
      AppCard.info(
        title: 'Trip Details',
        children: [
          AppInfoRow(label: 'Doc No', value: t.docNo),
          AppInfoRow(label: 'Vehicle', value: t.vehicle?.vehiclePlate ?? 'N/A'),
          AppInfoRow(label: 'Status', value: t.status),
          if (t.startingPoint != null)
            AppInfoRow(label: 'Starting Point', value: t.startingPoint!),
          if (t.estimatedTimeOfDispatch != null)
            AppInfoRow(
              label: 'Est. Departure',
              value: fmt.format(t.estimatedTimeOfDispatch!),
            ),
          if (t.estimatedTimeOfArrival != null)
            AppInfoRow(
              label: 'Est. Arrival',
              value: fmt.format(t.estimatedTimeOfArrival!),
            ),
          if (t.timeOfDispatch != null)
            AppInfoRow(label: 'Departed', value: fmt.format(t.timeOfDispatch!)),
          if (t.timeOfArrival != null)
            AppInfoRow(label: 'Arrived', value: fmt.format(t.timeOfArrival!)),
        ],
      ),
      Insets.gapMd,
      AppCard.info(
        title: 'Crew',
        children: t.crew.isEmpty
            ? [
                ListTile(
                  title: Text(
                    'No crew assigned',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ),
              ]
            : t.crew
                  .map(
                    (c) => ListTile(
                      dense: true,
                      leading: Icon(Icons.person, color: Colors.grey.shade400),
                      title: Text(
                        c.name ?? 'Crew #${c.userId}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        c.role,
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ),
                  )
                  .toList(),
      ),
      Insets.gapMd,
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stop Progress', style: AppTextStyle.sectionHeader),
            Insets.gapMd,
            AppProgressInfo(
              completed: trip.completedStops,
              total: trip.totalStops,
            ),
          ],
        ),
      ),
    ];
  }

  Widget _noActiveTripCard() {
    return Card(
      color: Colors.grey.shade900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No active dispatch plan',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pendingPlansSection(BuildContext context, TripProvider trip) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: 'Pending Dispatch Plans'),
        Insets.gapSm,
        ...trip.pendingPlans.map((p) => _pendingPlanTile(p)),
      ],
    );
  }

  Widget _pendingPlanTile(PostDispatchPlan p) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.route, color: Colors.blue.shade300, size: 28),
        title: Text(
          p.docNo,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          p.vehicle?.vehiclePlate ?? 'No vehicle assigned',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
        trailing: AppStatusBadge(status: p.status),
      ),
    );
  }

  void _confirmDeparture(BuildContext context, PostDispatchPlan plan) {
    AppDialog.showConfirm(
      context,
      title: 'Confirm Departure',
      message: 'Are you sure you want to proceed?',
      remarksHint: 'Remarks (Optional)',
      onConfirmWithRemarks: (remarks) {
        final trip = context.read<TripProvider>();
        final gps = context.read<GpsProvider>();
        trip.confirmDeparture(plan: plan, remarks: remarks).then((_) {
          if (trip.activeTrip != null) {
            gps.startTracking(trip.activeTrip!.id);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const _QuestWrapper()),
            );
          }
        });
      },
    );
  }

  void _markArrived(BuildContext context, PostDispatchPlan plan) {
    AppDialog.showConfirm(
      context,
      title: 'Mark Arrived at Base',
      message: 'Are you sure you want to proceed?',
      remarksHint: 'Remarks (Optional)',
      onConfirmWithRemarks: (remarks) {
        final trip = context.read<TripProvider>();
        final gps = context.read<GpsProvider>();
        trip
            .markArrivedAtBase(plan: plan, remarks: remarks)
            .then((_) => gps.stopTracking());
      },
    );
  }

  void _openQuest(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _QuestWrapper()),
    );
  }
}

class _QuestWrapper extends StatelessWidget {
  const _QuestWrapper();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: context.read<TripProvider>(),
      child: const QuestScreen(),
    );
  }
}
