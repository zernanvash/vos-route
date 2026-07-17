import 'package:flutter/material.dart';

class AppTextStyle {
  AppTextStyle._();

  static const String displayFontFamily = 'Plus Jakarta Sans';
  static const String bodyFontFamily = 'Inter';
  static const String labelFontFamily = 'Manrope';

  static const TextStyle displayLg = TextStyle(
    color: Color(0xFFFAFAFA),
    fontFamily: displayFontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 0,
  );

  static const TextStyle titleMd = TextStyle(
    color: Color(0xFFFAFAFA),
    fontFamily: displayFontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0,
  );

  static const TextStyle bodyMd = TextStyle(
    color: Color(0xFFFAFAFA),
    fontFamily: bodyFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0,
  );

  static const TextStyle labelSm = TextStyle(
    color: Color(0xFFADADB8),
    fontFamily: labelFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0,
  );

  static const TextStyle heading = displayLg;
  static const TextStyle subheading = titleMd;
  static const TextStyle body = bodyMd;
  static const TextStyle caption = TextStyle(
    color: Color(0xFFADADB8),
    fontFamily: bodyFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0,
  );
  static const TextStyle label = labelSm;
  static const TextStyle sectionHeader = TextStyle(
    color: Color(0xFF3B6EF0),
    fontFamily: labelFontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0,
  );
  static const TextStyle amount = TextStyle(
    color: Color(0xFFFAFAFA),
    fontFamily: bodyFontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.5,
    letterSpacing: 0,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const TextStyle badge = TextStyle(
    color: Color(0xFFFAFAFA),
    fontFamily: labelFontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0,
  );

  static TextStyle displayLgOf(BuildContext context) =>
      displayLg.copyWith(color: Theme.of(context).colorScheme.onSurface);

  static TextStyle titleMdOf(BuildContext context) =>
      titleMd.copyWith(color: Theme.of(context).colorScheme.onSurface);

  static TextStyle bodyMdOf(BuildContext context) =>
      bodyMd.copyWith(color: Theme.of(context).colorScheme.onSurface);

  static TextStyle labelSmOf(BuildContext context) =>
      labelSm.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

  static TextStyle headingOf(BuildContext context) => displayLgOf(context);

  static TextStyle subheadingOf(BuildContext context) => titleMdOf(context);

  static TextStyle bodyOf(BuildContext context) => bodyMdOf(context);

  static TextStyle captionOf(BuildContext context) =>
      caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

  static TextStyle sectionHeaderOf(BuildContext context) =>
      sectionHeader.copyWith(color: Theme.of(context).colorScheme.primary);

  static TextStyle amountOf(BuildContext context) =>
      amount.copyWith(color: Theme.of(context).colorScheme.onSurface);

  static TextTheme textTheme(Brightness brightness) {
    final primary = brightness == Brightness.dark
        ? const Color(0xFFFAFAFA)
        : const Color(0xFF0A0A10);
    final secondary = brightness == Brightness.dark
        ? const Color(0xFFADADB8)
        : const Color(0xFF4A4A5A);

    return TextTheme(
      displayLarge: displayLg.copyWith(color: primary),
      headlineMedium: titleMd.copyWith(color: primary),
      titleLarge: titleMd.copyWith(color: primary),
      titleMedium: titleMd.copyWith(color: primary, fontSize: 16),
      bodyLarge: bodyMd.copyWith(color: primary, fontSize: 16),
      bodyMedium: bodyMd.copyWith(color: primary),
      bodySmall: bodyMd.copyWith(color: secondary, fontSize: 12),
      labelLarge: labelSm.copyWith(color: primary),
      labelMedium: labelSm.copyWith(color: secondary),
      labelSmall: labelSm.copyWith(color: secondary),
    );
  }
}
