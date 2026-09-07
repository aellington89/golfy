import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/database.dart';
import 'package:golfy_app/data/database_provider.dart';
import 'package:golfy_app/data/repository_provider.dart';
import 'package:golfy_app/features/courses/course_set_yards_screen.dart';

void main() {
  const setId = 1;

  late GolfyDatabase db;

  setUp(() {
    db = GolfyDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  List<CourseSetYard> uniformYards({int yards = 420}) => [
        for (var h = 1; h <= 18; h++)
          CourseSetYard(
            id: h,
            courseSetId: setId,
            holeNumber: h,
            yards: yards,
          ),
      ];

  Future<void> pump(
    WidgetTester tester, {
    List<CourseSetYard>? yards,
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        courseSetYardsStreamProvider
            .overrideWith((ref, id) => Stream.value(yards ?? uniformYards())),
      ],
      child: const MaterialApp(
        home: CourseSetYardsScreen(setId: setId, setName: 'Blue tees'),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('seeds the first hole yardage', (tester) async {
    await pump(tester, yards: uniformYards(yards: 505));

    final field = tester.widget<TextFormField>(
      find.byKey(const ValueKey('set_yards_1')),
    );
    expect(field.initialValue, '505');
  });

  testWidgets('Save writes the full 18-hole yardage card to the database',
      (tester) async {
    // course_set_yards.course_set_id is a real FK — seed the course + set.
    final cid = await db.courseDao
        .insert(CoursesCompanion.insert(name: 'Augusta', gameTitle: 'PGA'));
    await db.courseSetDao
        .insertSet(CourseSetsCompanion.insert(courseId: cid, name: 'Blue'));

    await pump(tester, yards: uniformYards(yards: 410));

    await tester.enterText(find.byKey(const ValueKey('set_yards_1')), '432');
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('save_set_yards')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    final saved =
        await tester.runAsync(() => db.courseSetDao.getYardsForSet(setId));
    expect(saved, hasLength(18));
    expect(saved!.firstWhere((y) => y.holeNumber == 1).yards, 432);
    expect(saved.firstWhere((y) => y.holeNumber == 2).yards, 410);
  });
}
