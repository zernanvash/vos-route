import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/action_queue_provider.dart';
import '../models/action_entry.dart';
import '../theme/app_colors.dart';

class SyncLogScreen extends StatefulWidget {
  const SyncLogScreen({super.key});

  @override
  State<SyncLogScreen> createState() => _SyncLogScreenState();
}

class _SyncLogScreenState extends State<SyncLogScreen> {
  List<ActionEntry> _actions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final actions = await context.read<ActionQueueProvider>().getActions();
    if (mounted) {
      setState(() {
        _actions = actions;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Log'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
          if (_actions.any((a) => a.status == ActionStatus.failed))
            TextButton(
              onPressed: () async {
                await context.read<ActionQueueProvider>().retryFailed();
                await _load();
              },
              child: const Text('Retry All'),
            ),
          if (_actions.any((a) => a.status == ActionStatus.failed))
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear Failed'),
                    content: const Text(
                      'Remove all permanently failed items from the queue?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await context.read<ActionQueueProvider>().clearFailed();
                  await _load();
                }
              },
              child: const Text('Clear Failed'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _actions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_done_rounded,
                    size: 56,
                    color: AppColors.success,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'All synced',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No pending or failed items',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _actions.length,
                itemBuilder: (context, index) {
                  final entry = _actions[index];
                  return _buildActionCard(context, entry);
                },
              ),
            ),
    );
  }

  Widget _buildActionCard(BuildContext context, ActionEntry entry) {
    final cs = Theme.of(context).colorScheme;
    final isPending = entry.status == ActionStatus.pending;
    final isFailed = entry.status == ActionStatus.failed;

    final Color statusColor;
    final String statusLabel;
    final IconData statusIcon;

    if (isPending) {
      statusColor = AppColors.warning;
      statusLabel = 'Pending';
      statusIcon = Icons.sync_rounded;
    } else if (isFailed) {
      statusColor = AppColors.error;
      statusLabel = 'Failed';
      statusIcon = Icons.error_rounded;
    } else {
      statusColor = AppColors.success;
      statusLabel = 'Completed';
      statusIcon = Icons.check_circle_rounded;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _labelForType(entry.actionType),
                    style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (entry.lastError != null) ...[
              const SizedBox(height: 6),
              InkWell(
                onTap: () => _copyError(entry.lastError!),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          entry.lastError!,
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.copy_rounded,
                        size: 16,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              entry.endpoint,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
            ),
            if (entry.retryCount > 0) ...[
              const SizedBox(height: 2),
              Text(
                'Retries: ${entry.retryCount}',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
              ),
            ],
            if (isFailed)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () async {
                    await context.read<ActionQueueProvider>().retryAction(
                      entry.id!,
                    );
                    await _load();
                  },
                  child: const Text('Retry'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyError(String error) async {
    await Clipboard.setData(ClipboardData(text: error));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sync error copied to clipboard')),
    );
  }

  String _labelForType(ActionType actionType) {
    switch (actionType) {
      case ActionType.gpsBatch:
        return 'GPS Log Batch';
      case ActionType.linkPodPhoto:
        return 'POD Photo';
      case ActionType.linkTripPhoto:
        return 'Trip Photo';
      case ActionType.submitSos:
        return 'SOS Report';
      case ActionType.updateStopStatus:
        return 'Stop Status Update';
      case ActionType.addAdHocStop:
        return 'Ad-Hoc Stop';
      case ActionType.confirmDeparture:
        return 'Trip Departure';
      case ActionType.markArrived:
        return 'Trip Arrival';
      case ActionType.updateInvoicesDeparture:
        return 'Invoice Departure Update';
      case ActionType.updateOrdersDeparture:
        return 'Order Departure Update';
    }
  }
}
