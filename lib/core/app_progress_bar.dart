import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class AppProgressBar extends StatelessWidget {
  final double value;
  final double height;
  final Color? backgroundColor;
  final Color? color;

  const AppProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.backgroundColor,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Insets.smallRadius),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        backgroundColor: backgroundColor ?? cs.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation(color ?? AppColors.success),
        minHeight: height,
      ),
    );
  }
}

class AppProgressInfo extends StatelessWidget {
  final int completed;
  final int total;
  final double? value;
  final double barHeight;

  const AppProgressInfo({
    super.key,
    required this.completed,
    required this.total,
    this.value,
    this.barHeight = 8,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = value ?? (total > 0 ? completed / total : 0.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppProgressBar(value: progress, height: barHeight),
        const SizedBox(height: 8),
        Text(
          '$completed / $total stops completed',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
        ),
      ],
    );
  }
}
