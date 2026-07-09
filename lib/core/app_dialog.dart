import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

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
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text(title, style: TextStyle(color: cs.onSurface)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
              if (remarksHint != null) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(labelText: remarksHint),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(cancelLabel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (onConfirmWithRemarks != null) {
                  onConfirmWithRemarks(controller.text);
                } else {
                  onConfirm?.call();
                }
              },
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
  }

  static Future<void> showError(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error_rounded, color: AppColors.error, size: 20),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: cs.onSurface)),
            ],
          ),
          content: Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
