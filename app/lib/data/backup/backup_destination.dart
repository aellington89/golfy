import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// What became of a backup the user asked for (#69).
enum BackupSaveStatus {
  /// Written to a location the user chose (the Windows save dialog).
  saved,

  /// Handed to the system share sheet, which accepted it (Android).
  shared,

  /// The user backed out of the dialog or the share sheet.
  cancelled,

  /// Something went wrong; [BackupSaveOutcome.error] says what.
  failed,
}

/// The result of handing a finished backup file to the platform.
class BackupSaveOutcome {
  const BackupSaveOutcome.saved(this.location)
      : status = BackupSaveStatus.saved,
        error = null;

  const BackupSaveOutcome.shared()
      : status = BackupSaveStatus.shared,
        location = null,
        error = null;

  const BackupSaveOutcome.cancelled()
      : status = BackupSaveStatus.cancelled,
        location = null,
        error = null;

  const BackupSaveOutcome.failed(this.error)
      : status = BackupSaveStatus.failed,
        location = null;

  final BackupSaveStatus status;

  /// Where the file ended up, when the platform tells us (Windows).
  final String? location;

  final String? error;
}

/// Where a backup file goes once it has been written out (#69).
///
/// One method, because the two platforms do completely different things and
/// neither can be unit-tested:
///
///  * **Android** has no "save as" dialog available to Flutter at all — the
///    Storage Access Framework hands back a `content://` URI that `dart:io`
///    cannot write to, so `file_selector` does not implement a save location
///    there. A backup is written to the app's own cache and handed to the
///    system **share sheet**, which is how it reaches Drive, Files or mail.
///  * **Windows** opens an ordinary save dialog and the file is written
///    straight to the chosen path.
///
/// Keeping that behind an interface is also what lets the Settings screen and
/// the service be tested without a plugin in sight: tests override
/// `backupDestinationProvider` with a fake.
abstract class BackupDestination {
  Future<BackupSaveOutcome> save({
    required String fileName,
    required String contents,
  });
}

/// The platform's own destination: share sheet on Android / iOS, save dialog
/// everywhere else.
BackupDestination createPlatformBackupDestination() {
  if (Platform.isAndroid || Platform.isIOS) {
    return const ShareSheetBackupDestination();
  }
  return const SaveDialogBackupDestination();
}

/// Android: write to the app's cache, then let the user send it somewhere.
///
/// **The cache copy outlives the share sheet on purpose.** A receiving app may
/// read the content URI long after the sheet closes — Gmail holding a draft, a
/// cloud-drive app queueing an upload — so deleting the file the moment
/// `share` returns can leave the user with a 0-byte attachment *and* a
/// "Backup created" message, which is the worst failure this feature has.
/// `share_plus` says the same of the temporary files it writes itself: clean
/// them up "once in a while", not immediately.
///
/// So each export sweeps the *previous* backups out of the cache before
/// writing its own. One file at a time, app-private, and reclaimable by the OS
/// under pressure.
class ShareSheetBackupDestination implements BackupDestination {
  const ShareSheetBackupDestination();

  @override
  Future<BackupSaveOutcome> save({
    required String fileName,
    required String contents,
  }) async {
    try {
      final directory = await getTemporaryDirectory();
      await _sweepStaleBackups(directory, keep: fileName);
      final file = File(p.join(directory.path, fileName));
      await file.writeAsString(contents, flush: true);

      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          fileNameOverrides: [fileName],
          subject: 'Golfy backup',
        ),
      );

      return switch (result.status) {
        ShareResultStatus.success => const BackupSaveOutcome.shared(),
        ShareResultStatus.dismissed => const BackupSaveOutcome.cancelled(),
        ShareResultStatus.unavailable => const BackupSaveOutcome.failed(
            'no app on this device can receive the file',
          ),
      };
    } catch (e) {
      return BackupSaveOutcome.failed('$e');
    }
  }

  Future<void> _sweepStaleBackups(
    Directory directory, {
    required String keep,
  }) async {
    try {
      await for (final entity in directory.list()) {
        final name = p.basename(entity.path);
        if (entity is File &&
            name != keep &&
            name.startsWith('golfy-backup-') &&
            name.endsWith('.json')) {
          await entity.delete();
        }
      }
    } catch (_) {
      // Best effort only — never fail an export because the cache could not
      // be tidied. The OS reclaims this directory anyway.
    }
  }
}

/// Windows (and any desktop): an ordinary save dialog.
class SaveDialogBackupDestination implements BackupDestination {
  const SaveDialogBackupDestination();

  @override
  Future<BackupSaveOutcome> save({
    required String fileName,
    required String contents,
  }) async {
    try {
      final location = await getSaveLocation(
        suggestedName: fileName,
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Golfy backup', extensions: ['json']),
        ],
      );
      if (location == null) return const BackupSaveOutcome.cancelled();

      await File(location.path).writeAsString(contents, flush: true);
      return BackupSaveOutcome.saved(location.path);
    } catch (e) {
      return BackupSaveOutcome.failed('$e');
    }
  }
}
