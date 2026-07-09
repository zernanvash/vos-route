import 'package:flutter/material.dart';

/// Theme-adaptive text styles.
/// - Static const getters (no context): backward-compat for unmigrated screens.
///   Use these in `const` contexts or when `BuildContext` isn't available.
/// - Static methods ending in `Of(context)`: preferred for migrated screens.
class AppTextStyle {
  AppTextStyle._();

  // ── Static const (legacy compat – dark-mode colors) ───────────────────────
  static const TextStyle heading = TextStyle(
    color: Color(0xFFFAFAFA),
    fontSize: 22,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
  );

  static const TextStyle subheading = TextStyle(
    color: Color(0xFFFAFAFA),
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  static const TextStyle body = TextStyle(
    color: Color(0xFFFAFAFA),
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle caption = TextStyle(
    color: Color(0xFFADADB8),
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle label = TextStyle(
    color: Color(0xFFADADB8),
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
  );

  static const TextStyle sectionHeader = TextStyle(
    color: Color(0xFF3B6EF0),
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  static const TextStyle amount = TextStyle(
    color: Color(0xFFFAFAFA),
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle badge = TextStyle(
    color: Color(0xFFFAFAFA),
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  // ── Context-aware (preferred for migrated screens) ────────────────────────
  static TextStyle headingOf(BuildContext context) => TextStyle(
    color: Theme.of(context).colorScheme.onSurface,
    fontSize: 22,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
  );

  static TextStyle subheadingOf(BuildContext context) => TextStyle(
    color: Theme.of(context).colorScheme.onSurface,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  static TextStyle bodyOf(BuildContext context) => TextStyle(
    color: Theme.of(context).colorScheme.onSurface,
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  static TextStyle captionOf(BuildContext context) => TextStyle(
    color: Theme.of(context).colorScheme.onSurfaceVariant,
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  static TextStyle sectionHeaderOf(BuildContext context) => TextStyle(
    color: Theme.of(context).colorScheme.primary,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  static TextStyle amountOf(BuildContext context) => TextStyle(
    color: Theme.of(context).colorScheme.onSurface,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
