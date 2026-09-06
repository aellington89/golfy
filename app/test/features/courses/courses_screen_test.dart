import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/database.dart';
import 'package:golfy_app/data/database_provider.dart';
import 'package:golfy_app/data/models/round_with_course.dart';
import 'package:golfy_app/data/repository_provider.dart';
import 'package:golfy_app/features/courses/courses_screen.dart';

void main() {
  late GolfyDatabase db;
  late StreamController<List<Course>> coursesController;
  late StreamController<List<RoundWithCourse>> roundsController;

  setUp(() {
    db = GolfyDatabase.forTesting(NativeDatabase.memory());
    coursesController = StreamController<List<Course>>.broadcast();
    roundsController = StreamController<List<RoundWithCourse>>.broadcast();
  });

  tearDown(() async {
    await coursesController.close();
    await roundsController.close();
    await db.close();
  });

  Widget wrap() {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        coursesByNameStreamProvider
            .overrideWith((ref) => coursesController.stream),
        roundsStreamProvider.overrideWith((ref) => roundsController.stream),
      ],
      child: const MaterialApp(home: CoursesScreen()),
    );
  }

  Course makeCourse({int id = 1, String name = 'Pebble', String game = 'PGA'}) =>
      Course(id: id, name: name, gameTitle: game);

  RoundWithCourse makeRound({required int id, required int courseId}) =>
      RoundWithCourse(
        round: Round(
          id: id,
          date: '2026-05-25',
          courseId: courseId,
          roundNumber: 1,
        ),
        courseName: 'Pebble',
        event: null,
        holesEntered: 0,
        totalScore: 0,
        totalPar: 0,
      );

  Future<void> emit(
    WidgetTester tester, {
    List<Course> courses = const [],
    List<RoundWithCourse> rounds = const [],
  }) async {
    coursesController.add(courses);
    roundsController.add(rounds);
    await tester.pumpAndSettle();
  }

  testWidgets('empty state when there are no courses', (tester) async {
    await tester.pumpWidget(wrap());
    await emit(tester);

    expect(find.text('No courses yet. Tap + to add one.'), findsOneWidget);
  });

  testWidgets('lists a course with its game title and round count',
      (tester) async {
    await tester.pumpWidget(wrap());
    await emit(
      tester,
      courses: [makeCourse(id: 7, name: 'Augusta', game: 'PGA 2K25')],
      rounds: [
        makeRound(id: 1, courseId: 7),
        makeRound(id: 2, courseId: 7),
      ],
    );

    expect(find.text('Augusta'), findsOneWidget);
    expect(find.text('PGA 2K25 · 2 rounds'), findsOneWidget);
  });

  testWidgets('a course with no rounds reads "No rounds yet"', (tester) async {
    await tester.pumpWidget(wrap());
    await emit(tester, courses: [makeCourse(id: 3, name: 'Bandon')]);

    expect(find.text('PGA · No rounds yet'), findsOneWidget);
  });

  testWidgets('the FAB opens the Add Course dialog', (tester) async {
    await tester.pumpWidget(wrap());
    await emit(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Add Course'), findsOneWidget);
  });
}
