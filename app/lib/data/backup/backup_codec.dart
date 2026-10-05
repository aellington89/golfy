import 'dart:convert';

import 'package:drift/drift.dart' show DataClass;

import '../database.dart';
import 'backup_format_exception.dart';
import 'backup_manifest.dart';
import 'backup_payload.dart';

/// A decoded backup file: its envelope and its rows (#69).
class BackupBundle {
  const BackupBundle(this.manifest, this.payload);

  final BackupManifest manifest;
  final BackupPayload payload;
}

/// Turns a [BackupPayload] into the backup file's text, and back (#69).
///
/// Pure: no database, no file system, no plugins. **Both directions ship with
/// the export feature on purpose** — a format is only a promise until
/// something reads it, so the reader and its tests exist before anyone holds a
/// file. Writing the rows back into the database is #70's.
///
/// The spec this implements is [`BACKUP_FORMAT.md`](../../../../BACKUP_FORMAT.md).
class BackupCodec {
  const BackupCodec._();

  /// The drift `schemaVersion` this build reads and writes.
  ///
  /// Duplicated from [GolfyDatabase.schemaVersion] deliberately: the backup
  /// format is a contract with files that already exist, so it should not
  /// silently follow a schema bump.
  /// `test/data/backup/backup_guards_test.dart` fails the day the two
  /// disagree, which is the prompt to decide whether old files can still be
  /// read and to register an upgrader below.
  static const int supportedSchemaVersion = 7;

  /// Payload upgraders, keyed by the schema version they upgrade **from**.
  ///
  /// Empty, and not an oversight: export did not exist before schema v7, so no
  /// Golfy build can ever have written an older backup. The registry is here so
  /// that the first schema bump after this one has an obvious home, and the
  /// guard test makes sure it is not forgotten.
  static const Map<int, BackupPayload Function(BackupPayload)> _upgraders =
      <int, BackupPayload Function(BackupPayload)>{};

  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

