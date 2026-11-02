import 'package:flutter/material.dart';

import 'about_tiles.dart';
import 'export_backup_tile.dart';
import 'restore_backup_tile.dart';

/// Settings — reached from the navigation drawer (#69).
///
/// Two sections: **Data**, with Export (#69) and Restore (#70), and **About**,
/// with the installed version, the open-source licences, the privacy policy
/// and a way to get help (#72).
///
/// It is pushed over the tabs, so its app bar carries a back button and it has
/// no drawer of its own: a drawer takes the back button's place, and on
/// Windows, which has no system back, that left no way out (#72).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: const [
          _SectionHeader('Data'),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Golfy keeps everything on this device. A backup is a single '
              'file, and you choose where it goes — nothing is uploaded.',
            ),
          ),
          ExportBackupTile(),
          RestoreBackupTile(),
          Divider(),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Text(
              'Keep the file somewhere off this phone — a cloud drive, or an '
              'email to yourself. Restoring replaces everything on this '
              'device with what the file holds, and asks first.',
            ),
          ),
          _SectionHeader('About'),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Golfy has no account, no ads and no tracking. The links below '
              'open outside the app.',
            ),
          ),
          AppVersionTile(),
          LicensesTile(),
          PrivacyPolicyTile(),
          HelpFeedbackTile(),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// A section's title — **Data**, **About** — in the primary colour, and marked
/// as a heading for screen readers.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
