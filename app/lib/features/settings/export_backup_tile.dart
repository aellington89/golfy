import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/backup/backup_destination.dart';
import '../../data/backup/backup_provider.dart';
import '../../data/repository_provider.dart';

/// The **Back up your data** tile on the Settings screen (#69).
///
/// Its subtitle counts what is about to be saved, so the user can see whether
/// the file is going to hold what they expect before they send it anywhere —
/// and so an empty database says so rather than producing a file that looks
/// like a mistake.
class ExportBackupTile extends ConsumerStatefulWidget {
  const ExportBackupTile({super.key});

  @override
  ConsumerState<ExportBackupTile> createState() => _ExportBackupTileState();
}

class _ExportBackupTileState extends ConsumerState<ExportBackupTile> {
  bool _busy = false;

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref.read(backupServiceProvider).createBackup();
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      switch (result.status) {
        case BackupSaveStatus.saved:
          messenger.showSnackBar(SnackBar(
            content: Text('Backup saved · ${result.location ?? result.fileName}'),
          ));
        case BackupSaveStatus.shared:
          messenger.showSnackBar(SnackBar(
            content: Text('Backup created · ${result.fileName}'),
          ));
        case BackupSaveStatus.cancelled:
          messenger.showSnackBar(
            const SnackBar(content: Text('Backup cancelled — nothing saved')),
          );
        case BackupSaveStatus.failed:
          messenger.showSnackBar(SnackBar(
            content: Text("Backup failed — ${result.error ?? 'unknown error'}"),
            action: SnackBarAction(label: 'Retry', onPressed: _export),
            duration: const Duration(seconds: 8),
          ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rounds = ref.watch(roundsStreamProvider);
    final courses = ref.watch(coursesStreamProvider);
    final events = ref.watch(eventsStreamProvider);

    return ListTile(
      key: const ValueKey('settings_export_tile'),
      leading: const Icon(Icons.save_alt),
      title: const Text('Back up your data'),
      subtitle: Text(_subtitle(
        rounds: rounds.value?.length,
        courses: courses.value?.length,
        events: events.value?.length,
      )),
      trailing: _busy
          ? const SizedBox(
              key: ValueKey('settings_export_progress'),
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
      onTap: _busy ? null : _export,
    );
  }

  /// "42 rounds · 3 courses · 4 events", or something honest when there is
  /// nothing to say yet.
  static String _subtitle({int? rounds, int? courses, int? events}) {
    if (rounds == null || courses == null || events == null) {
      return 'Counting what you have…';
    }
    if (rounds == 0 && courses == 0 && events == 0) {
      return 'Nothing recorded yet';
    }
    return <String>[
      _plural(rounds, 'round'),
      _plural(courses, 'course'),
      _plural(events, 'event'),
    ].join(' · ');
  }

  static String _plural(int count, String noun) =>
      count == 1 ? '1 $noun' : '$count ${noun}s';
}
