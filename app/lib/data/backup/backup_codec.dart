import 'dart:convert';

import 'package:drift/drift.dart' show DataClass;

import '../database.dart';
import '../upgrades/putts_in_feet.dart';
import 'backup_format_exception.dart';
import 'backup_manifest.dart';
import 'backup_payload.dart';

/// A decoded backup file: its envelope and its rows (#69).
/// Rewrites an older file's raw rows, and its row counts, into the next
/// schema version's shape. See [BackupCodec._upgraders].
typedef _Upgrader = void Function(
  Map<String, Object?> data,
  Map<String, int> rowCounts,
);

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
  static const int supportedSchemaVersion = 9;

  /// Upgraders for an older file's rows, keyed by the schema version they
  /// upgrade **from**. Each one rewrites the raw `data` section into the shape
  /// of the next version, and the file's `rowCounts` with it where a table was
  /// renamed or added — so the counts can still be checked against what the
  /// file said.
  ///
  /// They run on the rows as JSON, before decoding, because a decoded row
  /// already has today's columns: checking a v7 row against them is exactly
  /// what refuses a file for being old rather than broken. Upgraded, the rows
  /// are decoded and checked like any current file's.
  ///
  /// Nothing below v7 is here, and never will be: export did not exist before
  /// schema v7, so no Golfy build can have written an older backup.
  static const Map<int, _Upgrader> _upgraders = <int, _Upgrader>{
    // v7 -> v8: putts record their distance in feet. No shot in a v7 file
    // has the column, and its putts saved with a distance have it in yards.
    7: _upgradeFrom7,
    // v8 -> v9: yardage splits into tee sets and pin sets.
    8: _upgradeFrom8,
  };

  /// The tables a file of data version 7 or 8 carries — before v9 split the
  /// yardage sets into tee sets and pin sets. Checked before upgrading, so an
  /// old file is refused for what *it* lacks, in its own table names.
  static const List<String> _tablesBeforeV9 = <String>[
    'courses',
    'course_holes',
    'course_sets',
    'course_set_yards',
    'events',
    'rounds',
    'hole_results',
    'hole_shots',
  ];

  static List<String> _tablesAt(int schemaVersion) =>
      schemaVersion < 9 ? _tablesBeforeV9 : backupTableOrder;

  static void _upgradeFrom7(
    Map<String, Object?> data,
    Map<String, int> rowCounts,
  ) {
    _addNullColumn(data, 'hole_shots', 'distance_feet', fromVersion: 7);
    _puttYardsToFeet(data);
  }

  /// v8 had one kind of yardage set, with one yardage per hole: a tee set and
  /// its course yards, in v9's terms. Exactly what the v8 -> v9 database
  /// migration does, so a restored v8 backup matches a migrated v8 database:
  ///
  /// * `course_sets` becomes `tee_sets`, rows unchanged;
  /// * `course_set_yards` becomes `course_yards`, `course_set_id` renamed
  ///   `tee_set_id`;
  /// * `pin_sets` and `tee_to_pin_yards` start empty;
  /// * each round's `course_set_id` becomes its `tee_set_id` — cleared when
  ///   that set is another course's, which v9 refuses — with `pin_set_id`
  ///   null, and the never-written `tee_set` label goes.
  static void _upgradeFrom8(
    Map<String, Object?> data,
    Map<String, int> rowCounts,
  ) {
    // Read before the rename: which course each v8 set is on.
    final setCourse = <Object?, Object?>{
      for (final row in _objects(data['course_sets']))
        row['id']: row['course_id'],
    };

    _renameTable(data, rowCounts, 'course_sets', 'tee_sets');
    _renameTable(data, rowCounts, 'course_set_yards', 'course_yards');
    _renameColumn(data, 'course_yards', 'course_set_id', 'tee_set_id',
        fromVersion: 8);
    data['pin_sets'] = <Object?>[];
    data['tee_to_pin_yards'] = <Object?>[];
    rowCounts['pin_sets'] = 0;
    rowCounts['tee_to_pin_yards'] = 0;

    _renameColumn(data, 'rounds', 'course_set_id', 'tee_set_id',
        fromVersion: 8);
    _addNullColumn(data, 'rounds', 'pin_set_id', fromVersion: 8);
    for (final row in _objects(data['rounds'])) {
      row.remove('tee_set');
      // Only a set the file has and puts on another course; a set it lacks
      // is a broken reference, left for validation to refuse.
      final teeSetId = row['tee_set_id'];
      if (setCourse.containsKey(teeSetId) &&
          setCourse[teeSetId] != row['course_id']) {
        row['tee_set_id'] = null;
      }
    }
  }

  /// Moves a table's rows, and its row count, to a new name.
  static void _renameTable(
    Map<String, Object?> data,
    Map<String, int> rowCounts,
    String from,
    String to,
  ) {
    data[to] = data.remove(from);
    final count = rowCounts.remove(from);
    if (count != null) rowCounts[to] = count;
  }

  /// Renames a column in every row of [table]. A row without [from] is
  /// refused, since a file of [fromVersion] always has it, as is one that
  /// already has [to], which it never does.
  static void _renameColumn(
    Map<String, Object?> data,
    String table,
    String from,
    String to, {
    required int fromVersion,
  }) {
    final rows = data[table];
    if (rows is! List) return;
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      if (row is! Map<String, Object?>) continue;
      if (!row.containsKey(from) || row.containsKey(to)) {
        throw BackupFormatException(
          BackupFormatProblem.badRow,
          row.containsKey(to)
              ? 'row has `$to`, which data version $fromVersion does not have'
              : 'row is missing `$from`',
          table: table,
          rowIndex: index,
        );
      }
      row[to] = row.remove(from);
    }
  }

  /// Rewrites the putts a v7 file saved in yards in feet, exactly as the v7 ->
  /// v8 migration rewrites a database: [puttsSavedInYards] decides which rows,
  /// for both. A row that doesn't hold what a v7 file holds is left alone —
  /// decoding refuses it, and the file with it, anyway.
  static void _puttYardsToFeet(Map<String, Object?> data) {
    final puttsByHole = <int, int>{
      for (final row in _objects(data['hole_results']))
        if ((row['id'], row['putts']) case (final int id, final int putts))
          id: putts,
    };
    // Each row with its own yards, so a file repeating an id (which validation
    // refuses later) can't make this throw.
    final rowsById = <int, (Map<String, Object?>, int?)>{};
    final shots = <V7Shot>[];
    for (final row in _objects(data['hole_shots'])) {
      if ((
        row['id'],
        row['hole_result_id'],
        row['shot_number'],
        row['club'],
        row['lie'],
        row['distance_yards'],
      )
          case (
            final int id,
            final int holeResultId,
            final int shotNumber,
            final String? club,
            final String? lie,
            final int? distanceYards,
          )) {
        rowsById[id] = (row, distanceYards);
        shots.add((
          id: id,
          holeResultId: holeResultId,
          shotNumber: shotNumber,
          club: club,
          lie: lie,
          distanceYards: distanceYards,
        ));
      }
    }
    for (final id in puttsSavedInYards(shots, puttsByHole)) {
      final (row, yards) = rowsById[id]!;
      if (yards == null) continue;
      row['distance_feet'] = yards * feetPerYard;
      row['distance_yards'] = null;
    }
  }

  static Iterable<Map<String, Object?>> _objects(Object? rows) =>
      rows is List ? rows.whereType<Map<String, Object?>>() : const [];

  /// Gives every row of [table] a null [column] — the upgrade for a nullable
  /// column added by a migration. Rows that aren't objects are left for
  /// decoding to refuse, with the reason it gives; a row that already has the
  /// column is refused here, since a file of [fromVersion] cannot.
  static void _addNullColumn(
    Map<String, Object?> data,
    String table,
    String column, {
    required int fromVersion,
  }) {
    final rows = data[table];
    if (rows is! List) return;
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      if (row is! Map<String, Object?>) continue;
      if (row.containsKey(column)) {
        throw BackupFormatException(
          BackupFormatProblem.badRow,
          'row has `$column`, which data version $fromVersion does not have',
          table: table,
          rowIndex: index,
        );
      }
      row[column] = null;
    }
  }

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
    final fileTables = _tablesAt(manifest.schemaVersion);
    for (final table in data.keys) {
      if (!fileTables.contains(table)) {
        throw BackupFormatException(
          BackupFormatProblem.unknownTable,
          '`data.$table` is not a table this version of Golfy knows',
          table: table,
        );
      }
    }
    for (final table in fileTables) {
      if (!data.containsKey(table)) {
        throw BackupFormatException(
          BackupFormatProblem.missingTable,
          '`data.$table` is missing',
          table: table,
        );
      }
    }

    // Bring an older file's rows up to this version before reading them.
    // Upgraders add, rename or rewrite columns and tables, never rows, so the
    // counts checked below are still the ones the file said — under the
    // table names they carry now.
    final rowCounts = Map<String, int>.of(manifest.rowCounts);
    for (var version = manifest.schemaVersion;
        version < supportedSchemaVersion;
        version++) {
      _upgraders[version]!(data, rowCounts);
    }

    final payload = BackupPayload(
      courses: _rows(data, 'courses', Course.fromJson),
      courseHoles: _rows(data, 'course_holes', CourseHole.fromJson),
      teeSets: _rows(data, 'tee_sets', TeeSet.fromJson),
      courseYards: _rows(data, 'course_yards', CourseYard.fromJson),
      pinSets: _rows(data, 'pin_sets', PinSet.fromJson),
      teeToPinYards: _rows(data, 'tee_to_pin_yards', TeeToPinYard.fromJson),
      events: _rows(data, 'events', Event.fromJson),
      rounds: _rows(data, 'rounds', Round.fromJson),
      holeResults: _rows(data, 'hole_results', HoleResult.fromJson),
      holeShots: _rows(data, 'hole_shots', HoleShot.fromJson),
    );

    // The counts are checked against what the file *said*.
    final counts = payload.rowCounts;
    for (final table in backupTableOrder) {
      final claimed = rowCounts[table];
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
