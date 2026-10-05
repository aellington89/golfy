import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

import '../repository.dart';
import 'backup_codec.dart';
import 'backup_destination.dart';
import 'backup_manifest.dart';
import 'backup_payload.dart';

/// What one Export attempt produced (#69) — enough for the UI to say something
/// specific, which matters because "export did nothing" is the worst failure a
/// backup feature can have.
class BackupResult {
  const BackupResult({
    required this.status,
    required this.fileName,
    required this.rowCounts,
    this.location,
    this.error,
  });

  final BackupSaveStatus status;

  /// The name the file was given, whatever became of it.
  final String fileName;

  /// Rows written, per table.
  final Map<String, int> rowCounts;

  /// Where it landed, when the platform says (Windows).
  final String? location;

  final String? error;

  int get totalRows =>
      rowCounts.values.fold<int>(0, (sum, count) => sum + count);

  bool get isSuccess =>
      status == BackupSaveStatus.saved || status == BackupSaveStatus.shared;
}

/// Builds a backup file and hands it to the platform (#69).
///
/// Reads every table in one transaction, wraps it in a manifest, encodes it,
/// checks it can be read back, and only then lets [BackupDestination] put it
/// somewhere. Returns a [BackupResult] and never throws at its caller: an
/// export that fails silently is worse than one that fails loudly.
class BackupService {
  BackupService({
    required this.repository,
    required this.destination,
    Future<String> Function()? readAppVersion,
    DateTime Function()? clock,
    String? platformName,
  })  : _readAppVersion = readAppVersion ?? _appVersionFromPackageInfo,
        _clock = clock ?? DateTime.now,
        _platformName = platformName ?? Platform.operatingSystem;

  final GolfyRepository repository;
  final BackupDestination destination;
  final Future<String> Function() _readAppVersion;
  final DateTime Function() _clock;
  final String _platformName;

  Future<BackupResult> createBackup() async {
    final now = _clock();
    final fileName = backupFileName(now);

    final BackupPayload payload;
    try {
      payload = await repository.readBackupPayload();
    } catch (e) {
      return BackupResult(
        status: BackupSaveStatus.failed,
        fileName: fileName,
        rowCounts: const <String, int>{},
        error: 'could not read your data ($e)',
      );
    }

    final String contents;
    try {
      final manifest = BackupManifest(
        formatVersion: BackupManifest.currentFormatVersion,
        schemaVersion: BackupCodec.supportedSchemaVersion,
        appVersion: await _readAppVersion(),
        exportedAt: now.toUtc(),
        platform: _platformName,
        rowCounts: payload.rowCounts,
      );
      contents = BackupCodec.encode(manifest, payload);
      _verifyReadableBack(contents, payload);
    } catch (e) {
      return BackupResult(
        status: BackupSaveStatus.failed,
        fileName: fileName,
        rowCounts: payload.rowCounts,
        error: 'could not build the backup file ($e)',
      );
    }

    final outcome = await destination.save(
      fileName: fileName,
      contents: contents,
    );
    return BackupResult(
      status: outcome.status,
      fileName: fileName,
      rowCounts: payload.rowCounts,
      location: outcome.location,
      error: outcome.error,
    );
  }

  /// Reads the file we just wrote straight back, and refuses to hand over
  /// anything that does not decode to exactly what went in.
  ///
  /// The test suite proves the codec in general; this proves *this* file, on
  /// this device, with this data — a backup that cannot be imported is not a
  /// backup, and finding that out on the day it is needed is too late. It costs
  /// one extra parse of a file measured in megabytes.
  ///
  /// Deliberately checks the **file**, not the data in it:
  /// [BackupPayload.validate] is not run here. It answers "would these rows go
  /// back into a database", which is a restore's question (#70) and is asked
  /// there. If it were asked here, a cross-table oddity — or a bug in the check
  /// — would deny the user any backup at all, when the file they were refused
  /// is a faithful copy of what they have and the very thing a diagnosis would
  /// start from. Export's job is to be faithful; import's job is to be careful.
  void _verifyReadableBack(String contents, BackupPayload payload) {
    final bundle = BackupCodec.decode(contents);
    if (bundle.payload != payload) {
      throw StateError(
        'the backup did not read back as the data it was built from',
      );
    }
  }
}

/// `golfy-backup-20261003-1432.json`.
///
/// Local time, because that is the one a person recognises when they see the
/// file later; the manifest carries UTC for anything that reads it. A plain
/// `.json` extension keeps the file openable in every share target, mail client
/// and text editor — see `BACKUP_FORMAT.md` for why a Golfy-specific extension
/// was not worth it.
String backupFileName(DateTime when) {
  String two(int value) => value.toString().padLeft(2, '0');
  final stamp = '${when.year}${two(when.month)}${two(when.day)}'
      '-${two(when.hour)}${two(when.minute)}';
  return 'golfy-backup-$stamp.json';
}

Future<String> _appVersionFromPackageInfo() async {
  final info = await PackageInfo.fromPlatform();
  return info.buildNumber.isEmpty
      ? info.version
      : '${info.version}+${info.buildNumber}';
}
