import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class AppGradientHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? trailing;
  final Widget? trailingWidget;
  final IconData? leadingIcon;
  final String? leadingText;
  final Widget? leadingWidget;
  final List<Color>? gradient;

  const AppGradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.trailingWidget,
    this.leadingIcon,
    this.leadingText,
    this.leadingWidget,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final colors = gradient ?? AppColors.primaryGradient;
    return Container(
      padding: Insets.allXl,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(Insets.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (trailingWidget != null)
                trailingWidget!
              else if (trailing != null)
                Container(
                  padding: Insets.badgeMd,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(Insets.cardRadius),
                  ),
                  child: Text(
                    trailing!,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
            ],
          ),
          if (subtitle != null ||
              leadingIcon != null ||
              leadingWidget != null) ...[
            Insets.gapSm,
            Row(
              children: [
                if (leadingWidget != null)
                  leadingWidget!
                else ...[
                  if (leadingIcon != null)
                    Icon(leadingIcon, color: Colors.white70, size: 18),
                  if (leadingIcon != null) Insets.gapWSm,
                  if (leadingText != null)
                    Text(
                      leadingText!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                ],
                if (subtitle != null) ...[
                  if (leadingWidget == null && leadingText == null)
                    const Spacer(),
                  const Spacer(),
                  Text(
                    subtitle!,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
