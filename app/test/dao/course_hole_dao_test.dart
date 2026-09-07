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

  CourseHolesCompanion hole(
    int courseId,
    int holeNumber, {
    int par = 4,
    int? strokeIndex,
  }) {
    return CourseHolesCompanion.insert(
      courseId: courseId,
      holeNumber: holeNumber,
      par: par,
      strokeIndex: Value(strokeIndex),
    );
  }

  group('CourseHoleDao.replaceForCourse', () {
    test('inserts the full 18-hole card', () async {
      final cid = await fx.insertCourse();
      await fx.insertCourseHoles(cid);

      final rows = await db.courseHoleDao.getForCourse(cid);
      expect(rows, hasLength(18));
      expect(rows.map((h) => h.holeNumber), List.generate(18, (i) => i + 1));
    });

    test('replaces the whole card — stale rows are cleared', () async {
      final cid = await fx.insertCourse();
      await fx.insertCourseHoles(cid); // 18 holes

      // Replace with a shorter, different card.
      await db.courseHoleDao.replaceForCourse(cid, [
        hole(cid, 1, par: 3, strokeIndex: 17),
        hole(cid, 2, par: 5),
      ]);

      final rows = await db.courseHoleDao.getForCourse(cid);
      expect(rows, hasLength(2));
      expect(rows.first.par, 3);
      expect(rows.first.strokeIndex, 17);
      expect(rows[1].par, 5);
      expect(rows[1].strokeIndex, isNull);
    });

    test('only touches the target course', () async {
      final a = await fx.insertCourse(name: 'A');
      final b = await fx.insertCourse(name: 'B');
      await fx.insertCourseHoles(a, count: 3);
      await fx.insertCourseHoles(b, count: 18);

      // Replacing A's card leaves B's intact.
      await db.courseHoleDao.replaceForCourse(a, [hole(a, 1)]);

      expect(await db.courseHoleDao.getForCourse(a), hasLength(1));
      expect(await db.courseHoleDao.getForCourse(b), hasLength(18));
    });
  });

  group('CourseHoleDao.watchForCourse', () {
    test('emits empty for a course with no template', () async {
      final cid = await fx.insertCourse();
      expect(await db.courseHoleDao.watchForCourse(cid).first, isEmpty);
    });

    test('orders by hole number', () async {
      final cid = await fx.insertCourse();
      // Insert out of order; the stream must still come back 1..3.
      await db.courseHoleDao.replaceForCourse(cid, [
        hole(cid, 3),
        hole(cid, 1),
        hole(cid, 2),
      ]);
      final rows = await db.courseHoleDao.watchForCourse(cid).first;
      expect(rows.map((h) => h.holeNumber), [1, 2, 3]);
    });

    test('re-emits after the template is replaced', () async {
      final cid = await fx.insertCourse();
      final results = <List<CourseHole>>[];
      final sub = db.courseHoleDao.watchForCourse(cid).listen(results.add);

      await Future<void>.delayed(Duration.zero);
      await fx.insertCourseHoles(cid, count: 2);
      await Future<void>.delayed(Duration.zero);

      expect(results.length, greaterThanOrEqualTo(2));
      expect(results.first, isEmpty);
      expect(results.last, hasLength(2));

      await sub.cancel();
    });

    test('emits empty after the parent course is deleted (cascade)', () async {
      final cid = await fx.insertCourse();
      await fx.insertCourseHoles(cid, count: 2);
      expect(await db.courseHoleDao.watchForCourse(cid).first, hasLength(2));

      await db.courseDao.deleteById(cid);
      expect(await db.courseHoleDao.watchForCourse(cid).first, isEmpty);
    });
  });
}
