import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/database.dart';
import 'package:golfy_app/data/database_provider.dart';
import 'package:golfy_app/data/repository_provider.dart';
import 'package:golfy_app/features/courses/add_course_dialog.dart';
import 'package:golfy_app/features/courses/course_picker.dart';

void main() {
  late GolfyDatabase db;
  // Stream backing [coursesByNameStreamProvider] in tests. Using a manual
  // controller (instead of drift's stream) keeps flutter_test's fake clock
  // happy — drift's stream leaves a pending timer that fails the
  // !timersPending invariant.
  late StreamController<List<Course>> coursesController;

  setUp(() {
    db = GolfyDatabase.forTesting(NativeDatabase.memory());
    coursesController = StreamController<List<Course>>.broadcast();
  });

  tearDown(() async {
    await coursesController.close();
    await db.close();
  });

  Widget wrap() {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        coursesByNameStreamProvider
            .overrideWith((ref) => coursesController.stream),
      ],
      child: const MaterialApp(home: _Holder()),
    );
  }

  Future<void> emit(WidgetTester tester, List<Course> courses) async {
    coursesController.add(courses);
    await tester.pump();
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 400));

  testWidgets('opens sheet and lists courses sorted alphabetically by name',
      (tester) async {
    await tester.pumpWidget(wrap());
    await emit(tester, const [
      Course(id: 1, name: 'Augusta', gameTitle: 'PGA Tour 2K25'),
      Course(id: 2, name: 'Bandon', gameTitle: 'EA Sports PGA Tour'),
      Course(id: 3, name: 'Pebble', gameTitle: 'EA Sports PGA Tour'),
    ]);

    await tester.tap(find.byType(InkWell).first);
    await settle(tester);

    final tiles = find.byType(ListTile);
    expect(tiles, findsNWidgets(4)); // 3 courses + "Add new course…"

    final names = tester
        .widgetList<ListTile>(tiles)
        .take(3)
        .map((t) => (t.title as Text).data)
        .toList();
    expect(names, ['Augusta', 'Bandon', 'Pebble']);
  });

  testWidgets('reactively reflects new courses inserted while mounted',
      (tester) async {
    await tester.pumpWidget(wrap());
    await emit(tester, const []);

    await tester.tap(find.byType(InkWell).first);
    await settle(tester);
    expect(find.text('St Andrews'), findsNothing);

    // Close the sheet, emit a new list, reopen.
    Navigator.of(tester.element(find.text('Add new course…'))).pop();
    await settle(tester);

    await emit(tester, const [
      Course(id: 1, name: 'St Andrews', gameTitle: 'EA Sports PGA Tour'),
    ]);

    await tester.tap(find.byType(InkWell).first);
    await settle(tester);
    expect(find.text('St Andrews'), findsOneWidget);
  });

  testWidgets(
      'selecting "+ Add new course…" opens dialog and selects the new course',
      (tester) async {
    await tester.pumpWidget(wrap());
    await emit(tester, const []);

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, 'Add new course…'));
    await tester.pumpAndSettle();

    expect(find.byType(AddCourseDialog), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Course Name'),
      'Torrey Pines',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Game Title'),
      'PGA Tour 2K25',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    // The insert future runs as real async; flush it before pumping frames.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await settle(tester);
    await settle(tester);

    expect(find.byType(AddCourseDialog), findsNothing);
    // Picker label now shows the newly-added course as the selected value.
    expect(find.text('Torrey Pines'), findsOneWidget);

    // Course landed in the real db too.
    final rows = await tester.runAsync(
      () => db.courseDao.watchAllByName().first,
    );
    expect(rows!.map((c) => c.name).toList(), ['Torrey Pines']);
  });
}

class _Holder extends StatefulWidget {
  const _Holder();

  @override
  State<_Holder> createState() => _HolderState();
}

class _HolderState extends State<_Holder> {
  Course? _selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: CoursePicker(
          value: _selected,
          onChanged: (c) => setState(() => _selected = c),
        ),
      ),
    );
  }
}
