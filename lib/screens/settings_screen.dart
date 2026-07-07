import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/gps_provider.dart';
import '../config/app_config.dart';
import '../services/api_service.dart';
import '../core/app_card.dart';
import '../core/app_dialog.dart';
import '../core/app_list_tile.dart';
import '../core/app_section_header.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final gps = context.watch<GpsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: AppColors.surface,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: Insets.cardLg,
        children: [
          if (auth.profile != null) ...[
            AppCard(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                title: Text(auth.profile!.fullName, style: AppTextStyle.body),
                subtitle: Text(
                  auth.profile!.email ?? '',
                  style: AppTextStyle.caption,
                ),
              ),
            ),
            Insets.gapLg,
          ],
          AppCard(
            child: Column(
              children: [
                AppListTile(
                  label: 'GPS Tracking',
                  icon: Icons.location_on,
                  value: gps.isTracking ? 'Active' : 'Inactive',
                ),
                AppDivider(),
                AppListTile(
                  label: 'GPS Interval',
                  icon: Icons.timer,
                  value: '${AppConfig.gpsIntervalSeconds}s',
                ),
                AppDivider(),
                AppListTile(
                  label: 'Server URL',
                  icon: Icons.dns,
                  value: AppConfig.springBaseUrl,
                ),
                AppDivider(),
                AppListTile(
                  label: 'Directus URL',
                  icon: Icons.cloud,
                  value: AppConfig.directusBaseUrl,
                ),
              ],
            ),
          ),
          Insets.gapXxl,
          AppCard(
            child: ListTile(
              leading: Icon(Icons.network_ping, color: AppColors.primary),
              title: Text(
                'Connection Diagnostics',
                style: AppTextStyle.subheading,
              ),
              subtitle: Text(
                'Ping Directus API server endpoint',
                style: AppTextStyle.caption,
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
              ),
              onTap: () => _pingServer(context),
            ),
          ),
          Insets.gapXxl,
          AppCard(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.info_outline,
                    color: AppColors.textSecondary,
                  ),
                  title: Text('App Version', style: AppTextStyle.body),
                  trailing: Text(
                    '1.0.0',
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                ),
                AppDivider(),
                ListTile(
                  leading: Icon(Icons.code, color: AppColors.textSecondary),
                  title: Text('Flutter', style: AppTextStyle.body),
                  trailing: Text(
                    '3.44.4',
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                ),
              ],
            ),
          ),
          Insets.gapXxl,
          SizedBox(
            width: double.infinity,
            height: Insets.buttonHeight,
            child: ElevatedButton.icon(
              onPressed: () => _logout(context),
              icon: Icon(Icons.logout),
              label: Text('Sign Out', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Insets.cardRadius),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _pingServer(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          color: AppColors.background,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                Insets.gapWLg,
                Text(
                  'Pinging Directus...',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final success = await ApiService().pingDirectus();

    if (context.mounted) {
      Navigator.pop(context);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error,
                color: success ? AppColors.success : AppColors.error,
              ),
              Insets.gapWSm,
              Text(
                success ? 'Diagnostics Result' : 'Diagnostics Failed',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ],
          ),
          content: Text(
            success
                ? 'Successfully established connection to Directus API server at ${AppConfig.directusBaseUrl}.'
                : 'Unable to reach Directus API server at ${AppConfig.directusBaseUrl}. Please verify your VPN/Tailscale connection configuration.',
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

  void _logout(BuildContext context) {
    AppDialog.showConfirm(
      context,
      title: 'Sign Out',
      message: 'Are you sure you want to sign out?',
      confirmLabel: 'Sign Out',
      onConfirm: () => context.read<AuthProvider>().logout(),
    );
  }
}
