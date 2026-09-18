import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/task_provider.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmClearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all tasks?'),
        content: const Text(
          'This will permanently delete every task stored on this device. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final provider = context.read<TaskProvider>();
    final success = await provider.clearAllTasks();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? 'All tasks cleared'
            : provider.errorMessage ?? 'Could not clear tasks'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- Appearance --------------------------------------------------
          _SectionCard(
            title: 'Appearance',
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Theme',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto_outlined),
                    label: Text('System'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('Light'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('Dark'),
                  ),
                ],
                selected: {provider.themeMode},
                onSelectionChanged: (modes) =>
                    provider.setThemeMode(modes.first),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ---- Storage -----------------------------------------------------
          _SectionCard(
            title: 'Storage',
            children: [
              _InfoTile(
                icon: Icons.storage_outlined,
                title: 'Tasks stored locally',
                subtitle: '${provider.totalCount} task(s) on this device',
              ),
              const _InfoTile(
                icon: Icons.lock_outline,
                title: 'Encryption',
                subtitle:
                    'AES-256 encrypted Hive box. The key is generated '
                    'on-device and kept in the OS secure storage '
                    '(Keychain on iOS / Keystore on Android) — never '
                    'hardcoded, never stored in the database itself.',
              ),
              const _InfoTile(
                icon: Icons.cloud_off_outlined,
                title: 'Offline-first',
                subtitle: 'No network calls — all data stays on this device.',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ---- Data management ---------------------------------------------
          _SectionCard(
            title: 'Data management',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete_sweep_outlined, color: scheme.error),
                title: Text(
                  'Clear all tasks',
                  style: TextStyle(color: scheme.error),
                ),
                subtitle: const Text('Permanently delete every stored task'),
                onTap: () => _confirmClearAll(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ---- About -------------------------------------------------------
          const _SectionCard(
            title: 'About ${AppConstants.appName}',
            children: [
              _InfoTile(
                icon: Icons.info_outline,
                title: AppConstants.appName,
                subtitle:
                    'Version 1.0.0 — Personal Task & Productivity Manager. '
                    'Built with Flutter, Hive (AES-256 encrypted) and '
                    'Provider. 100 % offline, local-data only.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Internal widgets
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
                letterSpacing: 0.8,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}
