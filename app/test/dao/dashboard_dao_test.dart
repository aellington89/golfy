import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/database.dart';
import 'package:golfy_app/data/models/dashboard_stats.dart';

import '_fixtures.dart';

/// The "rich fixture" used by the bulk of the dashboard tests. Numbers are
/// hand-chosen so every aggregate has a verifiable expected value.
///
/// **Round 1** — Pebble Beach, 2026-05-01, all par-4 (18 holes)
/// * Scores: 4 birdies (3), 10 pars (4), 4 bogeys (5) → SUM=72, to-par=0
/// * Fairway hits: holes 1–12 = true, 13–18 = false → 12/18 hits
/// * GIR: holes 1–10 = true, 11–18 = false → 10/18
/// * Putts: 2 each → SUM=36
/// * Up/down: hole 17 attempt=true,success=false; hole 18 attempt=true,
///   success=true. Others all attempt=false. → 2 attempts, 1 success.
/// * Penalty: hole 13 has penaltyStrokes=2; rest 0. → 1 hole with penalty,
///   total penalty strokes=2.
/// * Bunker/sand save: holes 14,15,16 bunkerVisited=true; hole 14
///   sandSave=true.
///
/// **Round 2** — Augusta National, 2026-05-15, mixed pars (18 holes)
/// * Par-3 on holes 4,8,13,17 (4 holes). Par-5 on holes 5,9,14,18. Rest
///   par-4 (10 holes). Total par = 72.
/// * Scores: holes 5,9 are par-5 birdies (score=4); holes 14,18 are par-5
///   pars (score=5); par-4 holes all par (score=4); par-3 holes all par
///   (score=3). SUM(score) = 8+10+40+12 = 70 → to-par = -2.
/// * Fairway hits: par-3 holes have fairwayHit=null. Par-4/5 holes: 1,2,3,
///   5,6,7,9,10 = true (8 hits); 11,12,14,15,16,18 = false → 8/14 hits.
/// * GIR: holes 1–15 = true, 16–18 = false → 15/18.
/// * Putts: 2 each → SUM=36.
/// * Up/down + penalty + bunker: all zero.
///
/// **Combined totals (36 holes, 2 rounds)**
/// * rounds_played = 2
/// * SUM(score) = 142 → avg per round = 71.0
/// * SUM(score-par) = -2 → avg vs par = -1.0
/// * fairwayHitPct = 20 / 32 = 0.625
/// * girPct = 25 / 36 ≈ 0.69444…
/// * avgPuttsPerHole = 2.0
/// * upDownPct = 1 / 2 = 0.5
/// * penaltyHolePct = 1 / 36 ≈ 0.02778…
/// * avgPenaltyStrokesPerHole = 2 / 36 ≈ 0.05556…
/// * scoreDistribution = {-1: 6, 0: 26, +1: 4}
/// * bestRound = Round 2 (to_par = -2)
Future<({int r1, int r2})> seedRichFixture(TestFixtures fx) async {
  final c1 = await fx.insertCourse(
    name: 'Pebble Beach',
    gameTitle: 'PGA Tour 2K25',
  );
  final c2 = await fx.insertCourse(
    name: 'Augusta National',
    gameTitle: 'PGA Tour 2K25',
  );

  // ── Round 1: all par-4 ──────────────────────────────────────────────────
  final r1 = await fx.insertRound(c1, date: '2026-05-01');
  for (var h = 1; h <= 18; h++) {
    final score = h <= 4
        ? 3 // birdies (holes 1-4)
        : h <= 14
            ? 4 // pars (holes 5-14)
            : 5; // bogeys (holes 15-18)
    final fairwayHit = h <= 12;
    final gir = h <= 10;
    final upDownAttempt = h == 17 || h == 18;
    final upDownSuccess = h == 18;
    final penaltyStrokes = h == 13 ? 2 : 0;
    final bunkerVisited = h == 14 || h == 15 || h == 16;
    final sandSave = h == 14;
    await fx.upsertHole(
      r1,
      h,
      par: 4,
      score: score,
      fairwayHit: fairwayHit,
      gir: gir,
      putts: 2,
      upDownAttempt: upDownAttempt,
      upDownSuccess: upDownSuccess,
      penaltyStrokes: penaltyStrokes,
      bunkerVisited: bunkerVisited,
      sandSave: sandSave,
    );
  }

  // ── Round 2: mixed pars ────────────────────────────────────────────────
  final r2 = await fx.insertRound(c2, date: '2026-05-15');
  bool isPar3(int h) => h == 4 || h == 8 || h == 13 || h == 17;
  bool isPar5(int h) => h == 5 || h == 9 || h == 14 || h == 18;
  for (var h = 1; h <= 18; h++) {
    final par = isPar3(h)
        ? 3
        : isPar5(h)
            ? 5
            : 4;
    // Par-5 birdies on holes 5 and 9; everything else par.
    final score = (h == 5 || h == 9) ? 4 : par;
    final fairwayHit = isPar3(h)
        ? null
        : (h == 1 ||
            h == 2 ||
            h == 3 ||
            h == 5 ||
            h == 6 ||
            h == 7 ||
            h == 9 ||
            h == 10);
    final gir = h <= 15;
    await fx.upsertHole(
      r2,
      h,
      par: par,
      score: score,
      fairwayHit: fairwayHit,
      gir: gir,
      putts: 2,
    );
  }

  return (r1: r1, r2: r2);
}

