import 'package:flutter/material.dart';

/// VOS brand color palette — matches SCM web `globals.css`
///
/// Light:  --background: hsl(240 6% 98.5%)   --card: hsl(0 0% 100%)
///         --primary:    hsl(224 76% 48%)
/// Dark:   --background: hsl(240 10% 3.2%)   --card: hsl(240 8% 6.5%)
///         --primary:    hsl(224 76% 56%)
class AppColors {
  AppColors._();

  // ── Brand ──────────────────────────────────────────────────────────────
  /// VOS brand blue – light mode primary (hsl 224 76% 48%)
  static const Color primaryLight = Color(0xFF1D4ED8);

  /// VOS brand blue – dark mode primary (hsl 224 76% 56%)
  static const Color primaryDark = Color(0xFF3B6EF0);

  // ── Gradient ────────────────────────────────────────────────────────────
  static const List<Color> brandGradientDark = [
    Color(0xFF1A3FBD),
    Color(0xFF1D4ED8),
  ];
  static const List<Color> brandGradientLight = [
    Color(0xFF1D4ED8),
    Color(0xFF3B6EF0),
  ];

  // ── Surfaces – DARK (hsl values from VOS web .dark) ────────────────────
  /// hsl(240 10% 3.2%) – deepest background
  static const Color darkBackground = Color(0xFF080810);

  /// hsl(240 8% 6.5%) – card surface
  static const Color darkSurface = Color(0xFF0F0F1A);

  /// hsl(240 5% 12%) – secondary surface
  static const Color darkSurfaceVariant = Color(0xFF1A1A22);

  /// hsl(240 5% 12.5%) – accent/hover surface
  static const Color darkSurfaceElevated = Color(0xFF1C1C25);

  /// hsl(240 4% 14%) – borders
  static const Color darkBorder = Color(0xFF1F1F27);

  // ── Surfaces – LIGHT (hsl values from VOS web :root) ───────────────────
  /// hsl(240 6% 98.5%) – page background
  static const Color lightBackground = Color(0xFFF7F7FB);

  /// hsl(0 0% 100%) – card surface
  static const Color lightSurface = Color(0xFFFFFFFF);

  /// hsl(240 6% 96.5%) – secondary surface / muted
  static const Color lightSurfaceVariant = Color(0xFFF2F2F7);

  /// hsl(240 6% 96%) – accent hover
  static const Color lightSurfaceElevated = Color(0xFFF0F0F6);

  /// hsl(240 6% 88%) – borders
  static const Color lightBorder = Color(0xFFDDDDE8);

  // ── Text – dark theme ───────────────────────────────────────────────────
  static const Color darkTextPrimary = Color(0xFFFAFAFA);
  static const Color darkTextSecondary = Color(0xFFADADB8);
  static const Color darkTextTertiary = Color(0xFF6B6B7A);

  // ── Text – light theme ──────────────────────────────────────────────────
  static const Color lightTextPrimary = Color(0xFF0A0A10);
  static const Color lightTextSecondary = Color(0xFF4A4A5A);
  static const Color lightTextTertiary = Color(0xFF8A8A9A);

  // ── Status (same on both themes, vivid enough for both) ─────────────────
  static const Color fulfilled = Color(0xFF22C55E); // green-500
  static const Color notFulfilled = Color(0xFFEF4444); // red-500
  static const Color fulfilledWithReturns = Color(0xFFF97316); // orange-500
  static const Color fulfilledWithConcerns = Color(0xFFEAB308); // yellow-500
  static const Color pending = Color(0xFF71717A); // zinc-500

  // ── Trip status ─────────────────────────────────────────────────────────
  static const Color forDispatch = Color(0xFF3B82F6); // blue-500
  static const Color forInbound = Color(0xFFF97316); // orange-500
  static const Color forClearance = Color(0xFFEAB308); // yellow-500
  static const Color posted = Color(0xFF22C55E); // green-500

  // ── Semantic ────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color successDark = Color(0xFF166534);
  static const Color error = Color(0xFFEF4444);
  static const Color errorDark = Color(0xFF991B1B);
  static const Color warning = Color(0xFFF97316);
  static const Color warningDark = Color(0xFF9A3412);
  static const Color info = Color(0xFF3B82F6);

  // ── Legacy compat aliases (for screens not yet fully migrated) ───────────
  /// Use Theme.of(context).colorScheme.surface in new code
  static const Color surface = darkSurface;

  /// Use Theme.of(context).colorScheme.surfaceContainerHigh in new code
  static const Color surfaceVariant = darkSurfaceVariant;

  /// Use Theme.of(context).colorScheme.onSurface in new code
  static const Color textPrimary = darkTextPrimary;

  /// Use Theme.of(context).colorScheme.onSurfaceVariant in new code
  static const Color textSecondary = darkTextSecondary;

  /// Use Theme.of(context).colorScheme.onSurfaceVariant in new code
  static const Color textTertiary = darkTextTertiary;

  /// Use Theme.of(context).colorScheme.outlineVariant in new code
  static const Color border = darkBorder;

  /// Use Theme.of(context).colorScheme.primary in new code
  static const Color primary = primaryDark;
}

extension AppColorExtension on String {
  Color get toInvoiceStatusColor {
    switch (this) {
      case 'Fulfilled':
        return AppColors.fulfilled;
      case 'Not Fulfilled':
        return AppColors.notFulfilled;
      case 'Fulfilled with Returns':
        return AppColors.fulfilledWithReturns;
      case 'Fulfilled with Concerns':
        return AppColors.fulfilledWithConcerns;
      default:
        return AppColors.pending;
    }
  }

  Color get toTripStatusColor {
    switch (this) {
      case 'For Dispatch':
        return AppColors.forDispatch;
      case 'For Inbound':
        return AppColors.forInbound;
      case 'For Clearance':
        return AppColors.forClearance;
      case 'Posted':
        return AppColors.posted;
      default:
        return AppColors.pending;
    }
  }
}
