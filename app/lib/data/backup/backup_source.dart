import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The largest file a restore will read (#70).
///
/// A year of serious play is a few MB, so this is room for decades — and it
/// stops a video picked by mistake from being read into memory whole.
const int maxBackupFileBytes = 64 * 1024 * 1024;

/// What came of asking the user for a backup file (#70).
sealed class BackupPickOutcome {
  const BackupPickOutcome();
}

/// The user chose a file, and this is everything in it.
class BackupPicked extends BackupPickOutcome {
  const BackupPicked(this.fileName, this.bytes);

  final String fileName;
  final Uint8List bytes;
}

/// The user chose a file far too big to be a backup; it was not read.
class BackupTooLarge extends BackupPickOutcome {
  const BackupTooLarge(this.fileName, this.length);

  final String fileName;
  final int length;
}

/// The user backed out of the picker.
class BackupPickCancelled extends BackupPickOutcome {
  const BackupPickCancelled();
}

/// The picker or the read failed; [error] says how.
class BackupPickFailed extends BackupPickOutcome {
  const BackupPickFailed(this.error);

  final String error;
}

/// Where a backup file to restore comes from (#70) — the counterpart of
/// `BackupDestination`.
///
/// One method, behind an interface for the same reason: the platform pickers
/// cannot be unit-tested, so the restore service and the Settings screen are
/// tested with a fake through `backupSourceProvider`.
abstract class BackupSource {
  Future<BackupPickOutcome> pick();
}

/// The platform's own picker.
BackupSource createPlatformBackupSource() => const FileSelectorBackupSource();

/// `file_selector`'s *open* dialog, on both platforms. Unlike its save dialog,
/// it is implemented on Android, where it is the Storage Access Framework's
/// document picker — so Drive, Files and downloaded attachments all reach it.
class FileSelectorBackupSource implements BackupSource {
  const FileSelectorBackupSource();

  @override
  Future<BackupPickOutcome> pick() async {
    try {
      final file = await openFile(acceptedTypeGroups: [_typeGroup()]);
      if (file == null) return const BackupPickCancelled();
      try {
        return await readPickedBackup(file);
      } finally {
        await _discardAndroidCopy(file.path);
      }
    } catch (e) {
      return BackupPickFailed('$e');
    }
  }

  /// Windows filters on the extension. Android filters on MIME type, and a
  /// file that has been through Drive or a mail attachment does not always
  /// keep `application/json` — so it is offered the loose types too. Picking
  /// the wrong file costs nothing: decoding refuses anything that is not a
  /// backup, and says why.
  static XTypeGroup _typeGroup() {
    if (Platform.isAndroid) {
      return const XTypeGroup(
        label: 'Golfy backup',
        extensions: ['json'],
        mimeTypes: [
          'application/json',
          'text/plain',
          'application/octet-stream',
        ],
      );
    }
    return const XTypeGroup(label: 'Golfy backup', extensions: ['json']);
  }

  /// On Android the picker copies the chosen document into the app's cache
  /// (`cache/<uuid>/<name>`) so `dart:io` can read it; nothing else removes
  /// those copies. Only ever touches a path inside the cache — on Windows the
  /// path is the user's own file, and it is left alone.
  static Future<void> _discardAndroidCopy(String path) async {
    if (!Platform.isAndroid || path.isEmpty) return;
    try {
      final cache = (await getTemporaryDirectory()).path;
      final copy = File(path);
      if (!p.isWithin(cache, copy.path)) return;
      final folder = copy.parent;
      if (p.equals(folder.parent.path, cache)) {
        await folder.delete(recursive: true);
      } else {
        await copy.delete();
      }
    } catch (_) {
      // Best effort only — never fail a restore over tidying the cache. The
      // OS reclaims this directory anyway.
    }
  }
}

/// Reads a picked file, refusing to read one larger than [maxBytes].
///
/// Separate from the picker so it can be tested with an in-memory [XFile].
Future<BackupPickOutcome> readPickedBackup(
  XFile file, {
  int maxBytes = maxBackupFileBytes,
}) async {
  final length = await file.length();
  if (length > maxBytes) return BackupTooLarge(file.name, length);
  return BackupPicked(file.name, await file.readAsBytes());
}
