import 'package:drift/drift.dart' show DataClass;

import '../database.dart';

/// Every table in a backup, **parents first** (#69).
///
/// A file is written in this order so it reads top-down and so a future
/// streaming importer could insert as it parses. An importer must not *depend*
/// on it: it uses this list itself, so a hand-edited file whose keys come in
/// another order still restores correctly. See `BACKUP_FORMAT.md`.
const List<String> backupTableOrder = <String>[
  'courses',
  'course_holes',
  'tee_sets',
  'course_yards',
  'pin_sets',
  'tee_to_pin_yards',
  'events',
  'rounds',
  'hole_results',
  'hole_shots',
];

/// One problem found by [BackupPayload.validate] — something a restore would
/// otherwise discover halfway through writing.
class BackupProblem {
  const BackupProblem(this.table, this.detail, {this.rowIndex});

  final String table;
  final String detail;

  /// 0-based position in that table's rows, where the problem is one row's.
  final int? rowIndex;

  @override
  String toString() => rowIndex == null
      ? '$table: $detail'
      : '$table row ${rowIndex! + 1}: $detail';

  @override
  bool operator ==(Object other) =>
      other is BackupProblem &&
      other.table == table &&
      other.detail == detail &&
      other.rowIndex == rowIndex;

  @override
  int get hashCode => Object.hash(table, detail, rowIndex);
}

/// Every row of every table, typed (#69).
///
/// Typed lists rather than loose maps on purpose: adding a table to the schema
/// is then a compile error here, not a silent omission from everyone's backups,
/// and drift's row classes carry value equality, so a round-trip test is one
/// `expect`.
class BackupPayload {
  const BackupPayload({
    required this.courses,
    required this.courseHoles,
    required this.teeSets,
    required this.courseYards,
    required this.pinSets,
    required this.teeToPinYards,
    required this.events,
    required this.rounds,
    required this.holeResults,
    required this.holeShots,
  });

  const BackupPayload.empty()
      : courses = const <Course>[],
        courseHoles = const <CourseHole>[],
        teeSets = const <TeeSet>[],
        courseYards = const <CourseYard>[],
        pinSets = const <PinSet>[],
        teeToPinYards = const <TeeToPinYard>[],
        events = const <Event>[],
        rounds = const <Round>[],
        holeResults = const <HoleResult>[],
        holeShots = const <HoleShot>[];

  final List<Course> courses;
  final List<CourseHole> courseHoles;
  final List<TeeSet> teeSets;
  final List<CourseYard> courseYards;
  final List<PinSet> pinSets;
  final List<TeeToPinYard> teeToPinYards;
  final List<Event> events;
  final List<Round> rounds;
  final List<HoleResult> holeResults;
  final List<HoleShot> holeShots;

  /// Every table keyed by SQL table name, in [backupTableOrder].
  ///
  /// This is also what the table-coverage guard test reads: it compares these
  /// keys against the live schema's `allTables`, so the day an eleventh table
  /// is added, the suite fails until it is backed up too.
  Map<String, List<DataClass>> get tables => <String, List<DataClass>>{
        'courses': courses,
        'course_holes': courseHoles,
        'tee_sets': teeSets,
        'course_yards': courseYards,
        'pin_sets': pinSets,
        'tee_to_pin_yards': teeToPinYards,
        'events': events,
        'rounds': rounds,
        'hole_results': holeResults,
        'hole_shots': holeShots,
      };

  Map<String, int> get rowCounts => <String, int>{
        for (final entry in tables.entries) entry.key: entry.value.length,
      };

  int get totalRows =>
      rowCounts.values.fold<int>(0, (sum, count) => sum + count);

  bool get isEmpty => totalRows == 0;

  /// The same payload with some tables replaced.
  BackupPayload copyWith({
    List<Course>? courses,
    List<CourseHole>? courseHoles,
    List<TeeSet>? teeSets,
    List<CourseYard>? courseYards,
    List<PinSet>? pinSets,
    List<TeeToPinYard>? teeToPinYards,
    List<Event>? events,
    List<Round>? rounds,
    List<HoleResult>? holeResults,
    List<HoleShot>? holeShots,
  }) {
    return BackupPayload(
      courses: courses ?? this.courses,
      courseHoles: courseHoles ?? this.courseHoles,
      teeSets: teeSets ?? this.teeSets,
      courseYards: courseYards ?? this.courseYards,
      pinSets: pinSets ?? this.pinSets,
      teeToPinYards: teeToPinYards ?? this.teeToPinYards,
      events: events ?? this.events,
      rounds: rounds ?? this.rounds,
      holeResults: holeResults ?? this.holeResults,
      holeShots: holeShots ?? this.holeShots,
    );
  }

