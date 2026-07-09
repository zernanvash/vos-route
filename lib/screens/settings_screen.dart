import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/gps_provider.dart';
import '../providers/theme_provider.dart';
import '../config/app_config.dart';
import '../services/api_service.dart';
import '../core/app_card.dart';
import '../core/app_dialog.dart';
import '../core/app_list_tile.dart';
import '../core/app_section_header.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  String _initials(dynamic profile) {
    final first = (profile.firstName as String?) ?? '';
    final last = (profile.lastName as String?) ?? '';
    final f = first.isNotEmpty ? first[0] : '';
    final l = last.isNotEmpty ? last[0] : '';
    final result = '$f$l'.toUpperCase();
    return result.isEmpty ? 'DR' : result;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final gps = context.watch<GpsProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: Insets.cardLg,
        children: [
          // ── Profile card ─────────────────────────────────────────────
          if (auth.profile != null) ...[
            AppCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: cs.primary.withValues(alpha: 0.15),
                    child: Text(
                      _initials(auth.profile!),
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.profile!.fullName,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          auth.profile!.email ?? '',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Insets.gapLg,
          ],

          // ── Appearance section ───────────────────────────────────────
          AppSectionHeader(title: 'Appearance'),
          Insets.gapSm,
          _AppearanceCard(),
          Insets.gapXxl,

          // ── System info ──────────────────────────────────────────────
          AppSectionHeader(title: 'System'),
          Insets.gapSm,
          AppCard(
            child: Column(
              children: [
                AppListTile(
                  label: 'GPS Tracking',
                  icon: Icons.location_on_outlined,
                  value: gps.isTracking ? 'Active' : 'Inactive',
                ),
                AppDivider(),
                AppListTile(
                  label: 'GPS Interval',
                  icon: Icons.timer_outlined,
                  value: '${AppConfig.gpsIntervalSeconds}s',
                ),
                AppDivider(),
                AppListTile(
                  label: 'Server URL',
                  icon: Icons.dns_outlined,
                  value: AppConfig.springBaseUrl,
                ),
                AppDivider(),
                AppListTile(
                  label: 'Directus URL',
                  icon: Icons.cloud_outlined,
                  value: AppConfig.directusBaseUrl,
                ),
              ],
            ),
          ),
          Insets.gapXxl,

          // ── Diagnostics ──────────────────────────────────────────────
          AppCard(
            child: ListTile(
              leading: Icon(Icons.network_ping_rounded, color: cs.primary),
              title: Text(
                'Connection Diagnostics',
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                'Ping Directus API server endpoint',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant,
              ),
              onTap: () => _pingServer(context),
            ),
          ),
          Insets.gapXxl,

          // ── App info ─────────────────────────────────────────────────
          AppCard(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.info_outline_rounded,
                    color: cs.onSurfaceVariant,
                  ),
                  title: Text(
                    'App Version',
                    style: TextStyle(color: cs.onSurface, fontSize: 14),
                  ),
                  trailing: Text(
                    '1.0.0',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
                AppDivider(),
                ListTile(
                  leading: Icon(Icons.code_rounded, color: cs.onSurfaceVariant),
                  title: Text(
                    'Flutter',
                    style: TextStyle(color: cs.onSurface, fontSize: 14),
                  ),
                  trailing: Text(
                    '3.44.4',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          Insets.gapXxl,

          // ── Sign out ─────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: Insets.buttonHeight,
            child: OutlinedButton.icon(
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout_rounded),
              label: const Text(
                'Sign Out',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Insets.cardRadius),
                ),
              ),
            ),
          ),
          Insets.gapLg,
        ],
      ),
    );
  }

  void _pingServer(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: cs.primary),
                  const SizedBox(width: 16),
                  Text(
                    'Pinging Directus...',
                    style: TextStyle(color: cs.onSurface),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    final success = await ApiService().pingDirectus();

    if (context.mounted) {
      Navigator.pop(context);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(
                success ? Icons.check_circle_rounded : Icons.error_rounded,
                color: success ? AppColors.success : AppColors.error,
              ),
              const SizedBox(width: 8),
              Text(
                success ? 'Diagnostics OK' : 'Diagnostics Failed',
                style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
              ),
            ],
          ),
          content: Text(
            success
                ? 'Successfully connected to Directus at ${AppConfig.directusBaseUrl}.'
                : 'Unable to reach ${AppConfig.directusBaseUrl}. Check your VPN/Tailscale connection.',
            style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant),
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

// ── Appearance card ──────────────────────────────────────────────────────────
class _AppearanceCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final cs = Theme.of(context).colorScheme;
    final currentMode = themeProvider.themeMode;

    final options = [
      (ThemeMode.light, 'Light', Icons.light_mode_rounded),
      (ThemeMode.dark, 'Dark', Icons.dark_mode_rounded),
      (ThemeMode.system, 'System', Icons.brightness_auto_rounded),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Theme',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: options.map((opt) {
              final (mode, label, icon) = opt;
              final isSelected = currentMode == mode;
              return Expanded(
                child: GestureDetector(
                  onTap: () => themeProvider.setMode(mode),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? cs.primary.withValues(alpha: 0.1)
                          : cs.surfaceContainer,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? cs.primary.withValues(alpha: 0.4)
                            : cs.outlineVariant.withValues(alpha: 0.5),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          color: isSelected ? cs.primary : cs.onSurfaceVariant,
                          size: 20,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          style: TextStyle(
                            color: isSelected
                                ? cs.primary
                                : cs.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
