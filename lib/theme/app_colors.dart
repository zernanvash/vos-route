import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primaryLight = Color(0xFF1D4ED8);
  static const Color primaryDark = Color(0xFF3B6EF0);

  static const List<Color> brandGradientDark = [Color(0xFF1A3FBD), primaryDark];
  static const List<Color> brandGradientLight = [primaryLight, primaryDark];

  static const Color darkBackground = Color(0xFF080810);
  static const Color darkSurface = Color(0xFF0F0F1A);
  static const Color darkSurfaceVariant = Color(0xFF1A1A22);
  static const Color darkSurfaceElevated = Color(0xFF1C1C25);
  static const Color darkBorder = Color(0xFF1F1F27);

  static const Color lightBackground = Color(0xFFF7F7FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF2F2F7);
  static const Color lightSurfaceElevated = Color(0xFFF0F0F6);
  static const Color lightBorder = Color(0xFFDDDDE8);

  static const Color darkTextPrimary = Color(0xFFFAFAFA);
  static const Color darkTextSecondary = Color(0xFFADADB8);
  static const Color darkTextTertiary = Color(0xFF6B6B7A);

  static const Color lightTextPrimary = Color(0xFF0A0A10);
  static const Color lightTextSecondary = Color(0xFF4A4A5A);
  static const Color lightTextTertiary = Color(0xFF8A8A9A);

  static const Color darkSuccess = Color(0xFF22C55E);
  static const Color darkError = Color(0xFFEF4444);
  static const Color darkWarning = Color(0xFFF97316);
  static const Color darkInfo = Color(0xFF3B82F6);
  static const Color darkClearance = Color(0xFFEAB308);

  static const Color lightSuccess = Color(0xFF16A34A);
  static const Color lightError = Color(0xFFDC2626);
  static const Color lightWarning = Color(0xFFEA580C);
  static const Color lightInfo = Color(0xFF2563EB);
  static const Color lightClearance = Color(0xFFCA8A04);

  static const Color pending = Color(0xFF71717A);

  static Color successFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkSuccess : lightSuccess;

  static Color errorFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkError : lightError;

  static Color warningFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkWarning : lightWarning;

  static Color infoFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkInfo : lightInfo;

  static Color clearanceFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkClearance : lightClearance;

  static Color invoiceStatusColor(String status, Brightness brightness) {
    switch (status) {
      case 'Fulfilled':
        return successFor(brightness);
      case 'Not Fulfilled':
        return errorFor(brightness);
      case 'Fulfilled with Returns':
        return warningFor(brightness);
      case 'Fulfilled with Concerns':
        return clearanceFor(brightness);
      default:
        return pending;
    }
  }

  static Color tripStatusColor(String status, Brightness brightness) {
    switch (status) {
      case 'For Dispatch':
        return infoFor(brightness);
      case 'For Inbound':
        return warningFor(brightness);
      case 'For Clearance':
        return clearanceFor(brightness);
      case 'Posted':
        return successFor(brightness);
      default:
        return pending;
    }
  }

  // Compatibility aliases for screens that are not yet theme-aware.
  static const Color fulfilled = darkSuccess;
  static const Color notFulfilled = darkError;
  static const Color fulfilledWithReturns = darkWarning;
  static const Color fulfilledWithConcerns = darkClearance;

  static const Color forDispatch = darkInfo;
  static const Color forInbound = darkWarning;
  static const Color forClearance = darkClearance;
  static const Color posted = darkSuccess;

  static const Color success = darkSuccess;
  static const Color successDark = Color(0xFF166534);
  static const Color error = darkError;
  static const Color errorDark = Color(0xFF991B1B);
  static const Color warning = darkWarning;
  static const Color warningDark = Color(0xFF9A3412);
  static const Color info = darkInfo;

  static const Color surface = darkSurface;
  static const Color surfaceVariant = darkSurfaceVariant;
  static const Color textPrimary = darkTextPrimary;
  static const Color textSecondary = darkTextSecondary;
  static const Color textTertiary = darkTextTertiary;
  static const Color border = darkBorder;
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
