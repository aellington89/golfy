import 'package:drift/drift.dart';

import '../backup/backup_payload.dart';
import '../database.dart';
import '../tables/course_holes.dart';
import '../tables/course_yards.dart';
import '../tables/courses.dart';
import '../tables/events.dart';
import '../tables/hole_results.dart';
import '../tables/hole_shots.dart';
import '../tables/pin_sets.dart';
import '../tables/rounds.dart';
import '../tables/tee_sets.dart';
import '../tables/tee_to_pin_yards.dart';

part 'backup_dao.g.dart';

/// DAO for moving the whole database in one piece: reading it out for Export
/// (#69) and putting a backup back for Restore (#70).
///
/// It spans every table, so it belongs to none of the per-table DAOs — and the
/// write side in particular must not go through them: their invariants police
/// what a person types, while a restore replays rows that already passed them.
@DriftAccessor(
  tables: [
    Courses,
    CourseHoles,
    TeeSets,
    CourseYards,
    PinSets,
    TeeToPinYards,
    Events,
    Rounds,
    HoleResults,
    HoleShots,
  ],
)
class BackupDao extends DatabaseAccessor<GolfyDatabase> with _$BackupDaoMixin {
  BackupDao(super.db);

  /// Reads every table into a [BackupPayload].
  ///
  /// **One transaction**, so a hole saved while the export is running cannot
  /// produce a file holding the `hole_results` row without its `hole_shots` —
  /// a backup is a snapshot or it is nothing.
  ///
  /// Rows come back ordered by `id`, which makes two exports of the same data
  /// byte-identical and therefore diffable.
  Future<BackupPayload> readAll() {
    return transaction(() async {
      return BackupPayload(
        courses: await _allById(courses),
        courseHoles: await _allById(courseHoles),
        teeSets: await _allById(teeSets),
        courseYards: await _allById(courseYards),
        pinSets: await _allById(pinSets),
        teeToPinYards: await _allById(teeToPinYards),
        events: await _allById(events),
        rounds: await _allById(rounds),
        holeResults: await _allById(holeResults),
        holeShots: await _allById(holeShots),
      );
    });
  }

  /// Replaces every row of every table with [payload]'s, ids and all (#70).
  ///
  /// **One transaction**: children are deleted before parents, parents are
  /// inserted before children, and the result is read back and compared with
  /// [payload] before anything commits. If any of that throws — a CHECK
  /// constraint a hand-edited file breaks, a duplicate id, a read-back that
  /// disagrees — the transaction rolls back and the device is exactly as it
  /// was. That, rather than a copy of the copy, is the answer to "what if
  /// restore dies halfway".
  ///
  /// Does not run [BackupPayload.validate]; the caller has, and refuses the
  /// file with its reasons before this is reached. What this guarantees is
  /// atomicity, and the database's own constraints.
  ///
  /// Rows go in with the file's ids. SQLite's autoincrement counter only ever
  /// rises to the highest id it has seen, so rows recorded after a restore
  /// cannot collide with restored ones.
  Future<void> replaceAll(BackupPayload payload) {
    return transaction(() async {
      for (final table in backupTableOrder.reversed) {
        await delete(_tableNamed(table)).go();
      }

      // `toCompanion(false)` keeps an explicit null explicit, so a column
      // given a default later can't quietly turn a restored null into it.
      // Plain inserts, so a duplicate fails rather than overwriting.
      await batch((b) {
        b.insertAll(courses, [
          for (final r in payload.courses) r.toCompanion(false),
        ]);
        b.insertAll(courseHoles, [
          for (final r in payload.courseHoles) r.toCompanion(false),
        ]);
        b.insertAll(teeSets, [
          for (final r in payload.teeSets) r.toCompanion(false),
        ]);
        b.insertAll(courseYards, [
          for (final r in payload.courseYards) r.toCompanion(false),
        ]);
        b.insertAll(pinSets, [
          for (final r in payload.pinSets) r.toCompanion(false),
        ]);
        b.insertAll(teeToPinYards, [
          for (final r in payload.teeToPinYards) r.toCompanion(false),
        ]);
        b.insertAll(events, [
          for (final r in payload.events) r.toCompanion(false),
        ]);
        b.insertAll(rounds, [
          for (final r in payload.rounds) r.toCompanion(false),
        ]);
        b.insertAll(holeResults, [
          for (final r in payload.holeResults) r.toCompanion(false),
        ]);
        b.insertAll(holeShots, [
          for (final r in payload.holeShots) r.toCompanion(false),
        ]);
      });

      // The tests prove a restore in general; this proves *this* one. A file
      // whose rows went in as something other than themselves is rolled back
      // rather than left on the device. It costs one read.
      final restored = await readAll();
      if (restored != _sortedById(payload)) {
        throw StateError(
          'the restored data did not read back as the backup it came from',
        );
      }
    });
  }

  /// Rows per SQL table name, in [backupTableOrder] — what the device holds
  /// now, for a restore to show beside what the file holds (#70).
  Future<Map<String, int>> countRows() {
    return transaction(() async {
      return <String, int>{
        for (final table in backupTableOrder)
          table: await _count(_tableNamed(table)),
      };
    });
  }

  Future<int> _count(TableInfo<Table, Object?> table) async {
    final count = countAll();
    final query = selectOnly(table)..addColumns([count]);
    return (await query.getSingle()).read(count)!;
  }

  TableInfo<Table, Object?> _tableNamed(String name) {
    return attachedDatabase.allTables
        .firstWhere((t) => t.actualTableName == name);
  }

  /// [payload] as [readAll] returns it — ordered by id — so a hand-assembled
  /// file whose rows come in another order still reads back as itself.
  static BackupPayload _sortedById(BackupPayload payload) {
    List<T> byId<T>(List<T> rows, int Function(T) id) =>
        List<T>.of(rows)..sort((a, b) => id(a).compareTo(id(b)));
    return BackupPayload(
      courses: byId(payload.courses, (r) => r.id),
      courseHoles: byId(payload.courseHoles, (r) => r.id),
      teeSets: byId(payload.teeSets, (r) => r.id),
      courseYards: byId(payload.courseYards, (r) => r.id),
      pinSets: byId(payload.pinSets, (r) => r.id),
      teeToPinYards: byId(payload.teeToPinYards, (r) => r.id),
      events: byId(payload.events, (r) => r.id),
      rounds: byId(payload.rounds, (r) => r.id),
      holeResults: byId(payload.holeResults, (r) => r.id),
      holeShots: byId(payload.holeShots, (r) => r.id),
    );
  }

  /// Every row of [table], ordered by its `id` column.
  ///
  /// Keyed by column *name* rather than a typed getter so one helper covers
  /// all ten tables; every table in this schema has an autoincrement `id`.
  Future<List<D>> _allById<T extends Table, D>(TableInfo<T, D> table) {
    final query = select(table)
      ..orderBy([(_) => OrderingTerm.asc(table.columnsByName['id']!)]);
    return query.get();
  }
}
