import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Surfaces
  static const Color background = Colors.black;
  static const Color surface = Color(0xFF1E1E1E); // grey.shade900
  static const Color surfaceVariant = Color(0xFF2D2D2D); // grey.shade800
  static const Color surfaceElevated = Color(0xFF333333); // grey.shade700

  // Primary
  static const Color primary = Color(0xFF1565C0); // blue.shade800
  static const Color primaryLight = Color(0xFF64B5F6); // blue.shade300
  static const Color primaryDark = Color(0xFF0D47A1); // blue.shade900
  static const Color primaryContainer = Color(0xFF1A237E);

  // Gradient
  static const List<Color> primaryGradient = [
    Color(0xFF0D47A1),
    Color(0xFF1565C0),
  ];

  // Text
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFBDBDBD); // grey.shade400
  static const Color textTertiary = Color(0xFF9E9E9E); // grey.shade500
  static const Color textDisabled = Color(0xFF616161); // grey.shade700

  // Status
  static const Color success = Color(0xFF66BB6A); // green.shade400
  static const Color successDark = Color(0xFF2E7D32); // green.shade800
  static const Color error = Color(0xFFEF5350); // red.shade300
  static const Color errorDark = Color(0xFFC62828); // red.shade800
  static const Color warning = Color(0xFFFFB74D); // orange.shade300
  static const Color warningDark = Color(0xFFE65100); // orange.shade800
  static const Color info = Color(0xFF64B5F6); // blue.shade300

  // Borders
  static const Color border = Color(0xFF424242); // grey.shade800
  static const Color borderLight = Color(0xFF616161); // grey.shade700

  // Invoice statuses
  static const Color fulfilled = Color(0xFF4CAF50); // green
  static const Color notFulfilled = Color(0xFFF44336); // red
  static const Color fulfilledWithReturns = Color(0xFFFF9800); // orange
  static const Color fulfilledWithConcerns = Color(0xFFFFC107); // amber
  static const Color pending = Color(0xFF9E9E9E); // grey

  // Trip statuses
  static const Color forDispatch = Color(0xFF64B5F6); // blue.shade300
  static const Color forInbound = Color(0xFFFFB74D); // orange.shade300
  static const Color forClearance = Color(0xFFFFD54F); // amber.shade300
  static const Color posted = Color(0xFF81C784); // green.shade300
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
        return AppColors.textTertiary;
    }
  }
}
