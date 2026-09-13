import 'package:drift/native.dart';
import 'package:flutter/material.dart';
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

  RoundWithCourse round(int id) => RoundWithCourse(
        round: Round(
          id: id,
          date: '2026-05-25',
          courseId: courseId,
          roundNumber: 1,
        ),
        courseName: 'Augusta',
        event: null,
        holesEntered: 0,
        totalScore: 0,
        totalPar: 0,
      );

  /// The shared par/SI card (yardage lives on sets, not here).
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

  CourseSet set(int id, String name) =>
      CourseSet(id: id, courseId: courseId, name: name);

  List<CourseSetYard> uniformYards(int setId, int yards) => [
        for (var h = 1; h <= 18; h++)
          CourseSetYard(
            id: setId * 100 + h,
            courseSetId: setId,
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
    List<CourseSet> sets = const [],
    Map<int, List<CourseSetYard>> yards = const {},
  }) async {
    tester.view.physicalSize = const Size(900, 3200);
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
        courseSetsStreamProvider.overrideWith((ref, id) => Stream.value(sets)),
        courseSetYardsStreamProvider.overrideWith(
          (ref, id) => Stream.value(yards[id] ?? const <CourseSetYard>[]),
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

    testWidgets('seeds par, stroke index and the active set\'s yardage',
        (tester) async {
      await pump(
        tester,
        card: uniformCard(par: 5, strokeIndex: 7),
        sets: [set(9, 'Blue tees')],
        yards: {9: uniformYards(9, 431)},
      );

      expect(parShown(tester, 1), 5);
      expect(textShown(tester, const ValueKey('course_hole_si_1')), '7');
      expect(textShown(tester, const ValueKey('course_hole_yards_1')), '431');
    });

    testWidgets('shows a progress counter and jumps to a tapped hole',
        (tester) async {
      await pump(
        tester,
        card: uniformCard(par: 4, strokeIndex: 3),
        sets: [set(9, 'Blue tees')],
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

  group('CourseSetupScreen — yardage sets (#81)', () {
    testWidgets('saving writes the active set\'s yardages alongside the card',
        (tester) async {
      final cid = await db.courseDao
          .insert(CoursesCompanion.insert(name: 'Augusta', gameTitle: 'PGA'));
      final setId = await db.courseSetDao
          .insertSet(CourseSetsCompanion.insert(courseId: cid, name: 'Blue'));

      await pump(
        tester,
        card: uniformCard(par: 4, strokeIndex: 3),
        sets: [set(setId, 'Blue')],
        yards: {setId: uniformYards(setId, 400)},
      );

      await tester.enterText(
          find.byKey(const ValueKey('course_hole_yards_1')), '455');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save_course_card')));
      await settleDb(tester);

      final stored = await tester
          .runAsync(() => db.courseSetDao.getYardsForSet(setId));
      expect(stored, hasLength(18));
      expect(stored!.firstWhere((y) => y.holeNumber == 1).yards, 455);
      expect(stored.firstWhere((y) => y.holeNumber == 2).yards, 400);
    });

    testWidgets('switching sets swaps the yardage shown and carries edits back',
        (tester) async {
      await pump(
        tester,
        card: uniformCard(par: 4, strokeIndex: 3),
        sets: [set(9, 'Blue'), set(10, 'White')],
        yards: {9: uniformYards(9, 431), 10: uniformYards(10, 388)},
      );

      expect(textShown(tester, const ValueKey('course_hole_yards_1')), '431');

      await tester.enterText(
          find.byKey(const ValueKey('course_hole_yards_1')), '440');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('yardage_set_chip_10')));
      await tester.pumpAndSettle();
      expect(textShown(tester, const ValueKey('course_hole_yards_1')), '388');

      // Coming back must still show the unsaved edit — switching tee boxes is
      // not a reason to lose work.
      await tester.tap(find.byKey(const ValueKey('yardage_set_chip_9')));
      await tester.pumpAndSettle();
      expect(textShown(tester, const ValueKey('course_hole_yards_1')), '440');
      expect(find.text('Save card · 1 unsaved'), findsOneWidget);
    });

    testWidgets('a set the user never opened keeps its stored yardages',
        (tester) async {
      // The danger of a wholesale replace: writing a never-loaded set would
      // blank an entire tee box.
      final cid = await db.courseDao
          .insert(CoursesCompanion.insert(name: 'Augusta', gameTitle: 'PGA'));
      final blue = await db.courseSetDao
          .insertSet(CourseSetsCompanion.insert(courseId: cid, name: 'Blue'));
      final white = await db.courseSetDao
          .insertSet(CourseSetsCompanion.insert(courseId: cid, name: 'White'));
      await db.courseSetDao.replaceYardsForSet(white, [
        for (var h = 1; h <= 18; h++)
          CourseSetYardsCompanion.insert(
              courseSetId: white, holeNumber: h, yards: 360),
      ]);

      await pump(
        tester,
        card: uniformCard(par: 4, strokeIndex: 3),
        sets: [set(blue, 'Blue'), set(white, 'White')],
        yards: {blue: uniformYards(blue, 400), white: uniformYards(white, 360)},
      );

      await tester.enterText(
          find.byKey(const ValueKey('course_hole_yards_1')), '455');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save_course_card')));
      await settleDb(tester);

      final untouched =
          await tester.runAsync(() => db.courseSetDao.getYardsForSet(white));
      expect(untouched, hasLength(18));
      expect(untouched!.every((y) => y.yards == 360), isTrue);
    });

    testWidgets('with no sets, the yardage field is disabled and says why',
        (tester) async {
      await pump(tester, card: uniformCard(par: 4, strokeIndex: 3));

      final yards = tester.widget<TextField>(
        find.byKey(const ValueKey('course_hole_yards_1')),
      );
      expect(yards.enabled, isFalse);
      expect(find.text('No yardage sets yet. Add one (e.g. a tee box or pin '
          'set) to record per-hole yardages.'), findsOneWidget);
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
}
