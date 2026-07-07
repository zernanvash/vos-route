import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class AppListTile extends StatelessWidget {
  final String label;
  final String? value;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const AppListTile({
    super.key,
    required this.label,
    this.value,
    this.icon,
    this.trailing,
    this.onTap,
    this.labelStyle,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: AppColors.textSecondary),
              Insets.gapWSm,
            ],
            SizedBox(
              width: 120,
              child: Text(
                label,
                style:
                    labelStyle ??
                    const TextStyle(color: AppColors.textTertiary),
              ),
            ),
            if (value != null)
              Expanded(
                child: Text(
                  value!,
                  style:
                      valueStyle ??
                      const TextStyle(color: AppColors.textPrimary),
                ),
              ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
