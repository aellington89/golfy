import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/backup/backup_codec.dart';
import '../../data/backup/restore_service.dart';
import 'platform_label.dart';

/// What the user decided, looking at a backup they picked (#70).
enum RestoreChoice {
  /// Replace everything on the device with the file.
  replace,

  /// Make a backup of what is here first, then come back.
  backUpFirst,
}

/// Asks before a restore replaces everything on the device (#70).
///
/// Replacing is destructive, so it has to look it: the dialog shows what the
/// file holds — when it was made, by which Golfy, on what — beside what the
/// device holds now, says plainly that it cannot be undone, and puts the
/// action in the error colour. Returns `null` when dismissed.
Future<RestoreChoice?> showRestoreConfirmDialog(
  BuildContext context,
  RestorePlan plan,
) {
  return showDialog<RestoreChoice>(
    context: context,
    builder: (_) => RestoreConfirmDialog(plan: plan),
  );
}

class RestoreConfirmDialog extends StatelessWidget {
  const RestoreConfirmDialog({super.key, required this.plan});

  final RestorePlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final manifest = plan.manifest;
    final fileCounts = plan.payload.rowCounts;
    final made = DateFormat('d MMM y, HH:mm').format(manifest.exportedAt.toLocal());
    final older = manifest.schemaVersion < BackupCodec.supportedSchemaVersion;
    final erasing = plan.payload.isEmpty && !plan.deviceIsEmpty;

    return AlertDialog(
      key: const ValueKey('restore_confirm_dialog'),
      title: Text(plan.deviceIsEmpty
          ? 'Restore this backup?'
          : 'Replace everything on this device?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('The backup', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(plan.fileName, style: theme.textTheme.bodySmall),
            Text(
              'Made $made by Golfy ${manifest.appVersion} on '
              '${platformLabel(manifest.platform)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              countsSummary(fileCounts),
              key: const ValueKey('restore_confirm_file_counts'),
            ),
            if (older) ...[
              const SizedBox(height: 4),
              Text(
                'Made by an older Golfy — it will be updated as it is '
                'restored.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            Text('This device now', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              plan.deviceIsEmpty
                  ? 'Nothing recorded yet'
                  : countsSummary(plan.currentCounts),
              key: const ValueKey('restore_confirm_device_counts'),
            ),
            const SizedBox(height: 16),
            Text(
              erasing
                  ? 'This backup is empty — replacing will erase everything '
                      'on this device. This can\'t be undone.'
                  : plan.deviceIsEmpty
                      ? 'Everything in the backup will be put on this device.'
                      : 'Everything on this device will be replaced by the '
                          'backup. This can\'t be undone.',
              style: plan.deviceIsEmpty
                  ? null
                  : theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
            ),
          ],
        ),
      ),
      actions: [
        if (!plan.deviceIsEmpty)
          TextButton(
            key: const ValueKey('restore_confirm_backup_first'),
            onPressed: () =>
                Navigator.of(context).pop(RestoreChoice.backUpFirst),
            child: const Text('Back up first'),
          ),
        TextButton(
          key: const ValueKey('restore_confirm_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('restore_confirm_replace'),
          style: plan.deviceIsEmpty
              ? null
              : FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
          onPressed: () => Navigator.of(context).pop(RestoreChoice.replace),
          child: Text(plan.deviceIsEmpty ? 'Restore' : 'Replace'),
        ),
      ],
    );
  }
}

/// "42 rounds · 3 courses · 4 events · 756 holes · 2980 shots", from rows per
/// SQL table name — the things a person counts, not every table.
String countsSummary(Map<String, int> counts) {
  return <String>[
    _plural(counts['rounds'] ?? 0, 'round'),
    _plural(counts['courses'] ?? 0, 'course'),
    _plural(counts['events'] ?? 0, 'event'),
    _plural(counts['hole_results'] ?? 0, 'hole'),
    _plural(counts['hole_shots'] ?? 0, 'shot'),
  ].join(' · ');
}

String _plural(int count, String noun) =>
    count == 1 ? '1 $noun' : '$count ${noun}s';
