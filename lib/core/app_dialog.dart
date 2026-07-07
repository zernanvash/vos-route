import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class AppDialog {
  static Future<void> showConfirm(
    BuildContext context, {
    required String title,
    required String message,
    VoidCallback? onConfirm,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    String? remarksHint,
    void Function(String remarks)? onConfirmWithRemarks,
  }) {
    final controller = TextEditingController();
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: TextStyle(color: AppColors.textSecondary)),
            if (remarksHint != null) ...[
              Insets.gapLg,
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: remarksHint,
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Insets.smallRadius),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(cancelLabel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (onConfirmWithRemarks != null) {
                onConfirmWithRemarks(controller.text);
              } else {
                onConfirm?.call();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
            ),
            child: Text(
              confirmLabel,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> showError(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Icon(Icons.error, color: AppColors.error, size: 20),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
