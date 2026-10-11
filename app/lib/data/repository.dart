import 'package:drift/drift.dart' show Value;

import 'backup/backup_payload.dart';
import 'database.dart';
import 'models/dashboard_stats.dart';
import 'models/event_stats.dart';
import 'models/hole_shot_input.dart';
import 'models/round_with_course.dart';

/// Single facade over the four drift DAOs.
///
/// UI / Riverpod code depends on this class, not on individual DAOs or on
/// the [GolfyDatabase] directly — that keeps SQL-shaped concerns inside the
/// `data/` layer and gives a future cross-DAO operation (e.g. "create a
/// round and seed 18 placeholder holes in one transaction") a natural home.
class GolfyRepository {
  GolfyRepository(this._db);

  final GolfyDatabase _db;

  // ── Courses ────────────────────────────────────────────────────────────

  Future<int> insertCourse(CoursesCompanion course) =>
      _db.courseDao.insert(course);

  /// Updates a course's identity (name / game title). A duplicate
  /// `(name, gameTitle)` throws (schema-level UNIQUE); the caller pre-checks and
  /// also catches this as a safety net. See [CourseDao.updateById].
  Future<int> updateCourse(int id, CoursesCompanion course) =>
      _db.courseDao.updateById(id, course);

  /// Deletes a course. Throws if any round still references it (FK RESTRICT);
  /// its `course_holes` template cascades away. See [CourseDao.deleteById].
  Future<int> deleteCourse(int id) => _db.courseDao.deleteById(id);

  Stream<List<Course>> watchCourses() => _db.courseDao.watchAll();

  Stream<List<Course>> watchCoursesByName() => _db.courseDao.watchAllByName();

  // ── Course holes (shared par / stroke index) ─────────────────────────────

  /// Reactive shared per-hole card for a course (par + stroke index, #36),
  /// ordered by hole number.
  Stream<List<CourseHole>> watchCourseHoles(int courseId) =>
      _db.courseHoleDao.watchForCourse(courseId);

  /// One-shot read of a course's shared per-hole card, used to seed Hole Entry.
  Future<List<CourseHole>> getCourseHoles(int courseId) =>
      _db.courseHoleDao.getForCourse(courseId);

  /// Replaces a course's entire shared per-hole card in one transaction. See
  /// [CourseHoleDao.replaceForCourse].
  Future<void> replaceCourseHoles(
    int courseId,
    List<CourseHolesCompanion> holes,
  ) =>
      _db.courseHoleDao.replaceForCourse(courseId, holes);

  // ── Tee sets, pin sets and their yards ───────────────────────────────────
  //
  // A hole's course yards vary with the tee set alone; its tee-to-pin yards
  // with the tee set and pin set together. A round's yardage set is a (tee
  // set, pin set) pair. See [YardageDao].

  /// Reactive list of a course's tee sets, ordered by name.
  Stream<List<TeeSet>> watchTeeSets(int courseId) =>
      _db.yardageDao.watchTeeSetsForCourse(courseId);

  /// Inserts a tee set and returns its id. A duplicate `(courseId, name)`
  /// throws (schema-level UNIQUE).
  Future<int> insertTeeSet(TeeSetsCompanion set) =>
      _db.yardageDao.insertTeeSet(set);

  /// Renames a tee set. A duplicate `(courseId, name)` throws.
  Future<int> renameTeeSet(int id, String name) =>
      _db.yardageDao.renameTeeSet(id, name);

  /// Deletes a tee set; its course yards and tee-to-pin yards cascade and
  /// rounds played from it detach (`rounds.tee_set_id` SET NULL).
  Future<int> deleteTeeSet(int id) => _db.yardageDao.deleteTeeSet(id);

  /// Reactive list of a course's pin sets, ordered by name.
  Stream<List<PinSet>> watchPinSets(int courseId) =>
      _db.yardageDao.watchPinSetsForCourse(courseId);

  /// Inserts a pin set and returns its id. A duplicate `(courseId, name)`
  /// throws (schema-level UNIQUE).
  Future<int> insertPinSet(PinSetsCompanion set) =>
      _db.yardageDao.insertPinSet(set);

