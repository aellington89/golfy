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

  group('CourseSetDao — sets', () {
    test('watchSetsForCourse orders by name and re-emits', () async {
      final cid = await fx.insertCourse();
      final results = <List<CourseSet>>[];
      final sub = db.courseSetDao.watchSetsForCourse(cid).listen(results.add);

      await Future<void>.delayed(Duration.zero);
      await fx.insertCourseSet(cid, name: 'White');
      await fx.insertCourseSet(cid, name: 'Blue');
      await Future<void>.delayed(Duration.zero);

      expect(results.first, isEmpty);
      expect(results.last.map((s) => s.name).toList(), ['Blue', 'White']);
      await sub.cancel();
    });

    test('insertSet rejects a duplicate name within a course', () async {
      final cid = await fx.insertCourse();
      await fx.insertCourseSet(cid, name: 'Blue');
      await expectLater(
        fx.insertCourseSet(cid, name: 'Blue'),
        throwsA(isA<Exception>()),
      );
    });

    test('renameSet changes the name; a collision throws', () async {
      final cid = await fx.insertCourse();
      final blue = await fx.insertCourseSet(cid, name: 'Blue');
      await fx.insertCourseSet(cid, name: 'White');

      await db.courseSetDao.renameSet(blue, 'Championship');
      final sets = await db.courseSetDao.watchSetsForCourse(cid).first;
      expect(sets.map((s) => s.name), containsAll(['Championship', 'White']));

      await expectLater(
        db.courseSetDao.renameSet(blue, 'White'),
        throwsA(isA<Exception>()),
      );
    });

    test('deleteSet removes the set (and its yardages cascade)', () async {
      final cid = await fx.insertCourse();
      final sid = await fx.insertCourseSet(cid);
      await fx.insertCourseSetYards(sid, count: 3);
      expect(await db.courseSetDao.watchYardsForSet(sid).first, hasLength(3));

      await db.courseSetDao.deleteSet(sid);
      expect(await db.courseSetDao.watchSetsForCourse(cid).first, isEmpty);
      expect(await db.courseSetDao.watchYardsForSet(sid).first, isEmpty);
    });
  });

  group('CourseSetDao — yardages', () {
    test('replaceForSet writes the card, ordered by hole', () async {
      final cid = await fx.insertCourse();
      final sid = await fx.insertCourseSet(cid);
      await db.courseSetDao.replaceYardsForSet(sid, [
        CourseSetYardsCompanion.insert(courseSetId: sid, holeNumber: 3, yards: 500),
        CourseSetYardsCompanion.insert(courseSetId: sid, holeNumber: 1, yards: 420),
        CourseSetYardsCompanion.insert(courseSetId: sid, holeNumber: 2, yards: 150),
      ]);

      final rows = await db.courseSetDao.getYardsForSet(sid);
      expect(rows.map((y) => y.holeNumber), [1, 2, 3]);
      expect(rows.map((y) => y.yards), [420, 150, 500]);
    });

    test('replaceForSet replaces wholesale — stale rows cleared', () async {
      final cid = await fx.insertCourse();
      final sid = await fx.insertCourseSet(cid);
      await fx.insertCourseSetYards(sid); // 18

      await db.courseSetDao.replaceYardsForSet(sid, [
        CourseSetYardsCompanion.insert(courseSetId: sid, holeNumber: 1, yards: 300),
      ]);
      expect(await db.courseSetDao.getYardsForSet(sid), hasLength(1));
    });

    test('only touches the target set', () async {
      final cid = await fx.insertCourse();
      final a = await fx.insertCourseSet(cid, name: 'A');
      final b = await fx.insertCourseSet(cid, name: 'B');
      await fx.insertCourseSetYards(a, count: 4);
      await fx.insertCourseSetYards(b, count: 18);

      await db.courseSetDao.replaceYardsForSet(a, [
        CourseSetYardsCompanion.insert(courseSetId: a, holeNumber: 1, yards: 100),
      ]);
      expect(await db.courseSetDao.getYardsForSet(a), hasLength(1));
      expect(await db.courseSetDao.getYardsForSet(b), hasLength(18));
    });
  });
}
