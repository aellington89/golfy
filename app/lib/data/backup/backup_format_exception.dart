/// Why a backup file could not be read (#69).
///
/// Each case is a distinct, reportable reason — a restore (#70) turns these
/// into something a person can act on, so "the file is bad" is never the whole
/// message.
enum BackupFormatProblem {
  /// Not JSON at all, or not a JSON object at the top level.
  notJson,

  /// No `golfyBackup` envelope — very likely not a Golfy backup.
  missingManifest,

  /// The envelope is there but a field is missing or the wrong type.
  badManifestField,

  /// A container version this build does not know how to read.
  unsupportedFormatVersion,

  /// Written by a newer Golfy than this one; its rows may carry columns this
  /// build has never heard of, so it is refused rather than half-read.
  newerSchemaVersion,

  /// Written at an older drift schema with no registered upgrader. Cannot
  /// happen with a file Golfy produced — export did not exist before v7 — but
  /// a hand-made file can claim anything.
  unsupportedSchemaVersion,

  /// No `data` object.
  missingData,

  /// `data` is missing a table the schema expects.
  missingTable,

  /// `data` carries a table the schema does not have.
  unknownTable,

  /// A row would not decode: a missing, extra or wrongly-typed column.
  badRow,

  /// The manifest's `rowCounts` disagree with the rows actually present —
  /// a truncated or edited file.
  rowCountMismatch,
}

/// Thrown by `BackupCodec.decode` when a file cannot be trusted.
///
/// Decoding is **total**: it either returns a complete payload or throws. There
/// is no partially-understood backup, because a restore that acts on one would
/// silently lose data.
class BackupFormatException implements Exception {
  const BackupFormatException(
    this.problem,
    this.message, {
    this.table,
    this.rowIndex,
    this.cause,
  });

  final BackupFormatProblem problem;
  final String message;

  /// SQL table name, where the problem belongs to one.
  final String? table;

  /// 0-based position within that table's rows, where the problem is a row.
  final int? rowIndex;

  /// The underlying error, for a row that failed to decode.
  final Object? cause;

  /// A one-line description for a snackbar or a log.
  String get describe {
    final where = switch ((table, rowIndex)) {
      (final String t, final int i) => ' ($t, row ${i + 1})',
      (final String t, null) => ' ($t)',
      _ => '',
    };
    return '$message$where';
  }

  @override
  String toString() => 'BackupFormatException(${problem.name}): $describe';
}
