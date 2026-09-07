import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/database.dart';
import 'package:golfy_app/data/database_provider.dart';
import 'package:golfy_app/features/courses/edit_course_dialog.dart';

void main() {
  late GolfyDatabase db;

  setUp(() {
    db = GolfyDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget wrap({
    required Course course,
    List<Course> existing = const [],
    void Function(Course?)? onResult,
  }) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  final result = await showDialog<Course>(
                    context: context,
                    builder: (_) => EditCourseDialog(
                      course: course,
                      existingCourses: existing,
                    ),
                  );
                  if (onResult != null) onResult(result);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Bounded pump — focused TextFormFields keep cursor-blink animations running
  // indefinitely, so pumpAndSettle would hang.
  Future<void> settle(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 400));

  Future<void> openDialog(
    WidgetTester tester, {
    required Course course,
    List<Course> existing = const [],
    void Function(Course?)? onResult,
  }) async {
    await tester
        .pumpWidget(wrap(course: course, existing: existing, onResult: onResult));
    await tester.tap(find.text('Open'));
    await settle(tester);
  }

  testWidgets('renaming persists the change and pops the updated Course',
      (tester) async {
    final id = await db.courseDao.insert(
      CoursesCompanion.insert(name: 'Pebbel', gameTitle: 'PGA Tour 2K25'),
    );
    final course =
        Course(id: id, name: 'Pebbel', gameTitle: 'PGA Tour 2K25');

    Course? popped;
    await openDialog(tester, course: course, onResult: (c) => popped = c);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Course Name'),
      'Pebble Beach',
    );
    await tester.tap(find.byKey(const ValueKey('edit_course_save')));
    await settle(tester);

    expect(find.byType(EditCourseDialog), findsNothing);
    expect(popped?.name, 'Pebble Beach');

    final row = await tester
        .runAsync(() => db.courseDao.watchAllByName().first)
        .then((rows) => rows!.single);
    expect(row.name, 'Pebble Beach');
    expect(row.gameTitle, 'PGA Tour 2K25');
  });

  testWidgets('a duplicate (name, gameTitle) shows an error and does not save',
      (tester) async {
    final keepId = await db.courseDao.insert(
      CoursesCompanion.insert(name: 'Augusta', gameTitle: 'PGA'),
    );
    final editId = await db.courseDao.insert(
      CoursesCompanion.insert(name: 'Pebble', gameTitle: 'PGA'),
    );
    final existing = [
      Course(id: keepId, name: 'Augusta', gameTitle: 'PGA'),
      Course(id: editId, name: 'Pebble', gameTitle: 'PGA'),
    ];

    await openDialog(
      tester,
      course: existing[1],
      existing: existing,
    );

    // Rename "Pebble" to the already-taken "Augusta" (same game title).
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Course Name'),
      'Augusta',
    );
    await tester.tap(find.byKey(const ValueKey('edit_course_save')));
    await settle(tester);

    expect(find.text('Course already exists'), findsOneWidget);
    expect(find.byType(EditCourseDialog), findsOneWidget);

    // The edited course is unchanged in the db.
    final row = await tester
        .runAsync(() => db.courseDao.watchAllByName().first)
        .then((rows) => rows!.firstWhere((c) => c.id == editId));
    expect(row.name, 'Pebble');
  });
}
