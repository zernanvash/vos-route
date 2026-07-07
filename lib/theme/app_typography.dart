import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyle {
  AppTextStyle._();

  static const TextStyle heading = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 22,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle subheading = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle body = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle caption = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle label = TextStyle(
    color: AppColors.textTertiary,
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle sectionHeader = TextStyle(
    color: AppColors.info,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle amount = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle badge = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 10,
    fontWeight: FontWeight.w600,
  );
}
