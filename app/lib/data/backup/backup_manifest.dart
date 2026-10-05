import 'backup_format_exception.dart';

/// The envelope at the head of a Golfy backup file (#69) — everything about
/// the file that is not golf data.
///
/// Two version numbers travel with every backup, and they answer different
/// questions:
///
///  * [formatVersion] describes this envelope — the shape of the container.
///    It starts at 1 and only moves if the container itself changes.
///  * [schemaVersion] is the drift `schemaVersion` the rows were written at,
///    so a restore can tell whether it understands the data (#70).
///
/// [rowCounts] is the integrity check: a restore compares it against what it
/// actually parsed, which catches a doctored or half-written file that still
/// happens to be valid JSON. A truncated one fails to parse at all.
///
/// Deliberately carries **no device identifier** — [platform] is `android` or
/// `windows` and that is the whole of it. Everything else in a backup is golf
/// data the user typed in themselves.
class BackupManifest {
  const BackupManifest({
    required this.formatVersion,
    required this.schemaVersion,
    required this.appVersion,
    required this.exportedAt,
    required this.platform,
    required this.rowCounts,
  });

  /// The envelope version this build writes, and the only one it reads.
  static const int currentFormatVersion = 1;

  /// The key the envelope sits under in the file.
  static const String jsonKey = 'golfyBackup';

  final int formatVersion;
  final int schemaVersion;

  /// The app version that wrote the file, as `pubspec.yaml` spells it
  /// (`0.4.0+38`) — diagnostics only; nothing branches on it.
  final String appVersion;

  /// When the file was written, in UTC. The *file name* uses local time,
  /// because that is the one a person recognises; this is the one a machine
  /// should read.
  final DateTime exportedAt;

  /// `android` or `windows`.
  final String platform;

  /// Row count per SQL table name, as written.
  final Map<String, int> rowCounts;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'formatVersion': formatVersion,
        'schemaVersion': schemaVersion,
        'appVersion': appVersion,
        'exportedAt': exportedAt.toUtc().toIso8601String(),
        'platform': platform,
        'rowCounts': <String, int>{...rowCounts},
      };

  /// Parses an envelope, throwing [BackupFormatException] with a readable
  /// reason rather than a cast error — this is the first thing a restore reads
  /// from a file it has every reason to distrust.
  factory BackupManifest.fromJson(Map<String, dynamic> json) {
    int requireInt(String key) {
      final value = json[key];
      if (value is int) return value;
      throw BackupFormatException(
        BackupFormatProblem.badManifestField,
        '`${BackupManifest.jsonKey}.$key` must be a whole number, '
        'found ${_describe(value)}',
      );
    }

    String requireString(String key) {
      final value = json[key];
      if (value is String && value.isNotEmpty) return value;
      throw BackupFormatException(
        BackupFormatProblem.badManifestField,
        '`${BackupManifest.jsonKey}.$key` must be a non-empty string, '
        'found ${_describe(value)}',
      );
    }

    final exportedAtRaw = requireString('exportedAt');
    final exportedAt = DateTime.tryParse(exportedAtRaw);
    if (exportedAt == null) {
      throw BackupFormatException(
        BackupFormatProblem.badManifestField,
        '`${BackupManifest.jsonKey}.exportedAt` is not a date: '
        '"$exportedAtRaw"',
      );
    }

    final countsRaw = json['rowCounts'];
    if (countsRaw is! Map) {
      throw BackupFormatException(
        BackupFormatProblem.badManifestField,
        '`${BackupManifest.jsonKey}.rowCounts` must be an object, '
        'found ${_describe(countsRaw)}',
      );
    }
    final rowCounts = <String, int>{};
    for (final entry in countsRaw.entries) {
      final value = entry.value;
      if (entry.key is! String || value is! int) {
        throw BackupFormatException(
          BackupFormatProblem.badManifestField,
          '`${BackupManifest.jsonKey}.rowCounts` must map table names to '
          'whole numbers, found ${entry.key}: ${_describe(value)}',
        );
      }
      rowCounts[entry.key as String] = value;
    }

    return BackupManifest(
      formatVersion: requireInt('formatVersion'),
      schemaVersion: requireInt('schemaVersion'),
      appVersion: requireString('appVersion'),
      exportedAt: exportedAt.toUtc(),
      platform: requireString('platform'),
      rowCounts: rowCounts,
    );
  }

  @override
  String toString() => 'BackupManifest(format $formatVersion, '
      'schema $schemaVersion, $appVersion, $platform, '
      '${exportedAt.toIso8601String()})';
}

String _describe(Object? value) => value == null ? 'nothing' : '`$value`';
