import 'dart:convert';

import 'package:drift/drift.dart' show DataClass;

import '../database.dart';
import '../upgrades/putts_in_feet.dart';
import '../upgrades/split_yardage_sets.dart';
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
  /// of the next version. One that replaces tables checks the file's counts
  /// for them first, then counts what it wrote — so every count checked after
  /// the upgrade is still one the file vouched for.
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

  /// v8's yardage sets were each one tee set + pin set pair, named "Tee Set -
  /// Pin Set" and holding the pair's tee-to-pin yards. Exactly what the v8 ->
  /// v9 database migration does, by the same rule ([splitYardageSets]), so a
  /// restored v8 backup matches a migrated v8 database:
  ///
  /// * `course_sets` and `course_set_yards` are replaced by `tee_sets`,
  ///   `pin_sets`, `tee_to_pin_yards` and — for a set whose name named no pin
  ///   set — `course_yards`;
  /// * each round's `course_set_id` becomes its `tee_set_id` + `pin_set_id`,
  ///   both cleared when that set is another course's, which v9 refuses, and
  ///   the never-written `tee_set` label goes.
  ///
  /// The two old tables are read strictly, since their rows are rebuilt rather
  /// than carried: a missing or unexpected column, a duplicated set id, a
  /// yard or round naming a set the file lacks, or a count the file got wrong
  /// is refused here, with the old table's name.
  static void _upgradeFrom8(
    Map<String, Object?> data,
    Map<String, int> rowCounts,
  ) {
    final sets = <V8YardageSet>[
      for (final (index, row) in _v8Rows(
          data, rowCounts, 'course_sets', const ['id', 'course_id', 'name']))
        (
          id: _v8Int(row, 'id', 'course_sets', index),
          courseId: _v8Int(row, 'course_id', 'course_sets', index),
          name: _v8String(row, 'name', 'course_sets', index),
        ),
    ];
    final setIds = <int>{};
    for (final (index, set) in sets.indexed) {
      if (!setIds.add(set.id)) {
        throw BackupFormatException(
          BackupFormatProblem.badRow,
          'id ${set.id} appears twice',
          table: 'course_sets',
          rowIndex: index,
        );
      }
    }
    final yards = <V8SetYard>[
      for (final (index, row) in _v8Rows(data, rowCounts, 'course_set_yards',
          const ['id', 'course_set_id', 'hole_number', 'yards']))
        (
          id: _v8Int(row, 'id', 'course_set_yards', index),
          courseSetId: _v8SetId(row, setIds, 'course_set_yards', index)!,
          holeNumber: _v8Int(row, 'hole_number', 'course_set_yards', index),
          yards: _v8Int(row, 'yards', 'course_set_yards', index),
        ),
    ];

    final split = splitYardageSets(sets, yards);
    data.remove('course_sets');
    data.remove('course_set_yards');
    rowCounts.remove('course_sets');
    rowCounts.remove('course_set_yards');
    void write(String table, List<Map<String, Object?>> rows) {
      data[table] = rows;
      rowCounts[table] = rows.length;
    }

    write('tee_sets', [
      for (final t in split.teeSets)
        {'id': t.id, 'course_id': t.courseId, 'name': t.name},
    ]);
    write('pin_sets', [
      for (final p in split.pinSets)
        {'id': p.id, 'course_id': p.courseId, 'name': p.name},
    ]);
    write('course_yards', [
      for (final y in split.courseYards)
        {
          'id': y.id,
          'tee_set_id': y.teeSetId,
          'hole_number': y.holeNumber,
          'yards': y.yards,
        },
    ]);
    write('tee_to_pin_yards', [
      for (final y in split.teeToPinYards)
        {
          'id': y.id,
          'tee_set_id': y.teeSetId,
          'pin_set_id': y.pinSetId,
          'hole_number': y.holeNumber,
          'yards': y.yards,
        },
    ]);

    final rounds = data['rounds'];
    if (rounds is! List) return; // decoding refuses it, with its reason
    for (var index = 0; index < rounds.length; index++) {
      final row = rounds[index];
      if (row is! Map<String, Object?>) continue;
      for (final column in const ['tee_set_id', 'pin_set_id']) {
        if (row.containsKey(column)) {
          throw BackupFormatException(
            BackupFormatProblem.badRow,
            'row has `$column`, which data version 8 does not have',
            table: 'rounds',
            rowIndex: index,
          );
        }
      }
      if (!row.containsKey('course_set_id')) {
        throw BackupFormatException(
          BackupFormatProblem.badRow,
          'row is missing `course_set_id`',
          table: 'rounds',
          rowIndex: index,
        );
      }
      final setId = _v8SetId(row, setIds, 'rounds', index);
      row.remove('course_set_id');
      row.remove('tee_set');
      final pair = setId == null ? null : split.bySetId[setId];
      final onCourse = pair != null && pair.courseId == row['course_id'];
      row['tee_set_id'] = onCourse ? pair.teeSetId : null;
      row['pin_set_id'] = onCourse ? pair.pinSetId : null;
    }
  }

  /// A v8 table whose rows the upgrade rebuilds, read strictly: a list of
  /// objects with exactly [columns], as many as the file's `rowCounts` says.
  static Iterable<(int, Map<String, Object?>)> _v8Rows(
    Map<String, Object?> data,
    Map<String, int> rowCounts,
    String table,
    List<String> columns,
  ) {
    final rows = data[table];
    if (rows is! List) {
      throw BackupFormatException(
        BackupFormatProblem.missingTable,
        '`data.$table` must be a list of rows',
        table: table,
      );
    }
    final claimed = rowCounts[table];
    if (claimed != rows.length) {
      throw BackupFormatException(
        BackupFormatProblem.rowCountMismatch,
        claimed == null
            ? 'the backup does not say how many `$table` rows it holds'
            : 'the backup says it holds $claimed `$table` rows but carries '
                '${rows.length} — the file looks incomplete or edited',
        table: table,
      );
    }
    final read = <(int, Map<String, Object?>)>[];
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      if (row is! Map<String, Object?>) {
        throw BackupFormatException(
          BackupFormatProblem.badRow,
          'row is not an object',
          table: table,
          rowIndex: index,
        );
      }
      final missing = [
        for (final c in columns)
          if (!row.containsKey(c)) c,
      ];
      final unknown = [
        for (final c in row.keys)
          if (!columns.contains(c)) c,
      ]..sort();
      if (missing.isNotEmpty || unknown.isNotEmpty) {
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
      read.add((index, row));
    }
    return read;
  }

  static int _v8Int(
    Map<String, Object?> row,
    String column,
    String table,
    int index,
  ) {
    final value = row[column];
    if (value is int) return value;
    throw BackupFormatException(
      BackupFormatProblem.badRow,
      '`$column` must be a whole number',
      table: table,
      rowIndex: index,
    );
  }

  static String _v8String(
    Map<String, Object?> row,
    String column,
    String table,
    int index,
  ) {
    final value = row[column];
    if (value is String) return value;
    throw BackupFormatException(
      BackupFormatProblem.badRow,
      '`$column` must be text',
      table: table,
      rowIndex: index,
    );
  }

  /// A row's `course_set_id`: null, or one of the file's [setIds]. A set the
  /// file lacks can't be split, so it is refused here rather than left for
  /// validation, which would never see the old id.
  static int? _v8SetId(
    Map<String, Object?> row,
    Set<int> setIds,
    String table,
    int index,
  ) {
    final value = row['course_set_id'];
    if (value == null) {
      if (table == 'rounds') return null;
    } else if (value is int && setIds.contains(value)) {
      return value;
    }
    throw BackupFormatException(
      BackupFormatProblem.badRow,
      value is int
          ? 'course_set_id $value is not in course_sets'
          : '`course_set_id` must be a whole number',
      table: table,
      rowIndex: index,
    );
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
