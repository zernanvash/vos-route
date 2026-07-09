import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class StatusChip extends StatelessWidget {
  final String status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color statusColor, String label) = _resolve(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: statusColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  (Color, String) _resolve(String status) {
    switch (status) {
      case 'Fulfilled':
        return (AppColors.fulfilled, 'Fulfilled');
      case 'Not Fulfilled':
        return (AppColors.notFulfilled, 'Not Fulfilled');
      case 'Fulfilled with Returns':
        return (AppColors.fulfilledWithReturns, 'With Returns');
      case 'Fulfilled with Concerns':
        return (AppColors.fulfilledWithConcerns, 'With Concerns');
      case 'In Progress':
        return (AppColors.info, 'In Progress');
      case 'Pending':
        return (AppColors.pending, 'Pending');
      case 'For Dispatch':
        return (AppColors.forDispatch, 'For Dispatch');
      case 'For Inbound':
        return (AppColors.forInbound, 'For Inbound');
      case 'For Clearance':
        return (AppColors.forClearance, 'For Clearance');
      case 'Posted':
        return (AppColors.posted, 'Posted');
      case 'Cancelled':
        return (AppColors.pending, 'Cancelled');
      default:
        return (AppColors.pending, status);
    }
  }
}