  /// Cross-table checks a restore runs **before** it writes anything (#70).
  ///
  /// SQLite would catch all of this itself, mid-transaction, as a constraint
  /// error naming nothing a person could act on. Doing it here first means a
  /// bad file is refused with a readable reason and an untouched database.
  ///
  /// Covers what cannot be checked one row at a time: ids present and unique,
  /// every foreign key resolvable *within the file*, no duplicated unique key,
  /// hole / shot numbering in range, and every yardage set on one course. Per-
  /// column CHECK constraints stay the database's job.
  List<BackupProblem> validate() {
    final problems = <BackupProblem>[];

    // Every table's ids are checked; only the ones something references are
    // kept, since the rest have nothing pointing at them.
    final courseIds = _ids(problems, 'courses', courses, (r) => r.id);
    final teeSetIds = _ids(problems, 'tee_sets', teeSets, (r) => r.id);
    final pinSetIds = _ids(problems, 'pin_sets', pinSets, (r) => r.id);
    final eventIds = _ids(problems, 'events', events, (r) => r.id);
    final roundIds = _ids(problems, 'rounds', rounds, (r) => r.id);
    final holeResultIds =
        _ids(problems, 'hole_results', holeResults, (r) => r.id);
    _ids(problems, 'course_holes', courseHoles, (r) => r.id);
    _ids(problems, 'course_yards', courseYards, (r) => r.id);
    _ids(problems, 'tee_to_pin_yards', teeToPinYards, (r) => r.id);
    _ids(problems, 'hole_shots', holeShots, (r) => r.id);

    // ── Foreign keys, resolvable inside the file ────────────────────────────
    _references(problems, 'course_holes', courseHoles, 'course_id',
        (r) => r.courseId, courseIds, 'courses');
    _references(problems, 'tee_sets', teeSets, 'course_id',
        (r) => r.courseId, courseIds, 'courses');
    _references(problems, 'course_yards', courseYards, 'tee_set_id',
        (r) => r.teeSetId, teeSetIds, 'tee_sets');
    _references(problems, 'pin_sets', pinSets, 'course_id',
        (r) => r.courseId, courseIds, 'courses');
    _references(problems, 'tee_to_pin_yards', teeToPinYards, 'tee_set_id',
        (r) => r.teeSetId, teeSetIds, 'tee_sets');
    _references(problems, 'tee_to_pin_yards', teeToPinYards, 'pin_set_id',
        (r) => r.pinSetId, pinSetIds, 'pin_sets');
    _references(problems, 'rounds', rounds, 'course_id', (r) => r.courseId,
        courseIds, 'courses');
    _references(problems, 'rounds', rounds, 'tee_set_id',
        (r) => r.teeSetId, teeSetIds, 'tee_sets');
    _references(problems, 'rounds', rounds, 'pin_set_id',
        (r) => r.pinSetId, pinSetIds, 'pin_sets');
    _references(problems, 'rounds', rounds, 'event_id', (r) => r.eventId,
        eventIds, 'events');
    _references(problems, 'hole_results', holeResults, 'round_id',
        (r) => r.roundId, roundIds, 'rounds');
    _references(problems, 'hole_shots', holeShots, 'hole_result_id',
        (r) => r.holeResultId, holeResultIds, 'hole_results');

    // ── Unique keys, as the schema declares them ───────────────────────────
    _unique(problems, 'courses', courses, '(name, game_title)',
        (r) => '${r.name}\u0000${r.gameTitle}');
    _unique(problems, 'course_holes', courseHoles, '(course_id, hole_number)',
        (r) => '${r.courseId}\u0000${r.holeNumber}');
    _unique(problems, 'tee_sets', teeSets, '(course_id, name)',
        (r) => '${r.courseId}\u0000${r.name}');
    _unique(problems, 'course_yards', courseYards, '(tee_set_id, hole_number)',
        (r) => '${r.teeSetId}\u0000${r.holeNumber}');
    _unique(problems, 'pin_sets', pinSets, '(course_id, name)',
        (r) => '${r.courseId}\u0000${r.name}');
    _unique(problems, 'tee_to_pin_yards', teeToPinYards,
        '(tee_set_id, pin_set_id, hole_number)',
        (r) => '${r.teeSetId}\u0000${r.pinSetId}\u0000${r.holeNumber}');
    _unique(problems, 'events', events, '(name, season)',
        (r) => '${r.name}\u0000${r.season}');
    _unique(problems, 'rounds', rounds, '(date, course_id, round_number)',
        (r) => '${r.date}\u0000${r.courseId}\u0000${r.roundNumber}');
    _unique(problems, 'hole_results', holeResults, '(round_id, hole_number)',
        (r) => '${r.roundId}\u0000${r.holeNumber}');
    _unique(problems, 'hole_shots', holeShots, '(hole_result_id, shot_number)',
        (r) => '${r.holeResultId}\u0000${r.shotNumber}');

    // ── Numbering ──────────────────────────────────────────────────────────
    _holeNumbers(problems, 'course_holes', courseHoles, (r) => r.holeNumber);
    _holeNumbers(problems, 'course_yards', courseYards, (r) => r.holeNumber);
    _holeNumbers(
        problems, 'tee_to_pin_yards', teeToPinYards, (r) => r.holeNumber);
    _holeNumbers(problems, 'hole_results', holeResults, (r) => r.holeNumber);
    for (var i = 0; i < holeShots.length; i++) {
      if (holeShots[i].shotNumber < 1) {
        problems.add(BackupProblem(
          'hole_shots',
          'shot_number ${holeShots[i].shotNumber} is below 1',
          rowIndex: i,
        ));
      }
    }

    // ── One course per yardage set ─────────────────────────────────────────
    // A tee set and a pin set only pair up on the same course, and a round's
    // sets are its own course's. SQL can't say either across parent tables,
    // so the DAOs enforce it on write and this on restore.
    final teeCourse = {for (final s in teeSets) s.id: s.courseId};
    final pinCourse = {for (final s in pinSets) s.id: s.courseId};
    for (var i = 0; i < teeToPinYards.length; i++) {
      final row = teeToPinYards[i];
      final tee = teeCourse[row.teeSetId];
      final pin = pinCourse[row.pinSetId];
      if (tee != null && pin != null && tee != pin) {
        problems.add(BackupProblem(
          'tee_to_pin_yards',
          'tee_set_id ${row.teeSetId} and pin_set_id ${row.pinSetId} are on '
          'different courses',
          rowIndex: i,
        ));
      }
    }
    for (var i = 0; i < rounds.length; i++) {
      final row = rounds[i];
      final tee = teeCourse[row.teeSetId];
      if (tee != null && tee != row.courseId) {
        problems.add(BackupProblem(
          'rounds',
          'tee_set_id ${row.teeSetId} is not on course ${row.courseId}',
          rowIndex: i,
        ));
      }
      final pin = pinCourse[row.pinSetId];
      if (pin != null && pin != row.courseId) {
        problems.add(BackupProblem(
          'rounds',
          'pin_set_id ${row.pinSetId} is not on course ${row.courseId}',
          rowIndex: i,
        ));
      }
    }

    return problems;
  }

