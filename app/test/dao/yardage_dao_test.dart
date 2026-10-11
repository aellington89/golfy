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

  group('YardageDao — tee sets', () {
    test('watchTeeSetsForCourse orders by name and re-emits', () async {
      final cid = await fx.insertCourse();
      final results = <List<TeeSet>>[];
      final sub =
          db.yardageDao.watchTeeSetsForCourse(cid).listen(results.add);

      await Future<void>.delayed(Duration.zero);
      await fx.insertTeeSet(cid, name: 'White');
      await fx.insertTeeSet(cid, name: 'Blue');
      await Future<void>.delayed(Duration.zero);

      expect(results.first, isEmpty);
      expect(results.last.map((s) => s.name).toList(), ['Blue', 'White']);
      await sub.cancel();
    });

    test('insertTeeSet rejects a duplicate name within a course', () async {
      final cid = await fx.insertCourse();
      await fx.insertTeeSet(cid, name: 'Blue');
      await expectLater(
        fx.insertTeeSet(cid, name: 'Blue'),
        throwsA(isA<Exception>()),
      );
    });

    test('renameTeeSet changes the name; a collision throws', () async {
      final cid = await fx.insertCourse();
      final blue = await fx.insertTeeSet(cid, name: 'Blue');
      await fx.insertTeeSet(cid, name: 'White');

      await db.yardageDao.renameTeeSet(blue, 'Championship');
      final sets = await db.yardageDao.watchTeeSetsForCourse(cid).first;
      expect(sets.map((s) => s.name), containsAll(['Championship', 'White']));

      await expectLater(
        db.yardageDao.renameTeeSet(blue, 'White'),
        throwsA(isA<Exception>()),
      );
    });

    test('deleteTeeSet cascades its course yards and tee-to-pin yards',
        () async {
      final cid = await fx.insertCourse();
      final tee = await fx.insertTeeSet(cid);
      final pin = await fx.insertPinSet(cid);
      await fx.insertCourseYards(tee, count: 3);
      await fx.insertTeeToPinYards(tee, pin, count: 3);

      await db.yardageDao.deleteTeeSet(tee);
      expect(await db.yardageDao.watchTeeSetsForCourse(cid).first, isEmpty);
      expect(await db.yardageDao.getCourseYards(tee), isEmpty);
      expect(await db.yardageDao.getTeeToPinYards(tee, pin), isEmpty);
      // The pin set is the course's, not the tee set's: it stays.
      expect(await db.yardageDao.watchPinSetsForCourse(cid).first, hasLength(1));
    });
  });

  group('YardageDao — pin sets', () {
    test('watchPinSetsForCourse orders by name; names are per course',
        () async {
      final a = await fx.insertCourse(name: 'A');
      final b = await fx.insertCourse(name: 'B');
      await fx.insertPinSet(a, name: 'Tournament day 1');
      await fx.insertPinSet(a, name: 'Sunday pins');
      // The same name on another course is a different pin set.
      await fx.insertPinSet(b, name: 'Sunday pins');

      final sets = await db.yardageDao.watchPinSetsForCourse(a).first;
      expect(sets.map((s) => s.name), ['Sunday pins', 'Tournament day 1']);
      await expectLater(
        fx.insertPinSet(a, name: 'Sunday pins'),
        throwsA(isA<Exception>()),
      );
    });

    test('renamePinSet changes the name; a collision throws', () async {
      final cid = await fx.insertCourse();
      final sunday = await fx.insertPinSet(cid, name: 'Sunday pins');
      await fx.insertPinSet(cid, name: 'Monday pins');

      await db.yardageDao.renamePinSet(sunday, 'Final round');
      final sets = await db.yardageDao.watchPinSetsForCourse(cid).first;
      expect(sets.map((s) => s.name), ['Final round', 'Monday pins']);

      await expectLater(
        db.yardageDao.renamePinSet(sunday, 'Monday pins'),
        throwsA(isA<Exception>()),
      );
    });

    test('deletePinSet cascades its tee-to-pin yards, not course yards',
        () async {
      final cid = await fx.insertCourse();
      final tee = await fx.insertTeeSet(cid);
      final pin = await fx.insertPinSet(cid);
      await fx.insertCourseYards(tee);
      await fx.insertTeeToPinYards(tee, pin);

      await db.yardageDao.deletePinSet(pin);
      expect(await db.yardageDao.getTeeToPinYards(tee, pin), isEmpty);
      // Course yards never depended on the pins.
      expect(await db.yardageDao.getCourseYards(tee), hasLength(18));
    });
  });

  group('YardageDao — course yards', () {
    test('replaceCourseYards writes the card, ordered by hole', () async {
      final cid = await fx.insertCourse();
      final tee = await fx.insertTeeSet(cid);
      await db.yardageDao.replaceCourseYards(tee, [
        CourseYardsCompanion.insert(teeSetId: tee, holeNumber: 3, yards: 500),
        CourseYardsCompanion.insert(teeSetId: tee, holeNumber: 1, yards: 420),
        CourseYardsCompanion.insert(teeSetId: tee, holeNumber: 2, yards: 150),
      ]);

      final rows = await db.yardageDao.getCourseYards(tee);
      expect(rows.map((y) => y.holeNumber), [1, 2, 3]);
      expect(rows.map((y) => y.yards), [420, 150, 500]);
    });

    test('replaceCourseYards replaces wholesale, only for its tee set',
        () async {
      final cid = await fx.insertCourse();
      final a = await fx.insertTeeSet(cid, name: 'A');
      final b = await fx.insertTeeSet(cid, name: 'B');
      await fx.insertCourseYards(a);
      await fx.insertCourseYards(b);

      await db.yardageDao.replaceCourseYards(a, [
        CourseYardsCompanion.insert(teeSetId: a, holeNumber: 1, yards: 300),
      ]);
      expect(await db.yardageDao.getCourseYards(a), hasLength(1));
      expect(await db.yardageDao.getCourseYards(b), hasLength(18));
    });

    test('upsertCourseYard updates one hole in place and returns its id',
        () async {
      // See `HoleResultDao.upsert`: `last_insert_rowid()` is only advanced by a
      // real insert, so on the DO UPDATE path it names whatever was inserted
      // last anywhere in the database.
      final cid = await fx.insertCourse();
      final tee = await fx.insertTeeSet(cid);
      await fx.insertCourseYards(tee, yards: 400);
      final firstId = await db.yardageDao.upsertCourseYard(
        CourseYardsCompanion.insert(teeSetId: tee, holeNumber: 4, yards: 165),
      );
      await fx.insertTeeSet(cid, name: 'Another tee set');

      final secondId = await db.yardageDao.upsertCourseYard(
        CourseYardsCompanion.insert(teeSetId: tee, holeNumber: 4, yards: 170),
      );

      expect(secondId, firstId);
      final rows = await db.yardageDao.getCourseYards(tee);
      expect(rows, hasLength(18));
      expect(rows[3].yards, 170);
      expect(rows[2].yards, 400);
    });
  });

  group('YardageDao — tee-to-pin yards', () {
    test('vary with the tee set and the pin set independently', () async {
      final cid = await fx.insertCourse();
      final blue = await fx.insertTeeSet(cid, name: 'Blue');
      final white = await fx.insertTeeSet(cid, name: 'White');
      final sunday = await fx.insertPinSet(cid, name: 'Sunday pins');
      final monday = await fx.insertPinSet(cid, name: 'Monday pins');
      await fx.insertTeeToPinYards(blue, sunday, yards: 410);
      await fx.insertTeeToPinYards(blue, monday, yards: 395);
      await fx.insertTeeToPinYards(white, sunday, yards: 380);

      Future<int> hole1(int tee, int pin) async =>
          (await db.yardageDao.getTeeToPinYards(tee, pin)).first.yards;
      expect(await hole1(blue, sunday), 410);
      expect(await hole1(blue, monday), 395);
      expect(await hole1(white, sunday), 380);
      expect(await db.yardageDao.getTeeToPinYards(white, monday), isEmpty);
    });

    test('replaceTeeToPinYards replaces only its own yardage set', () async {
      final cid = await fx.insertCourse();
      final tee = await fx.insertTeeSet(cid);
      final sunday = await fx.insertPinSet(cid, name: 'Sunday pins');
      final monday = await fx.insertPinSet(cid, name: 'Monday pins');
      await fx.insertTeeToPinYards(tee, sunday);
      await fx.insertTeeToPinYards(tee, monday);

      await db.yardageDao.replaceTeeToPinYards(tee, sunday, [
        TeeToPinYardsCompanion.insert(
          teeSetId: tee,
          pinSetId: sunday,
          holeNumber: 1,
          yards: 300,
        ),
      ]);
      expect(await db.yardageDao.getTeeToPinYards(tee, sunday), hasLength(1));
      expect(await db.yardageDao.getTeeToPinYards(tee, monday), hasLength(18));
    });

    test('upsertTeeToPinYard updates one hole in place and returns its id',
        () async {
      final cid = await fx.insertCourse();
      final tee = await fx.insertTeeSet(cid);
      final pin = await fx.insertPinSet(cid);
      await fx.insertTeeToPinYards(tee, pin, yards: 390);
      final firstId = await db.yardageDao.upsertTeeToPinYard(
        TeeToPinYardsCompanion.insert(
          teeSetId: tee,
          pinSetId: pin,
          holeNumber: 2,
          yards: 160,
        ),
      );
      await fx.insertPinSet(cid, name: 'Another pin set');

      final secondId = await db.yardageDao.upsertTeeToPinYard(
        TeeToPinYardsCompanion.insert(
          teeSetId: tee,
          pinSetId: pin,
          holeNumber: 2,
          yards: 172,
        ),
      );

      expect(secondId, firstId);
      final rows = await db.yardageDao.getTeeToPinYards(tee, pin);
      expect(rows, hasLength(18));
      expect(rows[1].yards, 172);
      expect(rows[0].yards, 390);
    });

    test('a tee set and a pin set from different courses are refused',
        () async {
      final a = await fx.insertCourse(name: 'A');
      final b = await fx.insertCourse(name: 'B');
      final tee = await fx.insertTeeSet(a);
      final pin = await fx.insertPinSet(b);

      await expectLater(
        db.yardageDao.upsertTeeToPinYard(TeeToPinYardsCompanion.insert(
          teeSetId: tee,
          pinSetId: pin,
          holeNumber: 1,
          yards: 400,
        )),
        throwsArgumentError,
      );
      await expectLater(
        fx.insertTeeToPinYards(tee, pin),
        throwsArgumentError,
      );
      expect(await db.yardageDao.getTeeToPinYards(tee, pin), isEmpty);
    });
  });
}
