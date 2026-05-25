import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/database.dart';
import 'package:golfy_app/data/database_provider.dart';
import 'package:golfy_app/features/courses/add_course_dialog.dart';

void main() {
  late GolfyDatabase db;

  setUp(() {
    db = GolfyDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget wrap({
    List<Course> existing = const [],
    void Function(Course?)? onResult,
  }) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final result = await showDialog<Course>(
                      context: context,
                      builder: (_) =>
                          AddCourseDialog(existingCourses: existing),
                    );
                    if (onResult != null) onResult(result);
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Bounded pump — focused TextFormFields keep cursor-blink animations
  // running indefinitely, so pumpAndSettle would hang.
  Future<void> settle(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 400));

  Future<void> openDialog(
    WidgetTester tester, {
    List<Course> existing = const [],
    void Function(Course?)? onResult,
  }) async {
    await tester.pumpWidget(wrap(existing: existing, onResult: onResult));
    await tester.tap(find.text('Open'));
    await settle(tester);
  }

  testWidgets('empty name shows validation error and does not insert',
      (tester) async {
    await openDialog(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Game Title'),
      'PGA Tour 2K25',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await settle(tester);

    expect(find.text('Required'), findsOneWidget);
    expect(find.byType(AddCourseDialog), findsOneWidget);

    final rows = await tester.runAsync(
      () => db.courseDao.watchAllByName().first,
    );
    expect(rows, isEmpty);
  });

  testWidgets('empty game title shows validation error and does not insert',
      (tester) async {
    await openDialog(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Course Name'),
      'Pebble Beach',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await settle(tester);

    expect(find.text('Required'), findsOneWidget);
    expect(find.byType(AddCourseDialog), findsOneWidget);

    final rows = await tester.runAsync(
      () => db.courseDao.watchAllByName().first,
    );
    expect(rows, isEmpty);
  });

  testWidgets(
      'duplicate (name, gameTitle) shows error and does not insert again',
      (tester) async {
    const existing = [
      Course(id: 1, name: 'Pebble Beach', gameTitle: 'PGA Tour 2K25'),
    ];
    await db.courseDao.insert(
      CoursesCompanion.insert(name: 'Pebble Beach', gameTitle: 'PGA Tour 2K25'),
    );

    await openDialog(tester, existing: existing);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Course Name'),
      'Pebble Beach',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Game Title'),
      'PGA Tour 2K25',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await settle(tester);

    expect(find.text('Course already exists'), findsOneWidget);
    expect(find.byType(AddCourseDialog), findsOneWidget);

    final rows = await tester.runAsync(
      () => db.courseDao.watchAllByName().first,
    );
    expect(rows, hasLength(1));
  });

  testWidgets('valid input inserts row and pops with the new Course',
      (tester) async {
    Course? popped;
    await openDialog(tester, onResult: (c) => popped = c);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Course Name'),
      'Augusta',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Game Title'),
      'EA Sports PGA Tour',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await settle(tester);

    expect(find.byType(AddCourseDialog), findsNothing);
    expect(popped, isNotNull);
    expect(popped!.name, 'Augusta');
    expect(popped!.gameTitle, 'EA Sports PGA Tour');

    final rows = await tester.runAsync(
      () => db.courseDao.watchAllByName().first,
    );
    expect(rows!.map((c) => c.name).toList(), ['Augusta']);
  });
}