void main() {
  late GolfyDatabase db;
  late TestFixtures fx;

  setUp(() {
    db = GolfyDatabase.forTesting(NativeDatabase.memory());
    fx = TestFixtures(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('DashboardDao.watchStats — empty database', () {
    test('roundsPlayed=0 and every other field is null', () async {
      final stats = await db.dashboardDao.watchStats().first;

      expect(stats.roundsPlayed, 0);
      expect(stats.avgScorePerRound, isNull);
      expect(stats.avgScoreVsPar, isNull);
      expect(stats.fairwayHitPct, isNull);
      expect(stats.girPct, isNull);
      expect(stats.avgPuttsPerHole, isNull);
      expect(stats.upDownPct, isNull);
      expect(stats.penaltyHolePct, isNull);
      expect(stats.avgPenaltyStrokesPerHole, isNull);
      expect(stats.scoreDistribution, isEmpty);
      expect(stats.bestRound, isNull);
    });
  });

  group('DashboardDao.watchStats — rich fixture', () {
    test('matches every hand-computed aggregate', () async {
      final ids = await seedRichFixture(fx);

      final stats = await db.dashboardDao.watchStats().first;

      expect(stats.roundsPlayed, 2);
      expect(stats.avgScorePerRound, closeTo(71.0, 1e-9));
      expect(stats.avgScoreVsPar, closeTo(-1.0, 1e-9));
      expect(stats.fairwayHitPct, closeTo(20 / 32, 1e-9));
      expect(stats.girPct, closeTo(25 / 36, 1e-9));
      expect(stats.avgPuttsPerHole, closeTo(2.0, 1e-9));
      expect(stats.upDownPct, closeTo(0.5, 1e-9));
      expect(stats.penaltyHolePct, closeTo(1 / 36, 1e-9));
      expect(stats.avgPenaltyStrokesPerHole, closeTo(2 / 36, 1e-9));

      expect(stats.scoreDistribution, [
        const ScoreBucket(scoreVsPar: -1, count: 6),
        const ScoreBucket(scoreVsPar: 0, count: 26),
        const ScoreBucket(scoreVsPar: 1, count: 4),
      ]);

      expect(stats.bestRound, isNotNull);
      expect(stats.bestRound!.roundId, ids.r2);
      expect(stats.bestRound!.courseName, 'Augusta National');
      expect(stats.bestRound!.date, '2026-05-15');
      expect(stats.bestRound!.toPar, -2);
    });
  });

  group('DashboardDao.watchStats — edge cases', () {
    test('upDownPct is null when no attempts have been recorded', () async {
      final cid = await fx.insertCourse();
      final rid = await fx.insertRound(cid);
      // 3 holes with no up/down attempts at all.
      for (var h = 1; h <= 3; h++) {
        await fx.upsertHole(rid, h);
      }
      final stats = await db.dashboardDao.watchStats().first;
      expect(stats.upDownPct, isNull);
      // Sanity: other aggregates that don't depend on attempts are present.
      expect(stats.roundsPlayed, 1);
      expect(stats.girPct, isNotNull);
    });

    test(
        'fairwayHitPct excludes par-3 (null fairwayHit) rows from both '
        'numerator and denominator', () async {
      final cid = await fx.insertCourse();
      final rid = await fx.insertRound(cid);
      // Mix: 2 par-3s (null fairwayHit), 1 par-4 hit, 1 par-4 miss → 1/2.
      await fx.upsertHole(rid, 1, par: 3, score: 3, fairwayHit: null);
      await fx.upsertHole(rid, 2, par: 3, score: 3, fairwayHit: null);
      await fx.upsertHole(rid, 3, par: 4, score: 4, fairwayHit: true);
      await fx.upsertHole(rid, 4, par: 4, score: 4, fairwayHit: false);

      final stats = await db.dashboardDao.watchStats().first;
      expect(stats.fairwayHitPct, closeTo(0.5, 1e-9));
    });

    test('bestRound is null when no hole_results exist (even with rounds)',
        () async {
      final cid = await fx.insertCourse();
      await fx.insertRound(cid);
      // Round exists but no holes entered.
      final stats = await db.dashboardDao.watchStats().first;
      expect(stats.bestRound, isNull);
      expect(stats.roundsPlayed, 0);
    });
  });

  group('DashboardDao.watchStats — GIR%', () {
    test('girPct is 1.0 when every hole is a GIR', () async {
      final cid = await fx.insertCourse();
      final rid = await fx.insertRound(cid);
      for (var h = 1; h <= 4; h++) {
        await fx.upsertHole(rid, h, gir: true);
      }
      final stats = await db.dashboardDao.watchStats().first;
      expect(stats.girPct, closeTo(1.0, 1e-9));
    });

    test('girPct is 0.0 (not null) when no hole is a GIR', () async {
      final cid = await fx.insertCourse();
      final rid = await fx.insertRound(cid);
      for (var h = 1; h <= 4; h++) {
        await fx.upsertHole(rid, h, gir: false);
      }
      final stats = await db.dashboardDao.watchStats().first;
      // Denominator is COUNT(*), so with holes present this is a real 0.0 —
      // never a divide-by-zero null.
      expect(stats.girPct, closeTo(0.0, 1e-9));
    });
  });

  group('DashboardDao.watchStats — score vs. par', () {
    // The under-par case (avgScoreVsPar = -1.0) is covered by the rich fixture.
    test('avgScoreVsPar is 0.0 for an exactly even-par round', () async {
      final cid = await fx.insertCourse();
      final rid = await fx.insertRound(cid);
      // 9 holes, score == par everywhere → SUM(score - par) = 0 over 1 round.
      for (var h = 1; h <= 9; h++) {
        await fx.upsertHole(rid, h, par: 4, score: 4);
      }
      final stats = await db.dashboardDao.watchStats().first;
      expect(stats.avgScoreVsPar, closeTo(0.0, 1e-9));
      expect(stats.avgScorePerRound, closeTo(36.0, 1e-9));
    });

    test('avgScoreVsPar is positive for an over-par round', () async {
      final cid = await fx.insertCourse();
      final rid = await fx.insertRound(cid);
      // 9 holes, one over par each → SUM(score - par) = 9 over 1 round.
      for (var h = 1; h <= 9; h++) {
        await fx.upsertHole(rid, h, par: 4, score: 5);
      }
      final stats = await db.dashboardDao.watchStats().first;
      expect(stats.avgScoreVsPar, closeTo(9.0, 1e-9));
    });
  });

  group('DashboardDao.watchStats — division by zero', () {
    test('fairwayHitPct is null when every hole is a par-3', () async {
      final cid = await fx.insertCourse();
      final rid = await fx.insertRound(cid);
      // Par-3s carry a null fairwayHit, so the fairway denominator
      // (SUM(fairway_hit IS NOT NULL)) is 0 → NULLIF → null. A distinct NULLIF
      // path from the up/down zero-attempts case above.
      for (var h = 1; h <= 3; h++) {
        await fx.upsertHole(rid, h, par: 3, score: 3, fairwayHit: null);
      }
      final stats = await db.dashboardDao.watchStats().first;
      expect(stats.fairwayHitPct, isNull);
      // Sanity: holes exist, so COUNT(*)-denominated stats are present.
      expect(stats.girPct, isNotNull);
    });
  });

  group('DashboardDao.watchStats — score distribution', () {
    test('surfaces eagle (≤ -2) through triple-bogey (+3) buckets, ordered',
        () async {
      final cid = await fx.insertCourse();
      final rid = await fx.insertRound(cid);
      // One hole per (score - par) bucket from -2 to +3, all par-4.
      await fx.upsertHole(rid, 1, par: 4, score: 2); // -2 eagle
      await fx.upsertHole(rid, 2, par: 4, score: 3); // -1 birdie
      await fx.upsertHole(rid, 3, par: 4, score: 4); //  0 par
      await fx.upsertHole(rid, 4, par: 4, score: 5); // +1 bogey
      await fx.upsertHole(rid, 5, par: 4, score: 6); // +2 double
      await fx.upsertHole(rid, 6, par: 4, score: 7); // +3 triple

      final stats = await db.dashboardDao.watchStats().first;
      expect(stats.scoreDistribution, [
        const ScoreBucket(scoreVsPar: -2, count: 1),
        const ScoreBucket(scoreVsPar: -1, count: 1),
        const ScoreBucket(scoreVsPar: 0, count: 1),
        const ScoreBucket(scoreVsPar: 1, count: 1),
        const ScoreBucket(scoreVsPar: 2, count: 1),
        const ScoreBucket(scoreVsPar: 3, count: 1),
      ]);
    });
  });

  group('DashboardDao.watchStats — best round', () {
    test('breaks a to-par tie by most recent date and returns exactly one',
        () async {
      final cid = await fx.insertCourse();
      // Two rounds tied at even par on different dates, plus a more recent but
      // worse round. Best-round SQL is `ORDER BY to_par ASC, date DESC LIMIT 1`.
      final earlyTie = await fx.insertRound(cid, date: '2026-05-01');
      final laterTie = await fx.insertRound(cid, date: '2026-05-20');
      final worseRecent = await fx.insertRound(cid, date: '2026-05-25');
      for (var h = 1; h <= 3; h++) {
        await fx.upsertHole(earlyTie, h, par: 4, score: 4); // to_par 0
        await fx.upsertHole(laterTie, h, par: 4, score: 4); // to_par 0
        await fx.upsertHole(worseRecent, h, par: 4, score: 5); // to_par +3
      }

      final stats = await db.dashboardDao.watchStats().first;
      expect(stats.bestRound, isNotNull);
      // Lowest to_par wins (0 beats +3, so the most-recent round loses); the
      // 0-tie is then broken by the later date → laterTie.
      expect(stats.bestRound!.roundId, laterTie);
      expect(stats.bestRound!.toPar, 0);
    });
  });

  group('DashboardDao.watchStats — reactivity', () {
    test('re-emits after a hole insert', () async {
      final cid = await fx.insertCourse();
      final rid = await fx.insertRound(cid);

      final stream = db.dashboardDao.watchStats();
      final results = <DashboardStats>[];
      final sub = stream.listen(results.add);

      await Future<void>.delayed(Duration.zero);
      await fx.upsertHole(rid, 1);
      await Future<void>.delayed(Duration.zero);

      expect(results.length, greaterThanOrEqualTo(2));
      expect(results.first.roundsPlayed, 0);
      expect(results.last.roundsPlayed, 1);

      await sub.cancel();
    });
  });
}
