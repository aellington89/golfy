import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/database.dart';
import 'package:golfy_app/data/models/event_stats.dart';

import '_fixtures.dart';

/// DAO-level coverage for the per-event scoring aggregate (#56),
/// `DashboardDao.watchEventStats`. Mirrors `dashboard_dao_test.dart`: seeds an
/// in-memory database via [TestFixtures] and asserts hand-computed aggregates.
/// Reactivity is covered here (at the DAO level) per the project's widget-test
/// reactivity constraint.
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

  group('watchEventStats — no data', () {
    test('an event with no rounds → zero counts, null aggregates', () async {
      final eid = await fx.insertEvent();

      final stats = await db.dashboardDao.watchEventStats(eid).first;

      expect(stats.roundsScored, 0);
      expect(stats.holesPlayed, 0);
      expect(stats.avgScorePerRound, isNull);
      expect(stats.avgScoreVsPar, isNull);
      expect(stats.bestRound, isNull);
      expect(stats.hasData, isFalse);
    });

    test('an event whose round has no entered holes → still no data', () async {
      final eid = await fx.insertEvent();
      final cid = await fx.insertCourse();
      await fx.insertRound(cid, eventId: eid); // round exists, no holes

      final stats = await db.dashboardDao.watchEventStats(eid).first;

      expect(stats.roundsScored, 0);
      expect(stats.holesPlayed, 0);
      expect(stats.avgScoreVsPar, isNull);
      expect(stats.bestRound, isNull);
    });
  });

  group('watchEventStats — aggregates', () {
    test('rounds scored / holes played / averages / best round', () async {
      final eid = await fx.insertEvent();
      final pebble = await fx.insertCourse(name: 'Pebble Beach');
      final augusta = await fx.insertCourse(name: 'Augusta National');

      // Round A: 9 holes, all par 4 / score 4 → to-par 0, SUM(score) = 36.
      final rA = await fx.insertRound(pebble, date: '2026-05-01', eventId: eid);
      for (var h = 1; h <= 9; h++) {
        await fx.upsertHole(rA, h, par: 4, score: 4);
      }
      // Round B: 9 holes par 4; eight score 4 + one score 6 → to-par +2,
      // SUM(score) = 38.
      final rB = await fx.insertRound(augusta, date: '2026-05-15', eventId: eid);
      for (var h = 1; h <= 9; h++) {
        await fx.upsertHole(rB, h, par: 4, score: h == 9 ? 6 : 4);
      }

      final stats = await db.dashboardDao.watchEventStats(eid).first;

      expect(stats.roundsScored, 2);
      expect(stats.holesPlayed, 18);
      expect(stats.avgScorePerRound, closeTo(37.0, 1e-9)); // (36 + 38) / 2
      expect(stats.avgScoreVsPar, closeTo(1.0, 1e-9)); // (0 + 2) / 2
      expect(stats.hasData, isTrue);
      expect(stats.bestRound, isNotNull);
      expect(stats.bestRound!.roundId, rA);
      expect(stats.bestRound!.courseName, 'Pebble Beach');
      expect(stats.bestRound!.date, '2026-05-01');
      expect(stats.bestRound!.toPar, 0);
    });

    test('excludes rounds from other events and casual rounds', () async {
      final target = await fx.insertEvent(name: 'Target');
      final other = await fx.insertEvent(name: 'Other');
      final cid = await fx.insertCourse();

      // Target event: one round, 9 pars → to-par 0.
      final r1 = await fx.insertRound(cid, date: '2026-05-01', eventId: target);
      for (var h = 1; h <= 9; h++) {
        await fx.upsertHole(r1, h, par: 4, score: 4);
      }
      // Another event's round (much worse) — must not leak in.
      final r2 = await fx.insertRound(cid, date: '2026-05-02', eventId: other);
      for (var h = 1; h <= 9; h++) {
        await fx.upsertHole(r2, h, par: 4, score: 7);
      }
      // A casual round (no event) — must not leak in.
      final r3 = await fx.insertRound(cid, date: '2026-05-03');
      for (var h = 1; h <= 9; h++) {
        await fx.upsertHole(r3, h, par: 4, score: 6);
      }

      final stats = await db.dashboardDao.watchEventStats(target).first;

      expect(stats.roundsScored, 1);
      expect(stats.holesPlayed, 9);
      expect(stats.avgScoreVsPar, closeTo(0.0, 1e-9));
      expect(stats.bestRound!.roundId, r1);
    });
  });

  group('watchEventStats — best-round tie-break', () {
    test('equal to-par resolves to the more recent date', () async {
      final eid = await fx.insertEvent();
      final cid = await fx.insertCourse();
      final early = await fx.insertRound(cid, date: '2026-05-01', eventId: eid);
      final later = await fx.insertRound(cid, date: '2026-05-20', eventId: eid);
      for (var h = 1; h <= 3; h++) {
        await fx.upsertHole(early, h, par: 4, score: 4); // to-par 0
        await fx.upsertHole(later, h, par: 4, score: 4); // to-par 0
      }

      final stats = await db.dashboardDao.watchEventStats(eid).first;

      expect(stats.bestRound!.roundId, later);
      expect(stats.bestRound!.toPar, 0);
    });

    test('same date + to-par resolves to the higher (newer) round id', () async {
      final eid = await fx.insertEvent();
      final cid = await fx.insertCourse();
      // Same course + date → distinct round numbers to satisfy the UNIQUE key.
      final first = await fx.insertRound(cid,
          date: '2026-05-01', roundNumber: 1, eventId: eid);
      final second = await fx.insertRound(cid,
          date: '2026-05-01', roundNumber: 2, eventId: eid);
      for (var h = 1; h <= 3; h++) {
        await fx.upsertHole(first, h, par: 4, score: 4); // to-par 0
        await fx.upsertHole(second, h, par: 4, score: 4); // to-par 0
      }

      final stats = await db.dashboardDao.watchEventStats(eid).first;

      expect(stats.bestRound!.roundId, second);
    });
  });

  group('watchEventStats — reactivity', () {
    test('re-emits after a hole insert into one of the event\'s rounds',
        () async {
      final eid = await fx.insertEvent();
      final cid = await fx.insertCourse();
      final rid = await fx.insertRound(cid, eventId: eid);

      final stream = db.dashboardDao.watchEventStats(eid);
      final results = <EventStats>[];
      final sub = stream.listen(results.add);

      await Future<void>.delayed(Duration.zero);
      await fx.upsertHole(rid, 1, par: 4, score: 5); // +1
      await Future<void>.delayed(Duration.zero);

      expect(results.length, greaterThanOrEqualTo(2));
      expect(results.first.roundsScored, 0);
      expect(results.last.roundsScored, 1);
      expect(results.last.holesPlayed, 1);

      await sub.cancel();
    });
  });
}
