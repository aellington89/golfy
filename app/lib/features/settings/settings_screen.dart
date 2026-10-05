import 'package:flutter/material.dart';

import '../../shell/app_drawer.dart';
import 'export_backup_tile.dart';

/// Settings — reached from the navigation drawer (#69).
///
/// Today it carries one section, **Data**, which is the home the Export action
/// needed. App version, open-source licences, the privacy policy and a support
/// link are [#72](https://github.com/aellington89/golfy/issues/72)'s and land
/// as further sections here rather than anywhere new.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      drawer: const AppDrawer(),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Data',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Golfy keeps everything on this device. A backup is a single '
              'file, and you choose where it goes — nothing is uploaded.',
            ),
          ),
          const ExportBackupTile(),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Text(
              'Keep the file somewhere off this phone — a cloud drive, or an '
              'email to yourself. Restoring a backup is coming in a later '
              'update; files you make now will still be valid then.',
            ),
          ),
        ],
      ),
    );
  }
}
