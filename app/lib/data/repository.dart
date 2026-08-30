import 'database.dart';
import 'models/dashboard_stats.dart';
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

  Stream<List<Course>> watchCourses() => _db.courseDao.watchAll();

  Stream<List<Course>> watchCoursesByName() => _db.courseDao.watchAllByName();

  // ── Rounds ─────────────────────────────────────────────────────────────

  Future<int> insertRound(RoundsCompanion round) =>
      _db.roundDao.insert(round);

  Stream<List<RoundWithCourse>> watchRounds() =>
      _db.roundDao.watchAllWithCourse();

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

  /// Renames an event. A duplicate name throws (schema-level UNIQUE); the
  /// caller pre-checks and also catches this as a safety net.
  Future<int> renameEvent(int id, String name) =>
      _db.eventDao.rename(id, name);

  Future<int> deleteEvent(int id) => _db.eventDao.deleteById(id);

  // ── Hole results ───────────────────────────────────────────────────────

  Future<int> upsertHoleResult(HoleResultsCompanion hole) =>
      _db.holeResultDao.upsert(hole);

  Stream<List<HoleResult>> watchHoleResults(int roundId) =>
      _db.holeResultDao.watchForRound(roundId);

  Future<int> holeCount(int roundId) => _db.holeResultDao.countForRound(roundId);

  // ── Dashboard ──────────────────────────────────────────────────────────

  Stream<DashboardStats> watchDashboardStats() => _db.dashboardDao.watchStats();
}
