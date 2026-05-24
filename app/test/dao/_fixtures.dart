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

  Future<int> insertRound(
    int courseId, {
    String date = '2026-05-19',
    int roundNumber = 1,
    String? teeSet,
  }) {
    return db.roundDao.insert(
      RoundsCompanion.insert(
        date: date,
        courseId: courseId,
        roundNumber: Value(roundNumber),
        teeSet: Value(teeSet),
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
    int driveDistanceYards = 250,
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
      driveDistanceYards: driveDistanceYards,
    );
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
