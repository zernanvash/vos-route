import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class AppStatusBadge extends StatelessWidget {
  final String status;
  final Color? color;
  final double fontSize;

  const AppStatusBadge({
    super.key,
    required this.status,
    this.color,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = color ?? status.toTripStatusColor;
    return Container(
      padding: Insets.badgeSm,
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(Insets.badgeRadius),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: badgeColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
