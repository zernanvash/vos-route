import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  final String status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = _colors(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  (Color, Color) _colors(String status) {
    switch (status) {
      case 'Fulfilled':
        return (Colors.green.shade800, Colors.green.shade200);
      case 'Not Fulfilled':
        return (Colors.red.shade800, Colors.red.shade200);
      case 'Fulfilled with Returns':
        return (Colors.orange.shade800, Colors.orange.shade200);
      case 'Fulfilled with Concerns':
        return (Colors.amber.shade800, Colors.amber.shade200);
      case 'In Progress':
        return (Colors.blue.shade800, Colors.blue.shade200);
      case 'Pending':
        return (Colors.grey.shade800, Colors.grey.shade400);
      case 'For Dispatch':
        return (Colors.blue.shade800, Colors.blue.shade200);
      case 'For Inbound':
        return (Colors.teal.shade800, Colors.teal.shade200);
      case 'For Clearance':
        return (Colors.purple.shade800, Colors.purple.shade200);
      case 'Posted':
        return (Colors.green.shade800, Colors.green.shade200);
      case 'Cancelled':
        return (Colors.grey.shade700, Colors.grey.shade400);
      default:
        return (Colors.grey.shade800, Colors.grey.shade400);
    }
  }
}
