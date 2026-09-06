import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/database.dart';

import '_fixtures.dart';

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

  Future<({int roundId, int hole1, int hole2})> seed() async {
    final cid = await fx.insertCourse();
    final rid = await fx.insertRound(cid);
    final h1 = await fx.upsertHole(rid, 1);
    final h2 = await fx.upsertHole(rid, 2);
    return (roundId: rid, hole1: h1, hole2: h2);
  }

  HoleShotsCompanion shot(int holeResultId, int shotNumber, {String? club}) {
    return HoleShotsCompanion.insert(
      holeResultId: holeResultId,
      shotNumber: shotNumber,
      club: Value(club),
    );
  }

  test('replaceForHole writes shots ordered by shot number', () async {
    final s = await seed();
    await db.holeShotDao.replaceForHole(s.hole1, [
      shot(s.hole1, 2, club: '7 iron'),
      shot(s.hole1, 1, club: 'Driver'),
    ]);

    final byHole = await db.holeShotDao.watchForRound(s.roundId).first;
    expect(byHole[1], hasLength(2));
    expect(byHole[1]!.map((x) => x.shotNumber), [1, 2]);
    expect(byHole[1]!.first.club, 'Driver');
  });

  test('watchForRound keys shots by hole number', () async {
    final s = await seed();
    await db.holeShotDao.replaceForHole(s.hole1, [shot(s.hole1, 1)]);
    await db.holeShotDao
        .replaceForHole(s.hole2, [shot(s.hole2, 1), shot(s.hole2, 2)]);

    final byHole = await db.holeShotDao.watchForRound(s.roundId).first;
    expect(byHole[1], hasLength(1));
    expect(byHole[2], hasLength(2));
  });

  test('replaceForHole replaces wholesale — stale shots cleared', () async {
    final s = await seed();
    await db.holeShotDao
        .replaceForHole(s.hole1, [shot(s.hole1, 1), shot(s.hole1, 2)]);
    await db.holeShotDao.replaceForHole(s.hole1, [shot(s.hole1, 1)]);

    final byHole = await db.holeShotDao.watchForRound(s.roundId).first;
    expect(byHole[1], hasLength(1));
  });

  test('shots cascade when their hole_results row is deleted', () async {
    final s = await seed();
    await db.holeShotDao.replaceForHole(s.hole1, [shot(s.hole1, 1)]);
    // Deleting the round cascades hole_results, which cascades hole_shots.
    await db.roundDao.deleteById(s.roundId);
    expect(await db.holeShotDao.watchForRound(s.roundId).first, isEmpty);
  });

  test('re-emits after a shot is added', () async {
    final s = await seed();
    final results = <Map<int, List<HoleShot>>>[];
    final sub = db.holeShotDao.watchForRound(s.roundId).listen(results.add);

    await Future<void>.delayed(Duration.zero);
    await db.holeShotDao.replaceForHole(s.hole1, [shot(s.hole1, 1)]);
    await Future<void>.delayed(Duration.zero);

    expect(results.first, isEmpty);
    expect(results.last[1], hasLength(1));
    await sub.cancel();
  });
}
