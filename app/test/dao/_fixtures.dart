import 'package:drift/drift.dart';

import 'package:golfy_app/data/database.dart';

/// Shared in-memory test fixtures for the DAO suites.
///
/// Each helper accepts the database under test and returns the inserted
/// row id (or a fully-populated companion). Defaults are picked so the
/// resulting row is valid against every CHECK constraint and against the
/// DAO's app-layer invariants — tests override the specific fields they
/// want to probe.
class TestFixtures {
  TestFixtures(this.db);

  final GolfyDatabase db;

  Future<int> insertCourse({
    String name = 'Pebble Beach',
    String gameTitle = 'PGA Tour 2K25',
  }) {
    return db.courseDao.insert(
      CoursesCompanion.insert(name: name, gameTitle: gameTitle),
    );
  }

  Future<int> insertEvent({String name = 'Club Championship', int season = 1}) {
    return db.eventDao.insert(
      EventsCompanion.insert(name: name, season: Value(season)),
    );
  }

  /// Saves a course's shared per-hole card (par + optional stroke index).
  /// Defaults to a full 18-hole par-4 card; pass [count]/[par]/[strokeIndex].
  Future<void> insertCourseHoles(
    int courseId, {
    int count = 18,
    int par = 4,
    int? strokeIndex,
  }) {
    return db.courseHoleDao.replaceForCourse(courseId, [
      for (var h = 1; h <= count; h++)
        CourseHolesCompanion.insert(
          courseId: courseId,
          holeNumber: h,
          par: par,
          strokeIndex: Value(strokeIndex),
        ),
    ]);
  }

  /// Inserts a named yardage set for a course and returns its id.
  Future<int> insertCourseSet(int courseId, {String name = 'Blue tees'}) {
    return db.courseSetDao.insertSet(
      CourseSetsCompanion.insert(courseId: courseId, name: name),
    );
  }

  /// Saves a set's per-hole yardage. Defaults to a full 18-hole card of
  /// [yards]-yard holes; pass [count] for fewer.
  Future<void> insertCourseSetYards(
    int setId, {
    int count = 18,
    int yards = 400,
  }) {
    return db.courseSetDao.replaceYardsForSet(setId, [
      for (var h = 1; h <= count; h++)
        CourseSetYardsCompanion.insert(
          courseSetId: setId,
          holeNumber: h,
          yards: yards,
        ),
    ]);
  }

  Future<int> insertRound(
    int courseId, {
    String date = '2026-05-19',
    int roundNumber = 1,
    int? eventId,
    int? courseSetId,
  }) {
    return db.roundDao.insert(
      RoundsCompanion.insert(
        date: date,
        courseId: courseId,
        roundNumber: Value(roundNumber),
        eventId: Value(eventId),
        courseSetId: Value(courseSetId),
      ),
    );
  }

  /// Builds a hole_results companion with defaults that satisfy both the
  /// schema CHECK constraints and the DAO invariant validator.
  HoleResultsCompanion holeCompanion(
    int roundId,
    int holeNumber, {
    int par = 4,
    int score = 4,
    int yards = 400,
    bool? fairwayHit = true,
    bool gir = true,
    int putts = 2,
    bool upDownAttempt = false,
    bool upDownSuccess = false,
    int penaltyStrokes = 0,
    bool bunkerVisited = false,
    bool sandSave = false,
  }) {
    return HoleResultsCompanion.insert(
      roundId: roundId,
      holeNumber: holeNumber,
      par: par,
      score: score,
      yards: yards,
      fairwayHit: Value(fairwayHit),
      gir: gir,
      putts: putts,
      upDownAttempt: upDownAttempt,
      upDownSuccess: upDownSuccess,
      penaltyStrokes: penaltyStrokes,
      bunkerVisited: bunkerVisited,
      sandSave: sandSave,
    );
  }

