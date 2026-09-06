import 'database.dart';
import 'models/dashboard_stats.dart';
import 'models/event_stats.dart';
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

  // ── Course yardage sets (#36) ─────────────────────────────────────────────

  /// Reactive list of a course's named yardage sets, ordered by name.
  Stream<List<CourseSet>> watchCourseSets(int courseId) =>
      _db.courseSetDao.watchSetsForCourse(courseId);

  /// Inserts a yardage set and returns its id. A duplicate `(courseId, name)`
  /// throws (schema-level UNIQUE).
  Future<int> insertCourseSet(CourseSetsCompanion set) =>
      _db.courseSetDao.insertSet(set);

  /// Renames a yardage set. A duplicate `(courseId, name)` throws.
  Future<int> renameCourseSet(int id, String name) =>
      _db.courseSetDao.renameSet(id, name);

  /// Deletes a yardage set; its yardages cascade and rounds on it detach
  /// (`rounds.course_set_id` SET NULL).
  Future<int> deleteCourseSet(int id) => _db.courseSetDao.deleteSet(id);

  /// Reactive per-hole yardage for a set, ordered by hole number.
  Stream<List<CourseSetYard>> watchCourseSetYards(int setId) =>
      _db.courseSetDao.watchYardsForSet(setId);

  /// One-shot read of a set's per-hole yardage, used to seed Hole Entry.
  Future<List<CourseSetYard>> getCourseSetYards(int setId) =>
      _db.courseSetDao.getYardsForSet(setId);

  /// Replaces a set's entire yardage card in one transaction. See
  /// [CourseSetDao.replaceYardsForSet].
  Future<void> replaceCourseSetYards(
    int setId,
    List<CourseSetYardsCompanion> yards,
  ) =>
      _db.courseSetDao.replaceYardsForSet(setId, yards);

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

  Stream<List<HoleResult>> watchHoleResults(int roundId) =>
      _db.holeResultDao.watchForRound(roundId);

  Future<int> holeCount(int roundId) => _db.holeResultDao.countForRound(roundId);

  // ── Dashboard ──────────────────────────────────────────────────────────

  Stream<DashboardStats> watchDashboardStats() => _db.dashboardDao.watchStats();

  /// Reactive scoring stats for a single event (#56). See
  /// [DashboardDao.watchEventStats].
  Stream<EventStats> watchEventStats(int eventId) =>
      _db.dashboardDao.watchEventStats(eventId);
}
