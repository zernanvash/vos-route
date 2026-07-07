import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class AppInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const AppInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyle.body.copyWith(color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: AppTextStyle.body.copyWith(
              color: valueColor ?? AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final List<Color>? gradient;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final double? height;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.gradient,
    this.color,
    this.borderColor,
    this.borderWidth = 0,
    this.height,
    this.onTap,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius =
        borderRadius ?? BorderRadius.circular(Insets.cardRadius);

    Widget card;
    if (gradient != null || borderColor != null) {
      card = Container(
        height: height,
        margin: margin ?? EdgeInsets.zero,
        padding: padding ?? Insets.cardLg,
        decoration: BoxDecoration(
          color: gradient != null ? null : (color ?? AppColors.surface),
          gradient: gradient != null ? LinearGradient(colors: gradient!) : null,
          borderRadius: effectiveBorderRadius,
          border: borderColor != null
              ? Border.all(color: borderColor!, width: borderWidth)
              : null,
        ),
        child: child,
      );
    } else {
      card = Card(
        color: color ?? AppColors.surface,
        margin: margin ?? EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: effectiveBorderRadius),
        child: Padding(padding: padding ?? Insets.cardLg, child: child),
      );
    }

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: effectiveBorderRadius,
        child: card,
      );
    }

    return card;
  }

  static AppCard info({
    required String title,
    required List<Widget> children,
    EdgeInsetsGeometry? padding,
  }) {
    return AppCard(
      padding: padding ?? Insets.cardLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyle.sectionHeader),
          Insets.gapSm,
          ...children,
        ],
      ),
    );
  }
}