  /// Seeds one dataset that exercises **every table and every awkward case**
  /// at once, for the backup suites (#69): two courses (one templated, one
  /// bare), two yardage sets on one of them, four events covering each result
  /// state and a second season of the same name, three rounds (one casual with
  /// no event and no set, one half-played, one complete and attached to an
  /// event), a par 3 with a null `fairwayHit`, holes with and without shots,
  /// shots with every optional field null, a round carrying the legacy
  /// `tee_set` and `migration_canary` columns, and notes holding quotes,
  /// newlines and non-ASCII text.
  ///
  /// Returns the expected row count per SQL table name, so a test can assert
  /// against the fixture instead of against hand-copied numbers.
  Future<Map<String, int>> seedFullBackupFixture() async {
    // ── Courses ────────────────────────────────────────────────────────────
    final pebble = await insertCourse();
    // A second course with no template at all: a backup has to carry a course
    // whose card was never entered.
    final bare = await insertCourse(
      name: 'Königsschloß — "the castle"',
      gameTitle: 'EA Sports PGA Tour',
    );

    // Par 3 on hole 7, par 5 on hole 18, par 4 elsewhere.
    await db.courseHoleDao.replaceForCourse(pebble, [
      for (var h = 1; h <= 18; h++)
        CourseHolesCompanion.insert(
          courseId: pebble,
          holeNumber: h,
          par: switch (h) { 7 => 3, 18 => 5, _ => 4 },
          strokeIndex: Value(h == 1 ? null : h),
        ),
    ]);

    final blue = await insertCourseSet(pebble);
    final gold = await insertCourseSet(pebble, name: 'Gold tees');
    await insertCourseSetYards(blue);
    await db.courseSetDao.replaceYardsForSet(gold, [
      for (var h = 1; h <= 18; h++)
        CourseSetYardsCompanion.insert(
          courseSetId: gold,
          holeNumber: h,
          yards: h == 7 ? 0 : 400 + h * 3,
        ),
    ]);

    // ── Events: one of each result state, plus a second season ─────────────
    final placed = await insertEvent();
    await db.eventDao.setResult(placed, finishPosition: 3, tied: true);
    final cut = await insertEvent(name: 'Open Qualifier');
    await db.eventDao.setResult(cut, missedCut: true);
    final unrecorded = await insertEvent(name: 'Friday Night League');
    await insertEvent(season: 2); // same name, next season

    // ── Rounds ─────────────────────────────────────────────────────────────
    // Casual: no event, no yardage set, nothing optional set.
    final casual = await insertRound(bare, date: '2026-05-01');
    // Half-played, on a set, attached to an event, carrying the legacy
    // free-text tee set and the v2 migration canary.
    final partial = await db.roundDao.insert(
      RoundsCompanion.insert(
        date: '2026-05-19',
        courseId: pebble,
        roundNumber: const Value(1),
        courseSetId: Value(blue),
        eventId: Value(placed),
        teeSet: const Value('Blue (legacy label)'),
        migrationCanary: const Value('v2 canary'),
        weather: const Value('Breezy'),
        windSpeedMph: const Value(12),
        difficulty: const Value('Pro'),
        notes: const Value('Said "nice shot" — then this:\nthree-putt. ⛳'),
      ),
    );
    // Complete, same day as `partial` so the (date, course, number) unique key
    // is exercised by a second round number.
    final complete = await db.roundDao.insert(
      RoundsCompanion.insert(
        date: '2026-05-19',
        courseId: pebble,
        roundNumber: const Value(2),
        courseSetId: Value(gold),
        eventId: Value(unrecorded),
      ),
    );

    // ── Holes and shots ────────────────────────────────────────────────────
    // The casual round has one hole and no shots at all.
    await upsertHole(casual, 1, par: 4, score: 5, putts: 2);

    // Seven of eighteen holes, hole 7 a par 3 (no fairway), one hole bunkered
    // and sand-saved, one with penalty strokes.
    for (var h = 1; h <= 7; h++) {
      final isPar3 = h == 7;
      await db.holeResultDao.upsert(holeCompanion(
        partial,
        h,
        par: isPar3 ? 3 : 4,
        score: isPar3 ? 2 : 5,
        yards: isPar3 ? 165 : 400 + h,
        fairwayHit: isPar3 ? null : h.isEven,
        gir: isPar3,
        putts: isPar3 ? 1 : 2,
        upDownAttempt: isPar3,
        upDownSuccess: isPar3,
        penaltyStrokes: h == 3 ? 1 : 0,
        bunkerVisited: h == 4,
        sandSave: h == 4,
      ));
    }

    // Shots on two holes only, with every optional field exercised.
    final partialHole1 = await db.holeResultDao.upsert(holeCompanion(
      partial,
      1,
      score: 5,
      putts: 2,
      fairwayHit: false,
    ));
    await db.holeShotDao.replaceForHole(partialHole1, [
      HoleShotsCompanion.insert(
        holeResultId: partialHole1,
        shotNumber: 1,
        club: const Value('Driver'),
        distanceYards: const Value(401),
        lie: const Value('Tee'),
      ),
      HoleShotsCompanion.insert(
        holeResultId: partialHole1,
        shotNumber: 2,
        club: const Value('7 iron'),
        distanceYards: const Value(160),
        lie: const Value('Light Rough'),
        result: const Value('Penalty'),
      ),
      // Everything optional left null — a shot the user started and never
      // filled in still has to survive a backup.
      HoleShotsCompanion.insert(holeResultId: partialHole1, shotNumber: 3),
    ]);

    for (var h = 1; h <= 18; h++) {
      final isPar3 = h == 7;
      final isPar5 = h == 18;
      await db.holeResultDao.upsert(holeCompanion(
        complete,
        h,
        par: isPar3
            ? 3
            : isPar5
                ? 5
                : 4,
        score: isPar3 ? 3 : 4,
        yards: isPar3 ? 0 : 400 + h * 3,
        fairwayHit: isPar3 ? null : true,
        gir: true,
        putts: 2,
      ));
    }
    final completeHole18 = await db.holeResultDao.upsert(holeCompanion(
      complete,
      18,
      par: 5,
      score: 4,
      yards: 454,
      gir: true,
      putts: 1,
    ));
    await db.holeShotDao.replaceForHole(completeHole18, [
      HoleShotsCompanion.insert(
        holeResultId: completeHole18,
        shotNumber: 1,
        club: const Value('Driver'),
        distanceYards: const Value(454),
        lie: const Value('Tee'),
      ),
      HoleShotsCompanion.insert(
        holeResultId: completeHole18,
        shotNumber: 2,
        club: const Value('3 wood'),
        distanceYards: const Value(210),
        lie: const Value('Fairway'),
        result: const Value('Holed'),
      ),
    ]);

    return const <String, int>{
      'courses': 2,
      'course_holes': 18,
      'course_sets': 2,
      'course_set_yards': 36,
      'events': 4,
      'rounds': 3,
      'hole_results': 26, // 1 casual + 7 partial + 18 complete
      'hole_shots': 5,
    };
  }

  Future<int> upsertHole(
    int roundId,
    int holeNumber, {
    int par = 4,
    int score = 4,
    int putts = 2,
    bool? fairwayHit = true,
    bool gir = true,
    bool upDownAttempt = false,
    bool upDownSuccess = false,
    int penaltyStrokes = 0,
    bool bunkerVisited = false,
    bool sandSave = false,
  }) {
    return db.holeResultDao.upsert(holeCompanion(
      roundId,
      holeNumber,
      par: par,
      score: score,
      putts: putts,
      fairwayHit: fairwayHit,
      gir: gir,
      upDownAttempt: upDownAttempt,
      upDownSuccess: upDownSuccess,
      penaltyStrokes: penaltyStrokes,
      bunkerVisited: bunkerVisited,
      sandSave: sandSave,
    ));
  }
}
