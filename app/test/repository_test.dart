import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/database.dart';
import 'package:golfy_app/data/models/hole_shot_input.dart';
import 'package:golfy_app/data/repository.dart';

import 'dao/_fixtures.dart';

/// Cross-DAO behaviour that only exists on the repository facade. The DAOs have
/// their own suites; what's covered here is the composition — above all
/// [GolfyRepository.saveHole], which writes a hole and its shot list together
/// and is the one place a hole_results id is used as a foreign key.
void main() {
  late GolfyDatabase db;
  late TestFixtures fx;
  late GolfyRepository repo;

  setUp(() {
    db = GolfyDatabase.forTesting(NativeDatabase.memory());
    fx = TestFixtures(db);
    repo = GolfyRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('GolfyRepository.saveHole', () {
    test('writes the hole and its shots together', () async {
      final cid = await fx.insertCourse();
      final rid = await fx.insertRound(cid);

      await repo.saveHole(fx.holeCompanion(rid, 1), const [
        HoleShotInput(club: 'Driver', distanceYards: 420, lie: 'Tee'),
        HoleShotInput(club: 'Putter', lie: 'Green', result: 'Holed'),
      ]);

      final shots = await repo.watchHoleShots(rid).first;
      expect(shots[1], hasLength(2));
      expect(shots[1]!.first.shotNumber, 1);
      expect(shots[1]!.last.result, 'Holed');
    });

    test('re-saving a hole keeps its shots on that hole', () async {
      // The second save of a hole takes the upsert's DO UPDATE path, which
      // leaves `last_insert_rowid()` naming the last row actually inserted —
      // one of the hole_shots rows the first save wrote. Keying the shots off
      // that stale rowid dropped the player's edit: the shots either landed on
      // a different hole or tripped the foreign key and rolled the save back.
      final cid = await fx.insertCourse();
      final rid = await fx.insertRound(cid);

      await repo.saveHole(fx.holeCompanion(rid, 1, par: 3, score: 3, putts: 1,
          fairwayHit: null, gir: false), const [
        HoleShotInput(club: '5 Iron', distanceYards: 165, lie: 'Tee'),
        HoleShotInput(club: 'Putter', lie: 'Green', result: 'Holed'),
      ]);
      // The par-3 tee shot missed the green: a second shot is inserted before
      // the putt, played from where the hole card can't say — the fairway.
      await repo.saveHole(fx.holeCompanion(rid, 1, par: 3, score: 3, putts: 1,
          fairwayHit: null, gir: false), const [
        HoleShotInput(club: '5 Iron', distanceYards: 165, lie: 'Tee'),
        HoleShotInput(lie: 'Fairway'),
        HoleShotInput(club: 'Putter', lie: 'Green', result: 'Holed'),
      ]);

      final shots = await repo.watchHoleShots(rid).first;
      expect(shots[1], hasLength(3));
      expect(shots[1]![1].lie, 'Fairway');
      expect(shots[1]![1].shotNumber, 2);
    });

    test('re-saving a hole leaves every other hole\'s shots alone', () async {
      final cid = await fx.insertCourse();
      final rid = await fx.insertRound(cid);

      await repo.saveHole(fx.holeCompanion(rid, 1), const [
        HoleShotInput(club: 'Driver', lie: 'Tee'),
      ]);
      await repo.saveHole(fx.holeCompanion(rid, 2), const [
        HoleShotInput(club: '3 Wood', lie: 'Tee'),
      ]);

      await repo.saveHole(fx.holeCompanion(rid, 1), const [
        HoleShotInput(club: 'Driver', lie: 'Tee'),
        HoleShotInput(club: '9 Iron', lie: 'Fairway'),
      ]);

      final shots = await repo.watchHoleShots(rid).first;
      expect(shots[1], hasLength(2));
      expect(shots[2], hasLength(1));
      expect(shots[2]!.single.club, '3 Wood');
    });

    test('re-saving with no shots clears the hole\'s shot list', () async {
      final cid = await fx.insertCourse();
      final rid = await fx.insertRound(cid);

      await repo.saveHole(fx.holeCompanion(rid, 1), const [
        HoleShotInput(club: 'Driver', lie: 'Tee'),
      ]);
      await repo.saveHole(fx.holeCompanion(rid, 1), const []);

      final shots = await repo.watchHoleShots(rid).first;
      expect(shots[1], isNull);
    });

    test('a re-save updates the hole row in place, keeping its id', () async {
      final cid = await fx.insertCourse();
      final rid = await fx.insertRound(cid);

      final firstId = await repo.saveHole(fx.holeCompanion(rid, 1, score: 4),
          const [HoleShotInput(club: 'Driver', lie: 'Tee')]);
      final secondId = await repo.saveHole(fx.holeCompanion(rid, 1, score: 6),
          const [HoleShotInput(club: 'Driver', lie: 'Tee')]);

      expect(secondId, firstId);
      final holes = await repo.watchHoleResults(rid).first;
      expect(holes, hasLength(1));
      expect(holes.single.score, 6);
    });
  });
}
