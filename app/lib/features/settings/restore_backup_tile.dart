import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/backup/backup_provider.dart';
import '../../data/backup/restore_service.dart';
import '../rounds/active_round_provider.dart';
import 'export_backup_tile.dart';
import 'restore_confirm_dialog.dart';

/// The **Restore from a backup** tile on the Settings screen (#70).
///
/// Pick a file; it is checked whole before anything happens, and refused with
/// its reason if it cannot be restored. A sound one is shown beside what the
/// device holds now, and only an explicit Replace writes anything.
class RestoreBackupTile extends ConsumerStatefulWidget {
  const RestoreBackupTile({super.key});

  @override
  ConsumerState<RestoreBackupTile> createState() => _RestoreBackupTileState();
}

class _RestoreBackupTileState extends ConsumerState<RestoreBackupTile> {
  /// A restore is under way, from the tap to the last message; a second tap
  /// does nothing.
  bool _busy = false;

  /// Work is running — reading the file, writing it, or backing up first. The
  /// spinner shows only for this, not while a dialog waits on the user.
  bool _working = false;

  Future<T> _whileWorking<T>(Future<T> Function() work) async {
    setState(() => _working = true);
    try {
      return await work();
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    _busy = true;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final restore = ref.read(restoreServiceProvider);
      final prepared = await _whileWorking(restore.prepare);
      if (!mounted) return;

      switch (prepared) {
        case RestoreCancelled():
          _nothingChanged(messenger);
        case RestoreRefused(:final reason, :final problems):
          await _showRefused(reason, problems);
        case RestoreReady(:final plan):
          final choice = await showRestoreConfirmDialog(context, plan);
          if (!mounted) return;
          switch (choice) {
            case null:
              _nothingChanged(messenger);
            case RestoreChoice.backUpFirst:
              await _backUpFirst();
            case RestoreChoice.replace:
              await _apply(restore, plan, messenger);
          }
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _apply(
    RestoreService restore,
    RestorePlan plan,
    ScaffoldMessengerState messenger,
  ) async {
    final result = await _whileWorking(() => restore.apply(plan));
    if (!mounted) return;
    if (!result.isSuccess) {
      await _showFailed(result.error);
      return;
    }
    // The restored ids are the file's, so the round Hole Entry had open may
    // now be a different round — or none. Close it, so an unsaved hole can't
    // be saved into someone else's round.
    ref.read(activeRoundIdProvider.notifier).clear();
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text('Restored · ${countsSummary(result.rowCounts)}'),
    ));
  }

  /// Runs the ordinary export, so what is here can be kept before it is
  /// replaced. The user restores again afterwards.
  Future<void> _backUpFirst() async {
    final messenger = ScaffoldMessenger.of(context);
    final result =
        await _whileWorking(ref.read(backupServiceProvider).createBackup);
    if (!mounted) return;
    showBackupResult(messenger, result, onRetry: _backUpFirst);
  }

  void _nothingChanged(ScaffoldMessengerState messenger) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(content: Text('Restore cancelled — nothing changed')),
    );
  }

  Future<void> _showRefused(String reason, List<String> problems) {
    const shown = 5;
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('restore_refused_dialog'),
        title: const Text("This file can't be restored"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(reason),
              for (final problem in problems.take(shown))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('• $problem'),
                ),
              if (problems.length > shown)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('…and ${problems.length - shown} more'),
                ),
              const SizedBox(height: 12),
              const Text('Nothing on this device was changed.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showFailed(String? error) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('restore_failed_dialog'),
        title: const Text('Restore failed — your data is unchanged'),
        content: Text(
          'The backup could not be written, so everything was put back as it '
          'was. (${error ?? 'unknown error'})',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: const ValueKey('settings_restore_tile'),
      leading: const Icon(Icons.settings_backup_restore),
      title: const Text('Restore from a backup'),
      subtitle: const Text('Replace what is here with a backup file'),
      trailing: _working
          ? const SizedBox(
              key: ValueKey('settings_restore_progress'),
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
      onTap: _working ? null : _restore,
    );
  }
}
