import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/database.dart';
import 'package:golfy_app/data/database_provider.dart';
import 'package:golfy_app/data/models/round_with_course.dart';
import 'package:golfy_app/data/repository_provider.dart';
import 'package:golfy_app/features/rounds/active_round_provider.dart';
import 'package:golfy_app/features/rounds/new_round_dialog.dart';
import 'package:golfy_app/features/rounds/rounds_screen.dart';
import 'package:golfy_app/shell/tab_index_provider.dart';

void main() {
  late GolfyDatabase db;
  late StreamController<List<RoundWithCourse>> roundsController;
  late StreamController<List<Course>> coursesController;

  setUp(() {
    db = GolfyDatabase.forTesting(NativeDatabase.memory());
    roundsController = StreamController<List<RoundWithCourse>>.broadcast();
    coursesController = StreamController<List<Course>>.broadcast();
  });

  tearDown(() async {
    await roundsController.close();
    await coursesController.close();
    await db.close();
  });

  Widget wrap() {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        roundsStreamProvider
            .overrideWith((ref) => roundsController.stream),
        coursesByNameStreamProvider
            .overrideWith((ref) => coursesController.stream),
      ],
      child: const MaterialApp(home: RoundsScreen()),
    );
  }

  // pumpAndSettle is safe here: this screen has no autofocused
  // TextFormField, so there's no cursor-blink timer to keep frames pending.
  Future<void> emitRounds(
    WidgetTester tester,
    List<RoundWithCourse> rounds,
  ) async {
    roundsController.add(rounds);
    await tester.pumpAndSettle();
  }

  Future<void> emitCourses(
    WidgetTester tester,
    List<Course> courses,
  ) async {
    coursesController.add(courses);
    await tester.pumpAndSettle();
  }

  RoundWithCourse makeRound({
    int id = 1,
    int courseId = 1,
    String courseName = 'Pebble',
    String date = '2026-05-25',
    int roundNumber = 1,
    int holesEntered = 0,
  }) {
    return RoundWithCourse(
      round: Round(
        id: id,
        date: date,
        courseId: courseId,
        roundNumber: roundNumber,
      ),
      courseName: courseName,
      holesEntered: holesEntered,
    );
  }

  testWidgets('empty state copy renders when there are no rounds',
      (tester) async {
    await tester.pumpWidget(wrap());
    await emitRounds(tester, const []);

    expect(
      find.text('No rounds yet. Tap + to start your first round.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'row shows course name with round number, formatted date, and X/18',
      (tester) async {
    await tester.pumpWidget(wrap());
    await emitRounds(tester, [
      makeRound(date: '2026-05-25', roundNumber: 2, holesEntered: 12),
    ]);

    expect(find.text('Pebble — Round 2'), findsOneWidget);
    expect(find.text('May 25, 2026'), findsOneWidget);
    expect(find.text('12/18'), findsOneWidget);
  });

  testWidgets('FAB opens the New Round dialog', (tester) async {
    await tester.pumpWidget(wrap());
    await emitRounds(tester, const []);
    await emitCourses(tester, const []);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.byType(NewRoundDialog), findsOneWidget);
  });

  testWidgets(
      'swipe-to-delete with confirm removes the round and clears active id',
      (tester) async {
    await db.courseDao.insert(
      CoursesCompanion.insert(name: 'Pebble', gameTitle: 'PGA'),
    );
    final rid = await db.roundDao.insert(
      RoundsCompanion.insert(
        date: '2026-05-25',
        courseId: 1,
        roundNumber: const Value(1),
      ),
    );

    await tester.pumpWidget(wrap());
    await emitRounds(tester, [makeRound(id: rid, holesEntered: 0)]);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(RoundsScreen)),
    );
    container.read(activeRoundIdProvider.notifier).set(rid);
    expect(container.read(activeRoundIdProvider), rid);

    await tester.drag(
      find.textContaining('Pebble'),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Delete round?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    await emitRounds(tester, const []);

    expect(find.textContaining('Pebble'), findsNothing);
    expect(container.read(activeRoundIdProvider), isNull);

    final rounds = await tester.runAsync(
      () => db.roundDao.watchAllWithCourse().first,
    );
    expect(rounds, isEmpty);
  });

  testWidgets(
      'tapping a round row sets activeRoundId and switches to Hole Entry tab',
      (tester) async {
    await tester.pumpWidget(wrap());
    await emitRounds(tester, [makeRound(id: 42, courseName: 'Pebble')]);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(RoundsScreen)),
    );
    expect(container.read(activeRoundIdProvider), isNull);
    expect(container.read(tabIndexProvider), 0);

    await tester.tap(find.textContaining('Pebble'));
    await tester.pump();

    expect(container.read(activeRoundIdProvider), 42);
    expect(container.read(tabIndexProvider), 1);
  });

  testWidgets('swipe-to-delete with cancel keeps the row', (tester) async {
    await tester.pumpWidget(wrap());
    await emitRounds(tester, [makeRound()]);

    await tester.drag(
      find.textContaining('Pebble'),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Delete round?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Pebble'), findsOneWidget);
  });
}