  /// Renames a pin set. A duplicate `(courseId, name)` throws.
  Future<int> renamePinSet(int id, String name) =>
      _db.yardageDao.renamePinSet(id, name);

  /// Deletes a pin set; its tee-to-pin yards cascade and rounds played to it
  /// detach (`rounds.pin_set_id` SET NULL).
  Future<int> deletePinSet(int id) => _db.yardageDao.deletePinSet(id);

  /// Reactive course yards for a tee set, ordered by hole number.
  Stream<List<CourseYard>> watchCourseYards(int teeSetId) =>
      _db.yardageDao.watchCourseYards(teeSetId);

  /// One-shot read of a tee set's course yards.
  Future<List<CourseYard>> getCourseYards(int teeSetId) =>
      _db.yardageDao.getCourseYards(teeSetId);

  /// Replaces a tee set's whole course-yards card in one transaction.
  Future<void> replaceCourseYards(
    int teeSetId,
    List<CourseYardsCompanion> yards,
  ) =>
      _db.yardageDao.replaceCourseYards(teeSetId, yards);

  /// Upserts one hole's course yards, without touching the other 17.
  Future<int> upsertCourseYard(CourseYardsCompanion yard) =>
      _db.yardageDao.upsertCourseYard(yard);

  /// Reactive tee-to-pin yards for a (tee set, pin set) yardage set, ordered
  /// by hole number.
  Stream<List<TeeToPinYard>> watchTeeToPinYards(int teeSetId, int pinSetId) =>
      _db.yardageDao.watchTeeToPinYards(teeSetId, pinSetId);

  /// One-shot read of a yardage set's tee-to-pin yards.
  Future<List<TeeToPinYard>> getTeeToPinYards(int teeSetId, int pinSetId) =>
      _db.yardageDao.getTeeToPinYards(teeSetId, pinSetId);

  /// Upserts one hole's tee-to-pin yards, without touching the other 17.
  /// Throws [ArgumentError] when the two sets are on different courses.
  Future<int> upsertTeeToPinYard(TeeToPinYardsCompanion yard) =>
      _db.yardageDao.upsertTeeToPinYard(yard);

  /// Saves a course's whole card in **one** transaction (#81): the per-hole
  /// par / stroke-index rows, the course yards of each tee set in
  /// [courseYardsByTeeSet], and the tee-to-pin yards of each yardage set in
  /// [teeToPinByYardageSet], keyed `(teeSetId, pinSetId)`.
  ///
  /// The course editor writes them together, as separate replaces. Run
  /// individually, a failure on a later one would leave the course half-saved
  /// while the editor's "everything is saved now" state said otherwise —
  /// precisely the lie its per-hole Saved/Unsaved chips exist to prevent. One
  /// transaction makes the save all-or-nothing.
  ///
  /// Only pass cards that have actually been loaded: each entry is a wholesale
  /// replace, so handing it a blank card would wipe that tee set's or yardage
  /// set's yards.
  Future<void> replaceCourseCard(
    int courseId,
    List<CourseHolesCompanion> holes, {
    Map<int, List<CourseYardsCompanion>> courseYardsByTeeSet = const {},
    Map<(int, int), List<TeeToPinYardsCompanion>> teeToPinByYardageSet =
        const {},
  }) {
    return _db.transaction(() async {
      await _db.courseHoleDao.replaceForCourse(courseId, holes);
      for (final entry in courseYardsByTeeSet.entries) {
        await _db.yardageDao.replaceCourseYards(entry.key, entry.value);
      }
      for (final entry in teeToPinByYardageSet.entries) {
        final (teeSetId, pinSetId) = entry.key;
        await _db.yardageDao
            .replaceTeeToPinYards(teeSetId, pinSetId, entry.value);
      }
    });
  }

  /// Upserts one hole's par / stroke index without touching the other 17 — for
  /// correcting the course template mid-round (#81). See
  /// [CourseHoleDao.upsertHole].
  Future<int> upsertCourseHole(CourseHolesCompanion hole) =>
      _db.courseHoleDao.upsertHole(hole);

  // ── Rounds ─────────────────────────────────────────────────────────────

  Future<int> insertRound(RoundsCompanion round) =>
      _db.roundDao.insert(round);

  Stream<List<RoundWithCourse>> watchRounds() =>
      _db.roundDao.watchAllWithCourse();