  Set<int> _ids<T>(
    List<BackupProblem> problems,
    String table,
    List<T> rows,
    int Function(T) id,
  ) {
    final seen = <int>{};
    for (var i = 0; i < rows.length; i++) {
      final value = id(rows[i]);
      if (value < 1) {
        problems.add(BackupProblem(table, 'id $value is not a row id',
            rowIndex: i));
        continue;
      }
      if (!seen.add(value)) {
        problems.add(BackupProblem(table, 'id $value appears twice',
            rowIndex: i));
      }
    }
    return seen;
  }

  void _references<T>(
    List<BackupProblem> problems,
    String table,
    List<T> rows,
    String column,
    int? Function(T) reference,
    Set<int> targets,
    String targetTable,
  ) {
    for (var i = 0; i < rows.length; i++) {
      final value = reference(rows[i]);
      if (value == null) continue; // a nullable link that isn't set
      if (!targets.contains(value)) {
        problems.add(BackupProblem(
          table,
          '$column $value is not in $targetTable',
          rowIndex: i,
        ));
      }
    }
  }

  void _unique<T>(
    List<BackupProblem> problems,
    String table,
    List<T> rows,
    String label,
    String Function(T) key,
  ) {
    final seen = <String>{};
    for (var i = 0; i < rows.length; i++) {
      if (!seen.add(key(rows[i]))) {
        problems.add(BackupProblem(
          table,
          'duplicates another row on $label',
          rowIndex: i,
        ));
      }
    }
  }

  void _holeNumbers<T>(
    List<BackupProblem> problems,
    String table,
    List<T> rows,
    int Function(T) holeNumber,
  ) {
    for (var i = 0; i < rows.length; i++) {
      final value = holeNumber(rows[i]);
      if (value < 1 || value > 18) {
        problems.add(BackupProblem(
          table,
          'hole_number $value is outside 1-18',
          rowIndex: i,
        ));
      }
    }
  }

  @override
  bool operator ==(Object other) {
    if (other is! BackupPayload) return false;
    final mine = tables;
    final theirs = other.tables;
    for (final table in backupTableOrder) {
      if (!_sameRows(mine[table]!, theirs[table]!)) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(
        <Object?>[for (final rows in tables.values) Object.hashAll(rows)],
      );

  @override
  String toString() => 'BackupPayload($rowCounts)';
}

bool _sameRows(List<DataClass> a, List<DataClass> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
