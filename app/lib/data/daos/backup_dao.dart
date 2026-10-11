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

/// DAO for reading the whole database out in one piece, for the Export
/// feature (#69).
///
/// It spans every table, so it belongs to none of the per-table DAOs. #70's
/// write-side counterpart (restoring a decoded payload) lands here too, which
/// is the other reason it is its own accessor rather than a method bolted onto
/// one of theirs.
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
