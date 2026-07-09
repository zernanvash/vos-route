import 'package:flutter/material.dart';
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
    final cs = Theme.of(context).colorScheme;
    final t = trailing;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: cs.onSurfaceVariant),
              Insets.gapWSm,
            ],
            SizedBox(
              width: 120,
              child: Text(
                label,
                style:
                    labelStyle ??
                    TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
            ),
            if (value != null)
              Expanded(
                child: Text(
                  value!,
                  style:
                      valueStyle ??
                      TextStyle(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                ),
              ),
            if (t != null) t,
          ],
        ),
      ),
    );
  }
}
