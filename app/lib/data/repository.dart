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

  // ── Rounds ─────────────────────────────────────────────────────────────

  Future<int> insertRound(RoundsCompanion round) =>
      _db.roundDao.insert(round);

  Stream<List<RoundWithCourse>> watchRounds() =>
      _db.roundDao.watchAllWithCourse();

  Future<Round?> getRound(int id) => _db.roundDao.getById(id);

  Future<int> deleteRound(int id) => _db.roundDao.deleteById(id);

  // ── Hole results ───────────────────────────────────────────────────────

  Future<int> upsertHoleResult(HoleResultsCompanion hole) =>
      _db.holeResultDao.upsert(hole);

  Stream<List<HoleResult>> watchHoleResults(int roundId) =>
      _db.holeResultDao.watchForRound(roundId);

  Future<int> holeCount(int roundId) => _db.holeResultDao.countForRound(roundId);

  // ── Dashboard ──────────────────────────────────────────────────────────

  Stream<DashboardStats> watchDashboardStats() => _db.dashboardDao.watchStats();
}
