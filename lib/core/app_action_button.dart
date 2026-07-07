import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

class AppActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? height;
  final bool expanded;

  const AppActionButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.height,
    this.expanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon != null ? Icon(icon, size: 20) : const SizedBox.shrink(),
      label: Text(label, style: const TextStyle(fontSize: 16)),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        minimumSize: Size(
          expanded ? double.infinity : 0,
          height ?? Insets.buttonHeight,
        ),
      ),
    );

    if (expanded) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }

  static AppActionButton departure({required VoidCallback? onPressed}) {
    return AppActionButton(
      onPressed: onPressed,
      label: 'Confirm Departure',
      icon: Icons.play_arrow,
      backgroundColor: Colors.blue.shade700,
    );
  }

  static AppActionButton arrival({required VoidCallback? onPressed}) {
    return AppActionButton(
      onPressed: onPressed,
      label: 'Mark Arrived at Base',
      icon: Icons.flag,
      backgroundColor: Colors.blue.shade700,
    );
  }

  static AppActionButton quest({required VoidCallback? onPressed}) {
    return AppActionButton(
      onPressed: onPressed,
      label: 'Photo Quest',
      icon: Icons.camera_alt,
      backgroundColor: Colors.green.shade700,
    );
  }
}
