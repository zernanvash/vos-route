import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  static const Color _seedLight = AppColors.primaryLight;
  static const Color _seedDark = AppColors.primaryDark;

  static ThemeData get light {
    final cs =
        ColorScheme.fromSeed(
          seedColor: _seedLight,
          brightness: Brightness.light,
          surface: AppColors.lightSurface,
          onSurface: AppColors.lightTextPrimary,
        ).copyWith(
          primary: _seedLight,
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFDDE9FF),
          onPrimaryContainer: const Color(0xFF001754),
          secondary: AppColors.lightSurfaceVariant,
          onSecondary: AppColors.lightTextPrimary,
          surfaceContainerLowest: AppColors.lightBackground,
          surfaceContainer: AppColors.lightSurfaceVariant,
          surfaceContainerHigh: AppColors.lightSurfaceElevated,
          outline: AppColors.lightBorder,
          outlineVariant: AppColors.lightBorder,
          error: AppColors.lightError,
          onError: Colors.white,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: cs,
      scaffoldBackgroundColor: AppColors.lightBackground,
      fontFamily: AppTextStyle.bodyFontFamily,
      textTheme: AppTextStyle.textTheme(Brightness.light),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightSurface,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTextStyle.titleMd.copyWith(
          color: AppColors.lightTextPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.lightTextPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _seedLight,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.lightSurfaceElevated,
          disabledForegroundColor: AppColors.lightTextTertiary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Insets.cardRadius),
          ),
          minimumSize: const Size(64, Insets.buttonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.lg,
            vertical: Insets.md,
          ),
          elevation: 0,
          textStyle: AppTextStyle.labelSm.copyWith(color: Colors.white),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _seedLight,
          side: const BorderSide(color: AppColors.lightBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Insets.cardRadius),
          ),
          minimumSize: const Size(64, Insets.buttonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.lg,
            vertical: Insets.md,
          ),
          textStyle: AppTextStyle.labelSm.copyWith(color: _seedLight),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Insets.cardRadius),
          side: const BorderSide(color: AppColors.lightBorder),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Insets.cardRadius),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Insets.cardRadius),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Insets.cardRadius),
          borderSide: const BorderSide(color: _seedLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Insets.cardRadius),
          borderSide: const BorderSide(color: AppColors.lightError),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Insets.cardRadius),
          borderSide: const BorderSide(color: AppColors.lightError, width: 2),
        ),
        labelStyle: AppTextStyle.bodyMd.copyWith(
          color: AppColors.lightTextSecondary,
        ),
        hintStyle: AppTextStyle.bodyMd.copyWith(
          color: AppColors.lightTextTertiary,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightBorder,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        indicatorColor: _seedLight.withValues(alpha: 0.12),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _seedLight, size: 22);
          }
          return const IconThemeData(
            color: AppColors.lightTextTertiary,
            size: 22,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTextStyle.labelSm.copyWith(color: _seedLight);
          }
          return AppTextStyle.labelSm.copyWith(
            color: AppColors.lightTextTertiary,
          );
        }),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.lightSurfaceElevated,
        contentTextStyle: AppTextStyle.bodyMd.copyWith(
          color: AppColors.lightTextPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Insets.smallRadius),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Insets.cardRadius),
          side: const BorderSide(color: AppColors.lightBorder),
        ),
      ),
    );
  }

  static ThemeData get dark {
    final cs =
        ColorScheme.fromSeed(
          seedColor: _seedDark,
          brightness: Brightness.dark,
          surface: AppColors.darkSurface,
          onSurface: AppColors.darkTextPrimary,
        ).copyWith(
          primary: _seedDark,
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFF1A2F6A),
          onPrimaryContainer: const Color(0xFFB8CFFF),
          secondary: AppColors.darkSurfaceVariant,
          onSecondary: AppColors.darkTextPrimary,
          surfaceContainerLowest: AppColors.darkBackground,
          surfaceContainer: AppColors.darkSurfaceVariant,
          surfaceContainerHigh: AppColors.darkSurfaceElevated,
          outline: AppColors.darkBorder,
          outlineVariant: AppColors.darkBorder,
          error: AppColors.darkError,
          onError: Colors.white,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: cs,
      scaffoldBackgroundColor: AppColors.darkBackground,
      fontFamily: AppTextStyle.bodyFontFamily,
      textTheme: AppTextStyle.textTheme(Brightness.dark),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTextStyle.titleMd.copyWith(
          color: AppColors.darkTextPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.darkTextPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _seedDark,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.darkSurfaceElevated,
          disabledForegroundColor: AppColors.darkTextTertiary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Insets.cardRadius),
          ),
          minimumSize: const Size(64, Insets.buttonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.lg,
            vertical: Insets.md,
          ),
          elevation: 0,
          textStyle: AppTextStyle.labelSm.copyWith(color: Colors.white),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _seedDark,
          side: const BorderSide(color: AppColors.darkBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Insets.cardRadius),
          ),
          minimumSize: const Size(64, Insets.buttonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.lg,
            vertical: Insets.md,
          ),
          textStyle: AppTextStyle.labelSm.copyWith(color: _seedDark),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Insets.cardRadius),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Insets.cardRadius),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Insets.cardRadius),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Insets.cardRadius),
          borderSide: const BorderSide(color: _seedDark, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Insets.cardRadius),
          borderSide: const BorderSide(color: AppColors.darkError),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Insets.cardRadius),
          borderSide: const BorderSide(color: AppColors.darkError, width: 2),
        ),
        labelStyle: AppTextStyle.bodyMd.copyWith(
          color: AppColors.darkTextSecondary,
        ),
        hintStyle: AppTextStyle.bodyMd.copyWith(
          color: AppColors.darkTextTertiary,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        indicatorColor: _seedDark.withValues(alpha: 0.2),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _seedDark, size: 22);
          }
          return const IconThemeData(
            color: AppColors.darkTextTertiary,
            size: 22,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTextStyle.labelSm.copyWith(color: _seedDark);
          }
          return AppTextStyle.labelSm.copyWith(
            color: AppColors.darkTextTertiary,
          );
        }),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkSurfaceElevated,
        contentTextStyle: AppTextStyle.bodyMd.copyWith(
          color: AppColors.darkTextPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Insets.smallRadius),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Insets.cardRadius),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
      ),
    );
  }
}