  /// Reactive list of the rounds belonging to a single event (#55), in the same
  /// shape and order as [watchRounds]. See [RoundDao.watchRoundsForEvent].
  Stream<List<RoundWithCourse>> watchRoundsForEvent(int eventId) =>
      _db.roundDao.watchRoundsForEvent(eventId);

  Future<Round?> getRound(int id) => _db.roundDao.getById(id);

  /// Updates a round in place (#45). The companion carries only the columns to
  /// change; a present `Value(null)` clears a nullable column (e.g. detaching
  /// the event). See [RoundDao.updateById].
  Future<int> updateRound(int id, RoundsCompanion round) =>
      _db.roundDao.updateById(id, round);

  Future<int> deleteRound(int id) => _db.roundDao.deleteById(id);

  // ── Events ─────────────────────────────────────────────────────────────

  Future<int> insertEvent(EventsCompanion event) =>
      _db.eventDao.insert(event);

  Stream<List<Event>> watchEvents() => _db.eventDao.watchAll();

  Future<Event?> getEvent(int id) => _db.eventDao.getById(id);

  /// Records an event's result. Pass all three components so the stored row is
  /// fully specified; the DAO enforces the position / tied / cut invariant.
  Future<int> setEventResult(
    int id, {
    int? finishPosition,
    bool tied = false,
    bool missedCut = false,
  }) =>
      _db.eventDao.setResult(
        id,
        finishPosition: finishPosition,
        tied: tied,
        missedCut: missedCut,
      );

  /// Updates an event's identity (name + season). A duplicate `(name, season)`
  /// throws (schema-level UNIQUE); the caller pre-checks and also catches this
  /// as a safety net.
  Future<int> updateEventDetails(
    int id, {
    required String name,
    required int season,
  }) =>
      _db.eventDao.updateDetails(id, name: name, season: season);

  Future<int> deleteEvent(int id) => _db.eventDao.deleteById(id);

  // ── Hole results ───────────────────────────────────────────────────────

  Future<int> upsertHoleResult(HoleResultsCompanion hole) =>
      _db.holeResultDao.upsert(hole);

  /// Saves a hole and its ordered shot list (#22) in one transaction: upserts
  /// the `hole_results` row, reads back its id, then replaces its `hole_shots`.
  /// [shots] are ordered — `shotNumber` is assigned from position (1-based).
  /// Returns the hole_results row id.
  Future<int> saveHole(
    HoleResultsCompanion hole,
    List<HoleShotInput> shots,
  ) {
    return _db.transaction(() async {
      final id = await _db.holeResultDao.upsert(hole);
      await _db.holeShotDao.replaceForHole(id, [
        for (var i = 0; i < shots.length; i++)
          HoleShotsCompanion.insert(
            holeResultId: id,
            shotNumber: i + 1,
            club: Value(shots[i].club),
            distanceYards: Value(shots[i].distanceYards),
            lie: Value(shots[i].lie),
            result: Value(shots[i].result),
            distanceFeet: Value(shots[i].distanceFeet),
          ),
      ]);
      return id;
    });
  }

  Stream<List<HoleResult>> watchHoleResults(int roundId) =>
      _db.holeResultDao.watchForRound(roundId);

  /// Reactive shots for every hole of a round, keyed by hole number (#22).
  Stream<Map<int, List<HoleShot>>> watchHoleShots(int roundId) =>
      _db.holeShotDao.watchForRound(roundId);

  Future<int> holeCount(int roundId) => _db.holeResultDao.countForRound(roundId);

  // ── Dashboard ──────────────────────────────────────────────────────────

  Stream<DashboardStats> watchDashboardStats() => _db.dashboardDao.watchStats();

  /// Reactive scoring stats for a single event (#56). See
  /// [DashboardDao.watchEventStats].
  Stream<EventStats> watchEventStats(int eventId) =>
      _db.dashboardDao.watchEventStats(eventId);

  // ── Backup ─────────────────────────────────────────────────────────────

  /// Reads every table into a [BackupPayload] for export (#69), in one
  /// transaction so the result is a consistent snapshot. See
  /// [BackupDao.readAll].
  Future<BackupPayload> readBackupPayload() => _db.backupDao.readAll();
}
