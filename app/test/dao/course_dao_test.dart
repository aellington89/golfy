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

  group('CourseDao.insert', () {
    test('returns the generated row id', () async {
      final id = await fx.insertCourse();
      expect(id, isPositive);
    });

    test('a second insert returns a distinct id', () async {
      final first = await fx.insertCourse(name: 'A');
      final second = await fx.insertCourse(name: 'B');
      expect(second, isNot(first));
    });
  });

  group('CourseDao.watchAll', () {
    test('emits empty list when no rows', () async {
      final first = await db.courseDao.watchAll().first;
      expect(first, isEmpty);
    });

    test('orders by (gameTitle ASC, name ASC)', () async {
      await fx.insertCourse(name: 'Bandon', gameTitle: 'EA Sports PGA Tour');
      await fx.insertCourse(name: 'Augusta', gameTitle: 'PGA Tour 2K25');
      await fx.insertCourse(name: 'Pebble', gameTitle: 'EA Sports PGA Tour');

      final rows = await db.courseDao.watchAll().first;
      expect(
        rows.map((c) => '${c.gameTitle}/${c.name}').toList(),
        [
          'EA Sports PGA Tour/Bandon',
          'EA Sports PGA Tour/Pebble',
          'PGA Tour 2K25/Augusta',
        ],
      );
    });

    test('re-emits after an insert', () async {
      final stream = db.courseDao.watchAll();
      final results = <List<Course>>[];
      final sub = stream.listen(results.add);

      // Initial empty emission.
      await Future<void>.delayed(Duration.zero);
      await fx.insertCourse(name: 'A');
      await Future<void>.delayed(Duration.zero);

      expect(results.length, greaterThanOrEqualTo(2));
      expect(results.first, isEmpty);
      expect(results.last.map((c) => c.name).toList(), ['A']);

      await sub.cancel();
    });
  });

  group('CourseDao.watchAllByName', () {
    test('emits empty list when no rows', () async {
      final first = await db.courseDao.watchAllByName().first;
      expect(first, isEmpty);
    });

    test('orders strictly by name across game titles', () async {
      await fx.insertCourse(name: 'Bandon', gameTitle: 'EA Sports PGA Tour');
      await fx.insertCourse(name: 'Augusta', gameTitle: 'PGA Tour 2K25');
      await fx.insertCourse(name: 'Pebble', gameTitle: 'EA Sports PGA Tour');

      final rows = await db.courseDao.watchAllByName().first;
      expect(
        rows.map((c) => c.name).toList(),
        ['Augusta', 'Bandon', 'Pebble'],
      );
    });

    test('re-emits after an insert', () async {
      final stream = db.courseDao.watchAllByName();
      final results = <List<Course>>[];
      final sub = stream.listen(results.add);

      await Future<void>.delayed(Duration.zero);
      await fx.insertCourse(name: 'A');
      await Future<void>.delayed(Duration.zero);

      expect(results.length, greaterThanOrEqualTo(2));
      expect(results.first, isEmpty);
      expect(results.last.map((c) => c.name).toList(), ['A']);

      await sub.cancel();
    });
  });

  group('CourseDao.getOrCreate', () {
    CoursesCompanion company({
      String name = 'Pebble',
      String game = 'PGA 2K25',
    }) =>
        CoursesCompanion.insert(name: name, gameTitle: game);

    test('inserts when absent and returns a positive id', () async {
      final id = await db.courseDao.getOrCreate(company());
      expect(id, isPositive);
      expect(await db.courseDao.watchAll().first, hasLength(1));
    });

    test('returns the same id and creates no duplicate when present',
        () async {
      final first = await db.courseDao.getOrCreate(company());
      final second = await db.courseDao.getOrCreate(company());
      expect(second, first);
      expect(await db.courseDao.watchAll().first, hasLength(1));
    });

    test('returns the id of a course inserted earlier via insert()', () async {
      final inserted =
          await fx.insertCourse(name: 'Pebble', gameTitle: 'PGA 2K25');
      final got = await db.courseDao.getOrCreate(company());
      expect(got, inserted);
    });

    test('distinguishes courses that share a name across game titles',
        () async {
      final a = await db.courseDao.getOrCreate(company(game: 'PGA 2K25'));
      final b =
          await db.courseDao.getOrCreate(company(game: 'EA Sports PGA Tour'));
      expect(b, isNot(a));
      expect(await db.courseDao.watchAll().first, hasLength(2));
    });
  });
}
