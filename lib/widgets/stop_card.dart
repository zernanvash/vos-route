import 'package:flutter/material.dart';
import '../models/stop.dart';
import '../theme/app_colors.dart';
import 'status_chip.dart';

class StopCard extends StatelessWidget {
  final Object stop;
  final int sequence;
  final VoidCallback? onTap;

  const StopCard({
    super.key,
    required this.stop,
    required this.sequence,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final String title;
    final String subtitle;
    final String status;
    final bool hasCoords;

    if (stop is InvoiceStop) {
      final s = stop as InvoiceStop;
      title = s.customerName ?? 'Customer #${s.invoiceId}';
      subtitle =
          'Invoice: ${s.invoiceNo ?? "N/A"}${s.address != null && s.address!.isNotEmpty ? " | ${s.address}" : ""}';
      status = s.status;
      hasCoords = s.latitude != null && s.longitude != null;
    } else if (stop is PurchaseStop) {
      final s = stop as PurchaseStop;
      title = s.supplierName ?? 'Supplier #${s.poId}';
      subtitle = 'PO: ${s.poNo ?? "N/A"}';
      status = s.status;
      hasCoords = false;
    } else if (stop is OtherStop) {
      final s = stop as OtherStop;
      title = s.remarks ?? 'Ad-hoc Stop';
      subtitle = '';
      status = s.status;
      hasCoords = s.latitude != null && s.longitude != null;
    } else {
      title = 'Unknown Stop';
      subtitle = '';
      status = 'Pending';
      hasCoords = false;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.primary.withValues(alpha: 0.15),
          child: Text(
            '$sequence',
            style: TextStyle(
              color: cs.primary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            if (hasCoords) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.location_on_rounded,
                size: 14,
                color: AppColors.success,
              ),
            ],
          ],
        ),
        subtitle: subtitle.isNotEmpty
            ? Text(
                subtitle,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              )
            : null,
        trailing: StatusChip(status: status),
        onTap: onTap,
      ),
    );
  }
}
