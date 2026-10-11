import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/database.dart';
import 'package:golfy_app/data/repository.dart';

import '_fixtures.dart';

/// Covers the per-hole upserts and the single-transaction card save added for
/// the reworked course editor (#81). Reactivity lives here rather than in a
/// widget test — see the note in `app/README.md`.
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

  CourseHolesCompanion hole(int courseId, int n, {int par = 4, int? si}) =>
      CourseHolesCompanion.insert(
        courseId: courseId,
        holeNumber: n,
        par: par,
        strokeIndex: Value(si),
      );

  CourseYardsCompanion yard(int teeSetId, int n, int yards) =>
      CourseYardsCompanion.insert(
        teeSetId: teeSetId,
        holeNumber: n,
        yards: yards,
      );

  TeeToPinYardsCompanion toPin(int teeSetId, int pinSetId, int n, int yards) =>
      TeeToPinYardsCompanion.insert(
        teeSetId: teeSetId,
        pinSetId: pinSetId,
        holeNumber: n,
        yards: yards,
      );

  group('upsertCourseHole', () {
    test('inserts a hole that has no row yet', () async {
      final courseId = await fx.insertCourse();

      await repo.upsertCourseHole(hole(courseId, 7, par: 5, si: 3));

      final card = await db.courseHoleDao.getForCourse(courseId);
      expect(card, hasLength(1));
      expect(card.single.holeNumber, 7);
      expect(card.single.par, 5);
      expect(card.single.strokeIndex, 3);
    });

    test('updates in place, keeping the row id', () async {
      final courseId = await fx.insertCourse();
      await fx.insertCourseHoles(courseId, par: 4, strokeIndex: 1);
      final before = await db.courseHoleDao.getForCourse(courseId);
      final originalId = before.firstWhere((h) => h.holeNumber == 7).id;

      await repo.upsertCourseHole(hole(courseId, 7, par: 3, si: 12));

      final after = await db.courseHoleDao.getForCourse(courseId);
      final updated = after.firstWhere((h) => h.holeNumber == 7);
      expect(after, hasLength(18), reason: 'no row was added');
      expect(updated.id, originalId, reason: 'updated, not replaced');
      expect(updated.par, 3);
      expect(updated.strokeIndex, 12);
    });

    test('a par-only upsert keeps an existing stroke index', () async {
      // What "Update course as I play" relies on: the round form has no stroke
      // index field, so it upserts par alone. Drift must leave columns the
      // companion doesn't carry untouched, or playing a hole would silently
      // erase a stroke index somebody entered on the course.
      final courseId = await fx.insertCourse();
      await fx.insertCourseHoles(courseId, par: 4, strokeIndex: 9);

      await repo.upsertCourseHole(CourseHolesCompanion.insert(
        courseId: courseId,
        holeNumber: 7,
        par: 5,
      ));

      final updated = (await db.courseHoleDao.getForCourse(courseId))
          .firstWhere((h) => h.holeNumber == 7);
      expect(updated.par, 5);
      expect(updated.strokeIndex, 9, reason: 'stroke index must survive');
    });

    test('leaves the other 17 holes alone', () async {
      final courseId = await fx.insertCourse();
      await fx.insertCourseHoles(courseId, par: 4, strokeIndex: 1);

      await repo.upsertCourseHole(hole(courseId, 7, par: 5, si: 9));

      final card = await db.courseHoleDao.getForCourse(courseId);
      final others = card.where((h) => h.holeNumber != 7);
      expect(others, hasLength(17));
      expect(others.every((h) => h.par == 4 && h.strokeIndex == 1), isTrue);
    });

    test('does not reach into another course', () async {
      final a = await fx.insertCourse(name: 'A');
      final b = await fx.insertCourse(name: 'B');
      await fx.insertCourseHoles(a, par: 4);
      await fx.insertCourseHoles(b, par: 4);

      await repo.upsertCourseHole(hole(a, 1, par: 5));

      final other = await db.courseHoleDao.getForCourse(b);
      expect(other.firstWhere((h) => h.holeNumber == 1).par, 4);
    });

    test('the course card stream re-emits after an upsert', () async {
      final courseId = await fx.insertCourse();
      await fx.insertCourseHoles(courseId, par: 4);

      final emissions = <int>[];
      final sub = db.courseHoleDao.watchForCourse(courseId).listen((card) {
        emissions.add(card.firstWhere((h) => h.holeNumber == 1).par);
      });
      await pumpEventQueue();

      await repo.upsertCourseHole(hole(courseId, 1, par: 3));
      await pumpEventQueue();
      await sub.cancel();

      expect(emissions, [4, 3]);
    });
  });

  group('upsertCourseYard', () {
    test('inserts then updates one hole without disturbing the rest', () async {
      final courseId = await fx.insertCourse();
      final teeSetId = await fx.insertTeeSet(courseId);
      await fx.insertCourseYards(teeSetId, yards: 400);

      await repo.upsertCourseYard(yard(teeSetId, 4, 172));

      final card = await db.yardageDao.getCourseYards(teeSetId);
      expect(card, hasLength(18));
      expect(card.firstWhere((y) => y.holeNumber == 4).yards, 172);
      expect(
        card.where((y) => y.holeNumber != 4).every((y) => y.yards == 400),
        isTrue,
      );
    });

    test('does not reach into another tee set', () async {
      final courseId = await fx.insertCourse();
      final blue = await fx.insertTeeSet(courseId, name: 'Blue');
      final white = await fx.insertTeeSet(courseId, name: 'White');
      await fx.insertCourseYards(blue, yards: 400);
      await fx.insertCourseYards(white, yards: 360);

      await repo.upsertCourseYard(yard(blue, 1, 999));

      final other = await db.yardageDao.getCourseYards(white);
      expect(other.firstWhere((y) => y.holeNumber == 1).yards, 360);
    });
  });

  group('upsertTeeToPinYard', () {
    test('writes one yardage set\'s hole, leaving course yards alone',
        () async {
      final courseId = await fx.insertCourse();
      final blue = await fx.insertTeeSet(courseId);
      final sunday = await fx.insertPinSet(courseId);
      await fx.insertCourseYards(blue, yards: 400);

      await repo.upsertTeeToPinYard(toPin(blue, sunday, 4, 388));

      final toPinCard = await db.yardageDao.getTeeToPinYards(blue, sunday);
      expect(toPinCard.single.holeNumber, 4);
      expect(toPinCard.single.yards, 388);
      final courseYards = await db.yardageDao.getCourseYards(blue);
      expect(courseYards.every((y) => y.yards == 400), isTrue);
    });
  });

  group('replaceCourseCard', () {
    test('writes par/SI, course yards and tee-to-pin yards in one call',
        () async {
      final courseId = await fx.insertCourse();
      final blue = await fx.insertTeeSet(courseId, name: 'Blue');
      final white = await fx.insertTeeSet(courseId, name: 'White');
      final sunday = await fx.insertPinSet(courseId);

      await repo.replaceCourseCard(
        courseId,
        [for (var h = 1; h <= 18; h++) hole(courseId, h, par: 5, si: h)],
        courseYardsByTeeSet: {
          blue: [for (var h = 1; h <= 18; h++) yard(blue, h, 500)],
          white: [for (var h = 1; h <= 18; h++) yard(white, h, 420)],
        },
        teeToPinByYardageSet: {
          (blue, sunday): [
            for (var h = 1; h <= 18; h++) toPin(blue, sunday, h, 490),
          ],
        },
      );

      final card = await db.courseHoleDao.getForCourse(courseId);
      expect(card, hasLength(18));
      expect(card.every((h) => h.par == 5), isTrue);
      expect(card.first.strokeIndex, 1);
      expect(
        (await db.yardageDao.getCourseYards(blue)).every((y) => y.yards == 500),
        isTrue,
      );
      expect(
        (await db.yardageDao.getCourseYards(white))
            .every((y) => y.yards == 420),
        isTrue,
      );
      expect(
        (await db.yardageDao.getTeeToPinYards(blue, sunday))
            .every((y) => y.yards == 490),
        isTrue,
      );
    });

    test('a card left out of the maps keeps its stored yards', () async {
      // The editor only passes cards it has actually loaded. A wholesale
      // replace with a blank card would wipe yards the user never opened.
      final courseId = await fx.insertCourse();
      final blue = await fx.insertTeeSet(courseId, name: 'Blue');
      final white = await fx.insertTeeSet(courseId, name: 'White');
      final sunday = await fx.insertPinSet(courseId);
      await fx.insertCourseYards(blue, yards: 400);
      await fx.insertCourseYards(white, yards: 360);
      await fx.insertTeeToPinYards(white, sunday, yards: 350);

      await repo.replaceCourseCard(
        courseId,
        [for (var h = 1; h <= 18; h++) hole(courseId, h)],
        courseYardsByTeeSet: {
          blue: [for (var h = 1; h <= 18; h++) yard(blue, h, 410)],
        },
      );

      final untouched = await db.yardageDao.getCourseYards(white);
      expect(untouched, hasLength(18));
      expect(untouched.every((y) => y.yards == 360), isTrue);
      final untouchedToPin =
          await db.yardageDao.getTeeToPinYards(white, sunday);
      expect(untouchedToPin.every((y) => y.yards == 350), isTrue);
    });

    test('rolls the whole card back when a yardage write fails', () async {
      // The reason this method exists: separate replaces could leave the
      // course half-saved while the editor reported everything as saved.
      final courseId = await fx.insertCourse();
      final otherCourse = await fx.insertCourse(name: 'Elsewhere');
      final blue = await fx.insertTeeSet(courseId, name: 'Blue');
      final foreignPins = await fx.insertPinSet(otherCourse);
      await fx.insertCourseHoles(courseId, par: 4);
      await fx.insertCourseYards(blue, yards: 400);

      // The pin set is another course's, so the tee-to-pin write — the last
      // one — is refused.
      await expectLater(
        repo.replaceCourseCard(
          courseId,
          [for (var h = 1; h <= 18; h++) hole(courseId, h, par: 5)],
          courseYardsByTeeSet: {
            blue: [for (var h = 1; h <= 18; h++) yard(blue, h, 500)],
          },
          teeToPinByYardageSet: {
            (blue, foreignPins): [toPin(blue, foreignPins, 1, 300)],
          },
        ),
        throwsA(anything),
      );

      final card = await db.courseHoleDao.getForCourse(courseId);
      expect(card.every((h) => h.par == 4), isTrue,
          reason: 'the par write must have rolled back');
      final yards = await db.yardageDao.getCourseYards(blue);
      expect(yards.every((y) => y.yards == 400), isTrue,
          reason: 'the course-yards write must have rolled back too');
    });
  });
}
