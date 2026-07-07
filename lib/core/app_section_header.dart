import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class AppSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Color? color;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: color ?? AppColors.info,
            fontSize: AppTextStyle.sectionHeader.fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class AppDivider extends StatelessWidget {
  const AppDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(color: AppColors.border, height: 1);
  }
}
