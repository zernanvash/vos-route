import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class StatusChip extends StatelessWidget {
  final String status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color statusColor, String label) = _resolve(
      status,
      Theme.of(context).brightness,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: statusColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  (Color, String) _resolve(String status, Brightness brightness) {
    switch (status) {
      case 'Fulfilled':
        return (AppColors.successFor(brightness), 'Fulfilled');
      case 'Not Fulfilled':
        return (AppColors.errorFor(brightness), 'Not Fulfilled');
      case 'Fulfilled with Returns':
        return (AppColors.warningFor(brightness), 'With Returns');
      case 'Fulfilled with Concerns':
        return (AppColors.clearanceFor(brightness), 'With Concerns');
      case 'In Progress':
        return (AppColors.infoFor(brightness), 'In Progress');
      case 'Pending':
        return (AppColors.pending, 'Pending');
      case 'For Dispatch':
        return (AppColors.infoFor(brightness), 'For Dispatch');
      case 'For Inbound':
        return (AppColors.warningFor(brightness), 'For Inbound');
      case 'For Clearance':
        return (AppColors.clearanceFor(brightness), 'For Clearance');
      case 'Posted':
        return (AppColors.successFor(brightness), 'Posted');
      case 'Cancelled':
        return (AppColors.pending, 'Cancelled');
      default:
        return (AppColors.pending, status);
    }
  }
}
