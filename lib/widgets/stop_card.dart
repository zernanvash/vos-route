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
      color: AppColors.surface,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary,
          child: Text('$sequence', style: const TextStyle(color: Colors.white)),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (hasCoords) ...[
              const SizedBox(width: 6),
              const Icon(Icons.location_on, size: 14, color: AppColors.success),
            ],
          ],
        ),
        subtitle: subtitle.isNotEmpty
            ? Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              )
            : null,
        trailing: StatusChip(status: status),
        onTap: onTap,
      ),
    );
  }
}
