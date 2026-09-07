import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/database.dart';
import 'package:golfy_app/data/database_provider.dart';
import 'package:golfy_app/data/models/round_with_course.dart';
import 'package:golfy_app/data/repository_provider.dart';
import 'package:golfy_app/features/courses/course_holes_screen.dart';

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

  // The shared par/SI card (yardage lives on sets now, not here).
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

  // Pumps a placeholder home with an "open" button, then pushes the screen so
  // its Delete action can pop back. Providers use single-value streams so the
  // screen always resolves to data (a lingering spinner would hang
  // pumpAndSettle), regardless of when it subscribes during the push.
  Future<void> pump(
    WidgetTester tester, {
    List<Course>? courses,
    List<RoundWithCourse> rounds = const [],
    List<CourseHole>? card,
    List<CourseSet> sets = const [],
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
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
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CourseHolesScreen(courseId: courseId),
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

  testWidgets('seeds the first hole par + stroke index from the card',
      (tester) async {
    await pump(tester, card: uniformCard(par: 5, strokeIndex: 7));

    final row1 = find.byKey(const ValueKey('course_hole_row_1'));
    expect(row1, findsOneWidget);
    expect(find.descendant(of: row1, matching: find.text('Par 5')),
        findsOneWidget);
    final si = tester.widget<TextFormField>(
      find.descendant(
        of: row1,
        matching: find.byKey(const ValueKey('course_hole_si_1')),
      ),
    );
    expect(si.initialValue, '7');
  });

  testWidgets('Save writes the full 18-hole par/SI card to the database',
      (tester) async {
    // course_holes.course_id is a real FK, so the parent course must exist in
    // the db under test (the stream override only feeds the UI).
    await db.courseDao
        .insert(CoursesCompanion.insert(name: 'Augusta', gameTitle: 'PGA'));
    await pump(tester, card: uniformCard(par: 4, strokeIndex: 3));

    await tester.tap(find.byKey(const ValueKey('save_course_card')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    final saved =
        await tester.runAsync(() => db.courseHoleDao.getForCourse(courseId));
    expect(saved, hasLength(18));
    expect(saved!.first.par, 4);
    expect(saved.first.strokeIndex, 3);
  });

  testWidgets('editing a hole\'s stroke index is persisted on Save',
      (tester) async {
    await db.courseDao
        .insert(CoursesCompanion.insert(name: 'Augusta', gameTitle: 'PGA'));
    await pump(tester, card: uniformCard(par: 4));

    await tester.enterText(
        find.byKey(const ValueKey('course_hole_si_1')), '11');
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('save_course_card')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    final saved =
        await tester.runAsync(() => db.courseHoleDao.getForCourse(courseId));
    expect(saved!.firstWhere((h) => h.holeNumber == 1).strokeIndex, 11);
  });

  testWidgets('lists the course\'s yardage sets and an Add-set action',
      (tester) async {
    await pump(
      tester,
      sets: [const CourseSet(id: 9, courseId: courseId, name: 'Blue tees')],
    );

    expect(find.byKey(const ValueKey('add_yardage_set')), findsOneWidget);
    expect(find.text('Blue tees'), findsOneWidget);
    expect(find.byKey(const ValueKey('yardage_set_tile_9')), findsOneWidget);
  });

  testWidgets('with no sets, shows the empty hint', (tester) async {
    await pump(tester); // no sets

    expect(find.textContaining('No yardage sets yet'), findsOneWidget);
  });

  testWidgets('delete is blocked while the course has rounds', (tester) async {
    await pump(tester, rounds: [round(1), round(2)]);

    await tester.tap(find.byKey(const ValueKey('course_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text("Can't delete course"), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'OK'), findsOneWidget);
    expect(find.text('Delete course?'), findsNothing);
  });

  testWidgets('deleting a course with no rounds removes it and pops',
      (tester) async {
    await db.courseDao
        .insert(CoursesCompanion.insert(name: 'Augusta', gameTitle: 'PGA'));

    await pump(tester); // no rounds

    await tester.tap(find.byKey(const ValueKey('course_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete course?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    final remaining =
        await tester.runAsync(() => db.courseDao.watchAll().first);
    expect(remaining, isEmpty);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('shows a gone-state when the course no longer exists',
      (tester) async {
    await pump(tester, courses: []);

    expect(find.text('This course no longer exists.'), findsOneWidget);
  });
}
