import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/trip.dart';
import '../providers/trip_provider.dart';
import '../providers/gps_provider.dart';
import '../theme/app_spacing.dart';
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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(title: const Text('Dispatch Plans')),
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
                _noActiveTripCard(context),
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
    final cs = Theme.of(context).colorScheme;

    final showDeparture =
        t.status == 'For Dispatch' &&
        (trip.activeTrip == null || trip.activeTrip?.id == t.id);
    final showArrival =
        t.status == 'For Inbound' && trip.activeTrip?.id == t.id;

    return [
      if (trip.activeTrip != null && t.id != trip.activeTrip?.id)
        GestureDetector(
          onTap: () => trip.selectPlan(trip.activeTrip!),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.arrow_back_rounded, color: cs.primary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Viewing another plan. Tap to return to active trip.',
                    style: TextStyle(color: cs.primary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      AppGradientHeader(
        title: t.docNo,
        trailing: t.status,
        leadingIcon: Icons.directions_car_rounded,
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
        context: context,
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
        context: context,
        title: 'Crew',
        children: t.crew.isEmpty
            ? [
                ListTile(
                  title: Text(
                    'No crew assigned',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ]
            : t.crew
                  .map(
                    (c) => ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.person_rounded,
                        color: cs.onSurfaceVariant,
                      ),
                      title: Text(
                        c.name ?? 'Crew #${c.userId}',
                        style: TextStyle(color: cs.onSurface),
                      ),
                      subtitle: Text(
                        c.role,
                        style: TextStyle(color: cs.onSurfaceVariant),
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
            Text(
              'Stop Progress',
              style: TextStyle(
                color: cs.primary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
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

  Widget _noActiveTripCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'No active dispatch plan',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
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
        ...trip.pendingPlans.map((p) => _pendingPlanTile(context, p)),
      ],
    );
  }

  Widget _pendingPlanTile(BuildContext context, PostDispatchPlan p) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.route_rounded, color: cs.primary, size: 26),
        title: Text(
          p.docNo,
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          p.vehicle?.vehiclePlate ?? 'No vehicle assigned',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
        ),
        trailing: AppStatusBadge(status: p.status),
      ),
    );
  }

  void _confirmDeparture(BuildContext context, PostDispatchPlan plan) async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!context.mounted) return;
    if (!enabled) {
      AppDialog.showConfirm(
        context,
        title: 'GPS Required',
        message: 'Please turn on your device GPS before starting the trip.',
        confirmLabel: 'OK',
        onConfirm: () {},
      );
      return;
    }

    AppDialog.showConfirm(
      context,
      title: 'Confirm Departure',
      message: 'Are you sure you want to proceed?',
      remarksHint: 'Remarks (Optional)',
      onConfirmWithRemarks: (remarks) {
        final trip = context.read<TripProvider>();
        final gps = context.read<GpsProvider>();
        trip.confirmDeparture(plan: plan, remarks: remarks).then((_) {
          if (!context.mounted) return;
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
