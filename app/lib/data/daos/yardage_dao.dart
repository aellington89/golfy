import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/course_yards.dart';
import '../tables/pin_sets.dart';
import '../tables/tee_sets.dart';
import '../tables/tee_to_pin_yards.dart';

part 'yardage_dao.g.dart';

/// DAO for a course's yardage: its tee sets and pin sets, each tee set's
/// course yards, and the tee-to-pin yards of every (tee set, pin set) pair.
///
/// A round's **yardage set** is one of those pairs. Its per-hole yards are the
/// pair's tee-to-pin yards; a tee set's course yards are the scorecard numbers,
/// which no pin set changes.
@DriftAccessor(tables: [TeeSets, PinSets, CourseYards, TeeToPinYards])
class YardageDao extends DatabaseAccessor<GolfyDatabase>
    with _$YardageDaoMixin {
  YardageDao(super.db);

  // ── Tee sets ─────────────────────────────────────────────────────────────

  /// Reactive list of a course's tee sets, ordered by name.
  Stream<List<TeeSet>> watchTeeSetsForCourse(int courseId) {
    return (select(teeSets)
          ..where((s) => s.courseId.equals(courseId))
          ..orderBy([(s) => OrderingTerm.asc(s.name)]))
        .watch();
  }

  /// Inserts a tee set and returns its id. Throws on a duplicate
  /// `(courseId, name)` (schema-level UNIQUE).
  Future<int> insertTeeSet(TeeSetsCompanion set) => into(teeSets).insert(set);

  /// Renames a tee set. Throws on a duplicate `(courseId, name)`. Returns rows
  /// updated (1 if the set existed).
  Future<int> renameTeeSet(int id, String name) {
    return (update(teeSets)..where((s) => s.id.equals(id)))
        .write(TeeSetsCompanion(name: Value(name)));
  }

  /// Deletes a tee set. Its course yards and tee-to-pin yards cascade, and any
  /// round played from it is detached (`rounds.tee_set_id` SET NULL). Returns
  /// rows deleted.
  Future<int> deleteTeeSet(int id) {
    return (delete(teeSets)..where((s) => s.id.equals(id))).go();
  }

  // ── Pin sets ─────────────────────────────────────────────────────────────

  /// Reactive list of a course's pin sets, ordered by name.
  Stream<List<PinSet>> watchPinSetsForCourse(int courseId) {
    return (select(pinSets)
          ..where((s) => s.courseId.equals(courseId))
          ..orderBy([(s) => OrderingTerm.asc(s.name)]))
        .watch();
  }

  /// Inserts a pin set and returns its id. Throws on a duplicate
  /// `(courseId, name)` (schema-level UNIQUE).
  Future<int> insertPinSet(PinSetsCompanion set) => into(pinSets).insert(set);

  /// Renames a pin set. Throws on a duplicate `(courseId, name)`. Returns rows
  /// updated (1 if the set existed).
  Future<int> renamePinSet(int id, String name) {
    return (update(pinSets)..where((s) => s.id.equals(id)))
        .write(PinSetsCompanion(name: Value(name)));
  }

  /// Deletes a pin set. Its tee-to-pin yards cascade, and any round played to
  /// it is detached (`rounds.pin_set_id` SET NULL). Returns rows deleted.
  Future<int> deletePinSet(int id) {
    return (delete(pinSets)..where((s) => s.id.equals(id))).go();
  }

  // ── Course yards (per tee set) ───────────────────────────────────────────

  /// Reactive course yards for a tee set, ordered by hole number.
  Stream<List<CourseYard>> watchCourseYards(int teeSetId) {
    return (select(courseYards)
          ..where((y) => y.teeSetId.equals(teeSetId))
          ..orderBy([(y) => OrderingTerm.asc(y.holeNumber)]))
        .watch();
  }

  /// One-shot read of a tee set's course yards, ordered by hole number.
  Future<List<CourseYard>> getCourseYards(int teeSetId) {
    return (select(courseYards)
          ..where((y) => y.teeSetId.equals(teeSetId))
          ..orderBy([(y) => OrderingTerm.asc(y.holeNumber)]))
        .get();
  }

  /// Upserts one hole's course yards, keyed on `(tee_set_id, hole_number)`.
  /// The per-hole counterpart to [replaceCourseYards] — see
  /// `CourseHoleDao.upsertHole` for why it exists, and `HoleResultDao.upsert`
  /// for why the id is read back with `RETURNING`.
  Future<int> upsertCourseYard(CourseYardsCompanion yard) async {
    final row = await into(courseYards).insertReturning(
      yard,
      onConflict: DoUpdate(
        (_) => yard,
        target: [courseYards.teeSetId, courseYards.holeNumber],
      ),
    );
    return row.id;
  }

  /// Replaces a tee set's whole course-yards card in one transaction (mirrors
  /// `CourseHoleDao.replaceForCourse`). Each companion must carry
  /// `teeSetId == teeSetId`.
  Future<void> replaceCourseYards(
    int teeSetId,
    List<CourseYardsCompanion> yards,
  ) {
    return transaction(() async {
      await (delete(courseYards)..where((y) => y.teeSetId.equals(teeSetId)))
          .go();
      await batch((b) => b.insertAll(courseYards, yards));
    });
  }

  // ── Tee-to-pin yards (per tee set × pin set) ─────────────────────────────

  /// Reactive tee-to-pin yards for one yardage set — a (tee set, pin set)
  /// pair — ordered by hole number.
  Stream<List<TeeToPinYard>> watchTeeToPinYards(int teeSetId, int pinSetId) {
    return (select(teeToPinYards)
          ..where((y) =>
              y.teeSetId.equals(teeSetId) & y.pinSetId.equals(pinSetId))
          ..orderBy([(y) => OrderingTerm.asc(y.holeNumber)]))
        .watch();
  }

  /// One-shot read of a yardage set's tee-to-pin yards, ordered by hole number.
  Future<List<TeeToPinYard>> getTeeToPinYards(int teeSetId, int pinSetId) {
    return (select(teeToPinYards)
          ..where((y) =>
              y.teeSetId.equals(teeSetId) & y.pinSetId.equals(pinSetId))
          ..orderBy([(y) => OrderingTerm.asc(y.holeNumber)]))
        .get();
  }

  /// Upserts one hole's tee-to-pin yards, keyed on
  /// `(tee_set_id, pin_set_id, hole_number)`.
  ///
  /// Throws [ArgumentError] when the tee set and pin set belong to different
  /// courses — see [assertSameCourse].
  Future<int> upsertTeeToPinYard(TeeToPinYardsCompanion yard) {
    return transaction(() async {
      await assertSameCourse(yard.teeSetId.value, yard.pinSetId.value);
      final row = await into(teeToPinYards).insertReturning(
        yard,
        onConflict: DoUpdate(
          (_) => yard,
          target: [
            teeToPinYards.teeSetId,
            teeToPinYards.pinSetId,
            teeToPinYards.holeNumber,
          ],
        ),
      );
      return row.id;
    });
  }

  /// Replaces a yardage set's whole tee-to-pin card in one transaction. Each
  /// companion must carry the same [teeSetId] and [pinSetId].
  ///
  /// Throws [ArgumentError] when the two sets belong to different courses.
  Future<void> replaceTeeToPinYards(
    int teeSetId,
    int pinSetId,
    List<TeeToPinYardsCompanion> yards,
  ) {
    return transaction(() async {
      await assertSameCourse(teeSetId, pinSetId);
      await (delete(teeToPinYards)
            ..where((y) =>
                y.teeSetId.equals(teeSetId) & y.pinSetId.equals(pinSetId)))
          .go();
      await batch((b) => b.insertAll(teeToPinYards, yards));
    });
  }

  /// A tee set and a pin set only make a yardage set on the same course, and
  /// SQL can't say so across two parent tables — so this does, loudly.
  ///
  /// A set that doesn't exist is left for the foreign key to refuse, so the
  /// caller gets the same error it would without this check.
  Future<void> assertSameCourse(int teeSetId, int pinSetId) async {
    final tee = await (select(teeSets)..where((s) => s.id.equals(teeSetId)))
        .getSingleOrNull();
    final pin = await (select(pinSets)..where((s) => s.id.equals(pinSetId)))
        .getSingleOrNull();
    if (tee == null || pin == null) return;
    if (tee.courseId != pin.courseId) {
      throw ArgumentError(
        'tee set $teeSetId (course ${tee.courseId}) and pin set $pinSetId '
        '(course ${pin.courseId}) are on different courses',
      );
    }
  }
}