  /// Writes the file's text: the envelope, then every table parents-first with
  /// its rows ordered as given. Ends with a newline, like any other text file.
  static String encode(BackupManifest manifest, BackupPayload payload) {
    final tables = payload.tables;
    final data = <String, Object?>{
      for (final table in backupTableOrder)
        table: <Map<String, dynamic>>[
          for (final row in tables[table]!) row.toJson(),
        ],
    };
    return '${_encoder.convert(<String, Object?>{
          BackupManifest.jsonKey: manifest.toJson(),
          'data': data,
        })}\n';
  }

  /// Reads a backup file.
  ///
  /// Total: returns a complete [BackupBundle] or throws
  /// [BackupFormatException] naming what defeated it — there is no
  /// partially-understood backup, because a restore acting on one would lose
  /// data silently.
  static BackupBundle decode(String text) {
    final Object? root;
    try {
      root = jsonDecode(text);
    } on FormatException catch (e) {
      throw BackupFormatException(
        BackupFormatProblem.notJson,
        'the file is not valid JSON (${e.message})',
        cause: e,
      );
    }
    if (root is! Map<String, Object?>) {
      throw const BackupFormatException(
        BackupFormatProblem.notJson,
        'the file does not contain a JSON object',
      );
    }

    final envelope = root[BackupManifest.jsonKey];
    if (envelope is! Map<String, Object?>) {
      throw const BackupFormatException(
        BackupFormatProblem.missingManifest,
        'no `golfyBackup` section — this does not look like a Golfy backup',
      );
    }
    final manifest = BackupManifest.fromJson(envelope);

    if (manifest.formatVersion != BackupManifest.currentFormatVersion) {
      throw BackupFormatException(
        BackupFormatProblem.unsupportedFormatVersion,
        'backup format version ${manifest.formatVersion} cannot be read by '
        'this version of Golfy (it reads version '
        '${BackupManifest.currentFormatVersion})',
      );
    }
    if (manifest.schemaVersion > supportedSchemaVersion) {
      throw BackupFormatException(
        BackupFormatProblem.newerSchemaVersion,
        'this backup was made by a newer version of Golfy '
        '(data version ${manifest.schemaVersion}, this app reads up to '
        '$supportedSchemaVersion) — update Golfy and try again',
      );
    }
    if (manifest.schemaVersion < supportedSchemaVersion &&
        !_upgraders.containsKey(manifest.schemaVersion)) {
      throw BackupFormatException(
        BackupFormatProblem.unsupportedSchemaVersion,
        'this backup holds data version ${manifest.schemaVersion}, which this '
        'version of Golfy cannot upgrade',
      );
    }

    final data = root['data'];
    if (data is! Map<String, Object?>) {
      throw const BackupFormatException(
        BackupFormatProblem.missingData,
        'no `data` section — the backup carries no tables',
      );
    }
    for (final table in data.keys) {
      if (!backupTableOrder.contains(table)) {
        throw BackupFormatException(
          BackupFormatProblem.unknownTable,
          '`data.$table` is not a table this version of Golfy knows',
          table: table,
        );
      }
    }
    for (final table in backupTableOrder) {
      if (!data.containsKey(table)) {
        throw BackupFormatException(
          BackupFormatProblem.missingTable,
          '`data.$table` is missing',
          table: table,
        );
      }
    }

    var payload = BackupPayload(
      courses: _rows(data, 'courses', Course.fromJson),
      courseHoles: _rows(data, 'course_holes', CourseHole.fromJson),
      courseSets: _rows(data, 'course_sets', CourseSet.fromJson),
      courseSetYards:
          _rows(data, 'course_set_yards', CourseSetYard.fromJson),
      events: _rows(data, 'events', Event.fromJson),
      rounds: _rows(data, 'rounds', Round.fromJson),
      holeResults: _rows(data, 'hole_results', HoleResult.fromJson),
      holeShots: _rows(data, 'hole_shots', HoleShot.fromJson),
    );

    // The counts are checked against what the file *said*, before any
    // upgrader rewrites the payload.
    final counts = payload.rowCounts;
    for (final table in backupTableOrder) {
      final claimed = manifest.rowCounts[table];
      if (claimed == null) {
        throw BackupFormatException(
          BackupFormatProblem.rowCountMismatch,
          'the backup does not say how many `$table` rows it holds',
          table: table,
        );
      }
      if (claimed != counts[table]) {
        throw BackupFormatException(
          BackupFormatProblem.rowCountMismatch,
          'the backup says it holds $claimed `$table` rows but carries '
          '${counts[table]} — the file looks incomplete or edited',
          table: table,
        );
      }
    }

    for (var version = manifest.schemaVersion;
        version < supportedSchemaVersion;
        version++) {
      payload = _upgraders[version]!(payload);
    }

    return BackupBundle(manifest, payload);
  }

  static List<T> _rows<T extends DataClass>(
    Map<String, Object?> data,
    String table,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final raw = data[table];
    if (raw is! List) {
      throw BackupFormatException(
        BackupFormatProblem.missingTable,
        '`data.$table` must be a list of rows',
        table: table,
      );
    }

    final rows = <T>[];
    for (var index = 0; index < raw.length; index++) {
      final element = raw[index];
      if (element is! Map<String, Object?>) {
        throw BackupFormatException(
          BackupFormatProblem.badRow,
          'row is not an object',
          table: table,
          rowIndex: index,
        );
      }

      final T row;
      try {
        row = fromJson(Map<String, dynamic>.of(element));
      } catch (e) {
        throw BackupFormatException(
          BackupFormatProblem.badRow,
          'row could not be read ($e)',
          table: table,
          rowIndex: index,
          cause: e,
        );
      }
      _checkColumns(table, index, element.keys.toSet(), row);
      rows.add(row);
    }
    return rows;
  }

  /// Compares a row's keys against the columns the schema actually has.
  ///
  /// Worth doing even though [DataClass.fromJson] already threw on anything it
  /// could not read: a **nullable** column whose key is absent would otherwise
  /// decode quietly as null, turning a mangled file into silent data loss. The
  /// expected set comes from the row drift just built, so it tracks the schema
  /// with no list to maintain here.
  static void _checkColumns(
    String table,
    int index,
    Set<String> present,
    DataClass row,
  ) {
    final expected = row.toJson().keys.toSet();
    final missing = expected.difference(present).toList()..sort();
    final unknown = present.difference(expected).toList()..sort();
    if (missing.isEmpty && unknown.isEmpty) return;

    final detail = <String>[
      if (missing.isNotEmpty) 'missing ${missing.join(', ')}',
      if (unknown.isNotEmpty) 'unexpected ${unknown.join(', ')}',
    ].join('; ');
    throw BackupFormatException(
      BackupFormatProblem.badRow,
      'row columns do not match the `$table` table ($detail)',
      table: table,
      rowIndex: index,
    );
  }
}
