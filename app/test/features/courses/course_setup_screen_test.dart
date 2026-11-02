import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/database.dart';
import 'package:golfy_app/data/database_provider.dart';
import 'package:golfy_app/data/models/round_with_course.dart';
import 'package:golfy_app/data/repository_provider.dart';
import 'package:golfy_app/features/courses/course_setup_screen.dart';

void main() {
  const courseId = 1;

  late GolfyDatabase db;

  setUp(() {
    db = GolfyDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Course course({String name = 'Augusta', String game = 'PGA'}) =>
      Course(id: courseId, name: name, gameTitle: game);

  RoundWithCourse round(int id, {int? teeSetId, int? pinSetId}) =>
      RoundWithCourse(
        round: Round(
          id: id,
          date: '2026-05-25',
          courseId: courseId,
          roundNumber: 1,
          teeSetId: teeSetId,
          pinSetId: pinSetId,
        ),
        courseName: 'Augusta',
        event: null,
        holesEntered: 0,
        totalScore: 0,
        totalPar: 0,
      );

  /// The par/SI card (yardage lives on tee sets and pin sets, not here).
  List<CourseHole> uniformCard({int par = 5, int? strokeIndex}) => [
        for (var h = 1; h <= 18; h++)
          CourseHole(
            id: h,
            courseId: courseId,
            holeNumber: h,
            par: par,
            strokeIndex: strokeIndex,
          ),
      ];

  TeeSet tee(int id, String name) =>
      TeeSet(id: id, courseId: courseId, name: name);

  PinSet pin(int id, String name) =>
      PinSet(id: id, courseId: courseId, name: name);

  List<CourseYard> uniformYards(int teeSetId, int yards) => [
        for (var h = 1; h <= 18; h++)
          CourseYard(
            id: teeSetId * 100 + h,
            teeSetId: teeSetId,
            holeNumber: h,
            yards: yards,
          ),
      ];

  List<TeeToPinYard> uniformToPin(int teeSetId, int pinSetId, int yards) => [
        for (var h = 1; h <= 18; h++)
          TeeToPinYard(
            id: teeSetId * 1000 + pinSetId * 100 + h,
            teeSetId: teeSetId,
            pinSetId: pinSetId,
            holeNumber: h,
            yards: yards,
          ),
      ];

  /// Pumps a placeholder home with an "open" button, then pushes the screen so
  /// its Delete action can pop back. Providers use single-value streams so the
  /// screen always resolves to data (a lingering spinner would hang
  /// pumpAndSettle), regardless of when it subscribes during the push.
  ///
  /// The viewport is tall because the editor is a list of eighteen full cards
  /// and a ListView won't build children beyond its cache extent.
  Future<void> pump(
    WidgetTester tester, {
    List<Course>? courses,
    List<RoundWithCourse> rounds = const [],
    List<CourseHole>? card,
    List<TeeSet> tees = const [],
    List<PinSet> pins = const [],
    Map<int, List<CourseYard>> yards = const {},
    Map<(int, int), List<TeeToPinYard>> toPin = const {},
  }) async {
    tester.view.physicalSize = const Size(900, 4400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final courseList = courses ?? [course()];
    final parSiCard = card ?? uniformCard();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        coursesByNameStreamProvider
            .overrideWith((ref) => Stream.value(courseList)),
        roundsStreamProvider.overrideWith((ref) => Stream.value(rounds)),
        courseHolesStreamProvider
            .overrideWith((ref, id) => Stream.value(parSiCard)),
        teeSetsStreamProvider.overrideWith((ref, id) => Stream.value(tees)),
        pinSetsStreamProvider.overrideWith((ref, id) => Stream.value(pins)),
        courseYardsStreamProvider.overrideWith(
          (ref, id) => Stream.value(yards[id] ?? const <CourseYard>[]),
        ),
        teeToPinYardsStreamProvider.overrideWith(
          (ref, sets) => Stream.value(toPin[sets] ?? const <TeeToPinYard>[]),
        ),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CourseSetupScreen(courseId: courseId),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> settleDb(WidgetTester tester) async {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
  }

  int parShown(WidgetTester tester, int hole) => tester
      .widget<SegmentedButton<int>>(
        find.descendant(
          of: find.byKey(ValueKey('course_hole_par_$hole')),
          matching: find.byType(SegmentedButton<int>),
        ),
      )
      .selected
      .first;

  String textShown(WidgetTester tester, Key key) =>
      tester.widget<TextField>(find.byKey(key)).controller!.text;

  group('CourseSetupScreen — Hole Entry idioms (#81)', () {
    testWidgets('par is a segmented button, not a dropdown', (tester) async {
      await pump(tester, card: uniformCard(par: 5, strokeIndex: 7));

      // The split this issue exists to remove: the same 3/4/5 choice used to be
      // a dropdown here and a segmented button on the Hole Entry card.
      expect(find.byKey(const ValueKey('course_hole_par_1')), findsOneWidget);
      expect(parShown(tester, 1), 5);
      expect(find.text('Par 5'), findsNothing);
    });

    testWidgets('seeds par, stroke index, course yards and tee to pin',
        (tester) async {
      await pump(
        tester,
        card: uniformCard(par: 5, strokeIndex: 7),
        tees: [tee(9, 'Blue')],
        pins: [pin(4, 'Sunday pins')],
        yards: {9: uniformYards(9, 431)},
        toPin: {(9, 4): uniformToPin(9, 4, 418)},
      );

      expect(parShown(tester, 1), 5);
      expect(textShown(tester, const ValueKey('course_hole_si_1')), '7');
      expect(textShown(tester, const ValueKey('course_hole_yards_1')), '431');
      expect(
        textShown(tester, const ValueKey('course_hole_tee_to_pin_1')),
        '418',
      );
      expect(find.text('Course yards · Blue'), findsWidgets);
      expect(find.text('Tee to pin · Sunday pins'), findsWidgets);
    });

    testWidgets('shows a progress counter and jumps to a tapped hole',
        (tester) async {
      await pump(
        tester,
        card: uniformCard(par: 4, strokeIndex: 3),
        tees: [tee(9, 'Blue')],
        yards: {9: uniformYards(9, 400)},
      );

      expect(find.text('Holes set: 18 / 18'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('course_hole_chip_12')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('course_hole_card_12')), findsOneWidget);
    });

    testWidgets('a hole with no stroke index does not count as set',
        (tester) async {
      await pump(tester, card: uniformCard(par: 4, strokeIndex: null));
      expect(find.text('Holes set: 0 / 18'), findsOneWidget);
    });
  });

  group('CourseSetupScreen — per-hole saved state (#81)', () {
    testWidgets('editing one hole marks only that hole unsaved',
        (tester) async {
      await pump(tester, card: uniformCard(par: 4, strokeIndex: 3));

      // Nothing edited yet: every card reads Saved.
      expect(find.text('Unsaved'), findsNothing);
      expect(find.text('All saved'), findsOneWidget);

      await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('course_hole_par_3')),
        matching: find.text('5'),
      ));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('course_hole_card_3')),
          matching: find.text('Unsaved'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('course_hole_card_4')),
          matching: find.text('Saved'),
        ),
        findsOneWidget,
      );
      expect(find.text('Save card · 1 unsaved'), findsOneWidget);
    });

    testWidgets('a course with no stored card starts from par 72, all unsaved',
        (tester) async {
      await pump(tester, card: const []);

      // The standard layout is a starting point to accept, not to inherit.
      expect(parShown(tester, 1), 4);
      expect(parShown(tester, 2), 5);
      expect(parShown(tester, 3), 3);
      expect(find.text('Save card · 18 unsaved'), findsOneWidget);
    });

    testWidgets('saving writes the card and clears every chip', (tester) async {
      // course_holes.course_id is a real FK, so the parent course must exist in
      // the db under test (the stream override only feeds the UI).
      await db.courseDao
          .insert(CoursesCompanion.insert(name: 'Augusta', gameTitle: 'PGA'));
      await pump(tester, card: const []);

      await tester.tap(find.byKey(const ValueKey('save_course_card')));
      await settleDb(tester);

      final saved =
          await tester.runAsync(() => db.courseHoleDao.getForCourse(courseId));
      expect(saved, hasLength(18));
      expect(saved!.firstWhere((h) => h.holeNumber == 2).par, 5);
      expect(find.text('All saved'), findsOneWidget);
      expect(find.text('Unsaved'), findsNothing);
    });

    testWidgets('an edited stroke index reaches the database', (tester) async {
      await db.courseDao
          .insert(CoursesCompanion.insert(name: 'Augusta', gameTitle: 'PGA'));
      await pump(tester, card: uniformCard(par: 4, strokeIndex: 3));

      await tester.enterText(
          find.byKey(const ValueKey('course_hole_si_1')), '11');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save_course_card')));
      await settleDb(tester);

      final saved =
          await tester.runAsync(() => db.courseHoleDao.getForCourse(courseId));
      expect(saved!.firstWhere((h) => h.holeNumber == 1).strokeIndex, 11);
    });
  });

  group('CourseSetupScreen — tee sets and pin sets', () {
    testWidgets('saving writes course yards and tee to pin with the card',
        (tester) async {
      final cid = await db.courseDao
          .insert(CoursesCompanion.insert(name: 'Augusta', gameTitle: 'PGA'));
      final blue = await db.yardageDao
          .insertTeeSet(TeeSetsCompanion.insert(courseId: cid, name: 'Blue'));
      final sunday = await db.yardageDao.insertPinSet(
          PinSetsCompanion.insert(courseId: cid, name: 'Sunday pins'));

      await pump(
        tester,
        card: uniformCard(par: 4, strokeIndex: 3),
        tees: [tee(blue, 'Blue')],
        pins: [pin(sunday, 'Sunday pins')],
        yards: {blue: uniformYards(blue, 400)},
      );

      await tester.enterText(
          find.byKey(const ValueKey('course_hole_yards_1')), '455');
      await tester.enterText(
          find.byKey(const ValueKey('course_hole_tee_to_pin_1')), '441');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save_course_card')));
      await settleDb(tester);

      final course =
          await tester.runAsync(() => db.yardageDao.getCourseYards(blue));
      expect(course, hasLength(18));
      expect(course!.firstWhere((y) => y.holeNumber == 1).yards, 455);
      expect(course.firstWhere((y) => y.holeNumber == 2).yards, 400);
      final toPin = await tester
          .runAsync(() => db.yardageDao.getTeeToPinYards(blue, sunday));
      expect(toPin, hasLength(18));
      expect(toPin!.firstWhere((y) => y.holeNumber == 1).yards, 441);
      expect(find.text('All saved'), findsOneWidget);
    });

    testWidgets('switching tee sets swaps the course yards and carries edits',
        (tester) async {
      await pump(
        tester,
        card: uniformCard(par: 4, strokeIndex: 3),
        tees: [tee(9, 'Blue'), tee(10, 'White')],
        yards: {9: uniformYards(9, 431), 10: uniformYards(10, 388)},
      );

      expect(textShown(tester, const ValueKey('course_hole_yards_1')), '431');

      await tester.enterText(
          find.byKey(const ValueKey('course_hole_yards_1')), '440');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tee_set_chip_10')));
      await tester.pumpAndSettle();
      expect(textShown(tester, const ValueKey('course_hole_yards_1')), '388');

      // Coming back must still show the unsaved edit — switching tee boxes is
      // not a reason to lose work.
      await tester.tap(find.byKey(const ValueKey('tee_set_chip_9')));
      await tester.pumpAndSettle();
      expect(textShown(tester, const ValueKey('course_hole_yards_1')), '440');
      expect(find.text('Save card · 1 unsaved'), findsOneWidget);
    });

    testWidgets('switching pin sets swaps tee to pin, not course yards',
        (tester) async {
      await pump(
        tester,
        card: uniformCard(par: 4, strokeIndex: 3),
        tees: [tee(9, 'Blue')],
        pins: [pin(4, 'Monday pins'), pin(5, 'Sunday pins')],
        yards: {9: uniformYards(9, 431)},
        toPin: {
          (9, 4): uniformToPin(9, 4, 425),
          (9, 5): uniformToPin(9, 5, 409),
        },
      );

      expect(
          textShown(tester, const ValueKey('course_hole_tee_to_pin_1')), '425');

      await tester.tap(find.byKey(const ValueKey('pin_set_chip_5')));
      await tester.pumpAndSettle();
      expect(
          textShown(tester, const ValueKey('course_hole_tee_to_pin_1')), '409');
      // The scorecard yardage is the tee set's, whatever the pins.
      expect(textShown(tester, const ValueKey('course_hole_yards_1')), '431');
    });

    testWidgets('opens on the sets of the round last played here',
        (tester) async {
      // "Update course as I play" records into the round's sets; the editor
      // has to show those, not whichever set sorts first by name.
      await pump(
        tester,
        card: uniformCard(par: 4, strokeIndex: 3),
        rounds: [
          round(2, teeSetId: 10, pinSetId: 5),
          round(1, teeSetId: 9, pinSetId: 4),
        ],
        tees: [tee(9, 'Blue'), tee(10, 'White')],
        pins: [pin(4, 'Monday pins'), pin(5, 'Sunday pins')],
        yards: {9: uniformYards(9, 431), 10: uniformYards(10, 402)},
        toPin: {
          (9, 4): uniformToPin(9, 4, 425),
          (10, 5): uniformToPin(10, 5, 388),
        },
      );

      expect(textShown(tester, const ValueKey('course_hole_yards_1')), '402');
      expect(
          textShown(tester, const ValueKey('course_hole_tee_to_pin_1')), '388');

      // A set picked by hand sticks.
      await tester.tap(find.byKey(const ValueKey('pin_set_chip_4')));
      await tester.pumpAndSettle();
      expect(
          textShown(tester, const ValueKey('course_hole_tee_to_pin_1')), '');
    });

    testWidgets('a pin set with nothing entered does not read unsaved',
        (tester) async {
      // Every tee set has its own tee-to-pin card for every pin set; looking at
      // one not filled in yet must not make eighteen holes unsaved.
      await pump(
        tester,
        card: uniformCard(par: 4, strokeIndex: 3),
        tees: [tee(9, 'Blue')],
        pins: [pin(4, 'Sunday pins')],
        yards: {9: uniformYards(9, 431)},
      );

      expect(
          textShown(tester, const ValueKey('course_hole_tee_to_pin_1')), '');
      expect(find.text('All saved'), findsOneWidget);
    });

    testWidgets('a set the user never opened keeps its stored yards',
        (tester) async {
      // The danger of a wholesale replace: writing a never-loaded card would
      // blank an entire tee box.
      final cid = await db.courseDao
          .insert(CoursesCompanion.insert(name: 'Augusta', gameTitle: 'PGA'));
      final blue = await db.yardageDao
          .insertTeeSet(TeeSetsCompanion.insert(courseId: cid, name: 'Blue'));
      final white = await db.yardageDao
          .insertTeeSet(TeeSetsCompanion.insert(courseId: cid, name: 'White'));
      await db.yardageDao.replaceCourseYards(white, [
        for (var h = 1; h <= 18; h++)
          CourseYardsCompanion.insert(
              teeSetId: white, holeNumber: h, yards: 360),
      ]);

      await pump(
        tester,
        card: uniformCard(par: 4, strokeIndex: 3),
        tees: [tee(blue, 'Blue'), tee(white, 'White')],
        yards: {blue: uniformYards(blue, 400), white: uniformYards(white, 360)},
      );

      await tester.enterText(
          find.byKey(const ValueKey('course_hole_yards_1')), '455');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save_course_card')));
      await settleDb(tester);

      final untouched =
          await tester.runAsync(() => db.yardageDao.getCourseYards(white));
      expect(untouched, hasLength(18));
      expect(untouched!.every((y) => y.yards == 360), isTrue);
    });

    testWidgets('with no sets, both yards fields are disabled and say why',
        (tester) async {
      await pump(tester, card: uniformCard(par: 4, strokeIndex: 3));

      final yards = tester.widget<TextField>(
        find.byKey(const ValueKey('course_hole_yards_1')),
      );
      expect(yards.enabled, isFalse);
      final toPin = tester.widget<TextField>(
        find.byKey(const ValueKey('course_hole_tee_to_pin_1')),
      );
      expect(toPin.enabled, isFalse);
      expect(find.text("No tee sets yet. Add one (e.g. Blue) to record each "
          "hole's course yards."), findsOneWidget);
      expect(find.text('No pin sets yet. Add one (e.g. Sunday pins) to record '
          'tee-to-pin yards from each tee set.'), findsOneWidget);
    });

    testWidgets('with a tee set but no pin set, tee to pin says why',
        (tester) async {
      await pump(
        tester,
        card: uniformCard(par: 4, strokeIndex: 3),
        tees: [tee(9, 'Blue')],
        yards: {9: uniformYards(9, 431)},
      );

      final toPin = tester.widget<TextField>(
        find.byKey(const ValueKey('course_hole_tee_to_pin_1')),
      );
      expect(toPin.enabled, isFalse);
      expect(toPin.decoration!.helperText, 'No pin set');
    });
  });

  group('CourseSetupScreen — unsaved-changes guard (#81)', () {
    testWidgets('backing out with edits asks before discarding',
        (tester) async {
      await pump(tester, card: uniformCard(par: 4, strokeIndex: 3));

      await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('course_hole_par_1')),
        matching: find.text('3'),
      ));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Discard unsaved changes?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('discard_course_changes')));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('backing out with nothing to lose just pops', (tester) async {
      await pump(tester, card: uniformCard(par: 4, strokeIndex: 3));

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Discard unsaved changes?'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  });

  group('CourseSetupScreen — course actions', () {
    testWidgets('delete is blocked while the course has rounds',
        (tester) async {
      await pump(tester, rounds: [round(1)]);

      await tester.tap(find.byKey(const ValueKey('course_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text("Can't delete course"), findsOneWidget);
    });

    testWidgets('deleting a course with no rounds removes it and pops',
        (tester) async {
      // Also the guard's canary: the delete path pops programmatically, and the
      // unsaved-changes confirm must not stand in its way.
      final cid = await db.courseDao
          .insert(CoursesCompanion.insert(name: 'Augusta', gameTitle: 'PGA'));
      await pump(tester, card: const []);

      await tester.tap(find.byKey(const ValueKey('course_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settleDb(tester);

      final remaining = await tester.runAsync(() => db.courseDao.watchAll().first);
      expect(remaining!.where((c) => c.id == cid), isEmpty);
      expect(find.text('Discard unsaved changes?'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('shows a gone-state when the course no longer exists',
        (tester) async {
      await pump(tester, courses: const []);
      expect(find.text('This course no longer exists.'), findsOneWidget);
    });
  });

  // #73: renaming a set was a long press only; it is also a named action on
  // the chip, so a screen reader can reach it.
  testWidgets('a set chip offers "Rename tee set" as an action',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, tees: [tee(9, 'Blue')]);

    tester.semantics.customAction(
      find.semantics.byLabel('Blue'),
      const CustomSemanticsAction(label: 'Rename tee set'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rename tee set'), findsOneWidget);
    semantics.dispose();
  });
}
