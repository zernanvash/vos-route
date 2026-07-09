import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

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
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? cs.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 13,
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
    final cs = Theme.of(context).colorScheme;
    final effectiveBorderRadius =
        borderRadius ?? BorderRadius.circular(Insets.cardRadius);
    final effectiveColor = color ?? cs.surface;
    final effectiveBorderColor =
        borderColor ?? cs.outlineVariant.withValues(alpha: 0.6);

    Widget card;
    if (gradient != null || borderColor != null) {
      card = Container(
        height: height,
        margin: margin ?? EdgeInsets.zero,
        padding: padding ?? Insets.cardLg,
        decoration: BoxDecoration(
          color: gradient != null ? null : effectiveColor,
          gradient: gradient != null ? LinearGradient(colors: gradient!) : null,
          borderRadius: effectiveBorderRadius,
          border: Border.all(
            color: gradient != null ? Colors.transparent : effectiveBorderColor,
            width: borderWidth > 0 ? borderWidth : 1,
          ),
        ),
        child: child,
      );
    } else {
      card = Container(
        height: height,
        margin: margin ?? EdgeInsets.zero,
        padding: padding ?? Insets.cardLg,
        decoration: BoxDecoration(
          color: effectiveColor,
          borderRadius: effectiveBorderRadius,
          border: Border.all(color: effectiveBorderColor),
        ),
        child: child,
      );
    }

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: effectiveBorderRadius,
          child: card,
        ),
      );
    }

    return card;
  }

  static Widget info({
    required BuildContext context,
    required String title,
    required List<Widget> children,
    EdgeInsetsGeometry? padding,
  }) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      padding: padding ?? Insets.cardLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: cs.primary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}
