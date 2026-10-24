import 'dart:convert';

import '../repository.dart';
import 'backup_codec.dart';
import 'backup_format_exception.dart';
import 'backup_manifest.dart';
import 'backup_payload.dart';
import 'backup_source.dart';

/// A backup that has been read, decoded and checked, waiting for the user to
/// confirm it should replace what is on the device (#70).
///
/// [RestoreService.prepare] only builds one from a payload that passed
/// [BackupPayload.validate], which is what lets [RestoreService.apply] write
/// it without asking again.
class RestorePlan {
  const RestorePlan({
    required this.fileName,
    required this.manifest,
    required this.payload,
    required this.currentCounts,
  });

  final String fileName;
  final BackupManifest manifest;
  final BackupPayload payload;

  /// Rows per table on the device right now — what replacing will erase.
  final Map<String, int> currentCounts;

  bool get deviceIsEmpty => currentCounts.values.every((count) => count == 0);
}

/// What came of reading a backup the user picked (#70). Nothing in any of
/// these has touched the database.
sealed class RestorePreparation {
  const RestorePreparation();
}

/// The user backed out of the picker.
class RestoreCancelled extends RestorePreparation {
  const RestoreCancelled();
}

/// The file cannot be restored. [reason] is one sentence for a person;
/// [problems] lists what the cross-table check found, when that is why.
class RestoreRefused extends RestorePreparation {
  const RestoreRefused(this.reason, {this.problems = const <String>[]});

  final String reason;
  final List<String> problems;
}

/// The file is sound; ask the user, then [RestoreService.apply] it.
class RestoreReady extends RestorePreparation {
  const RestoreReady(this.plan);

  final RestorePlan plan;
}

enum RestoreStatus { restored, failed }

/// What one restore attempt did.
class RestoreResult {
  const RestoreResult.restored(this.rowCounts)
      : status = RestoreStatus.restored,
        error = null;

  const RestoreResult.failed(this.error)
      : status = RestoreStatus.failed,
        rowCounts = const <String, int>{};

  final RestoreStatus status;

  /// Rows now on the device, per table, when it worked.
  final Map<String, int> rowCounts;

  final String? error;

  bool get isSuccess => status == RestoreStatus.restored;
}

/// Puts a backup file back onto the device (#70), in two steps with the
/// user's confirmation between them.
///
/// [prepare] picks a file and does every check there is — size, text, the
/// format, the versions, the row counts, the cross-table references — without
/// touching the database, so a bad file is refused with a reason and an
/// untouched device. [apply] replaces everything in one transaction, which
/// rolls back whole if anything fails.
///
/// Neither throws at its caller, like `BackupService`: a restore that fails
/// silently is worse than one that fails loudly.
class RestoreService {
  RestoreService({required this.repository, required this.source});

  final GolfyRepository repository;
  final BackupSource source;

  Future<RestorePreparation> prepare() async {
    try {
      return switch (await source.pick()) {
        BackupPickCancelled() => const RestoreCancelled(),
        BackupPickFailed(:final error) =>
          RestoreRefused('The file could not be opened ($error).'),
        BackupTooLarge(:final fileName, :final length) => RestoreRefused(
            '$fileName is ${_megabytes(length)} — far larger than any Golfy '
            'backup. Is it the right file?',
          ),
        BackupPicked(:final fileName, :final bytes) =>
          await _check(fileName, bytes),
      };
    } catch (e) {
      return RestoreRefused('The file could not be read ($e).');
    }
  }

  Future<RestorePreparation> _check(String fileName, List<int> bytes) async {
    String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      return const RestoreRefused(
        'The file is not text, so it is not a Golfy backup.',
      );
    }
    // A file re-saved by some Windows editors starts with a byte-order mark,
    // which JSON does not allow. It is not part of the data.
    if (text.startsWith('\uFEFF')) text = text.substring(1);

    final BackupBundle bundle;
    try {
      bundle = BackupCodec.decode(text);
    } on BackupFormatException catch (e) {
      return RestoreRefused(_sentence(e.describe));
    }

    final problems = bundle.payload.validate();
    if (problems.isNotEmpty) {
      return RestoreRefused(
        'The backup holds data that does not fit together, so restoring it '
        'would fail.',
        problems: [for (final problem in problems) '$problem'],
      );
    }

    final Map<String, int> currentCounts;
    try {
      currentCounts = await repository.countBackupRows();
    } catch (e) {
      return RestoreRefused('Could not read what is on this device ($e).');
    }

    return RestoreReady(RestorePlan(
      fileName: fileName,
      manifest: bundle.manifest,
      payload: bundle.payload,
      currentCounts: currentCounts,
    ));
  }

  Future<RestoreResult> apply(RestorePlan plan) async {
    try {
      await repository.restoreBackupPayload(plan.payload);
      return RestoreResult.restored(plan.payload.rowCounts);
    } catch (e) {
      return RestoreResult.failed('$e');
    }
  }

  static String _megabytes(int bytes) =>
      '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';

  /// The codec's messages are lower-case clauses, written to follow a colon.
  static String _sentence(String message) {
    if (message.isEmpty) return message;
    final capital = message[0].toUpperCase() + message.substring(1);
    return capital.endsWith('.') ? capital : '$capital.';
  }
}
