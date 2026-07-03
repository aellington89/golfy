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
import 'package:golfy_app/features/rounds/edit_round_dialog.dart';

void main() {
  late GolfyDatabase db;
  late StreamController<List<Course>> coursesController;

  setUp(() {
    db = GolfyDatabase.forTesting(NativeDatabase.memory());
    coursesController = StreamController<List<Course>>.broadcast();
  });

  tearDown(() async {
    await coursesController.close();
    await db.close();
  });

  // Builds a RoundWithCourse to feed the dialog. Mirrors the row model the
  // rounds list passes in; hand-built so the test controls every field.
  RoundWithCourse makeRound({
    required int id,
    int courseId = 1,
    String courseName = 'Augusta',
    String date = '2026-04-01',
    int roundNumber = 1,
    String? notes,
    Event? event,
  }) {
    return RoundWithCourse(
      round: Round(
        id: id,
        date: date,
        courseId: courseId,
        roundNumber: roundNumber,
        notes: notes,
        eventId: event?.id,
      ),
      courseName: courseName,
      event: event,
      holesEntered: 0,
      totalScore: 0,
      totalPar: 0,
    );
  }

  Event makeEvent({int id = 1, String name = 'Club Championship'}) =>
      Event(id: id, name: name, tied: false, missedCut: false);

  Widget wrap({
    required RoundWithCourse round,
    List<RoundWithCourse> existingRounds = const [],
    List<Event> existingEvents = const [],
    List<Course> existingCourses = const [],
  }) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        coursesByNameStreamProvider
            .overrideWith((ref) => coursesController.stream),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => EditRoundDialog(
                      round: round,
                      existingRounds: existingRounds,
                      existingEvents: existingEvents,
                      existingCourses: existingCourses,
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> openDialog(
    WidgetTester tester, {
    required RoundWithCourse round,
    List<RoundWithCourse> existingRounds = const [],
    List<Event> existingEvents = const [],
    List<Course> existingCourses = const [],
  }) async {
    await tester.pumpWidget(wrap(
      round: round,
      existingRounds: existingRounds,
      existingEvents: existingEvents,
      existingCourses: existingCourses,
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    // Feed the course picker's stream (its initial value comes from
    // existingCourses, but emit so the picker isn't stuck loading).
    coursesController.add(existingCourses);
    await tester.pumpAndSettle();
  }

  // Flushes the real async write against the in-memory db before pumping.
  Future<void> flush(WidgetTester tester) async {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('pre-fills fields from the round', (tester) async {
    const course = Course(id: 1, name: 'Augusta', gameTitle: 'PGA');
    final event = makeEvent(id: 7, name: 'Club Championship');
    final round = makeRound(
      id: 1,
      roundNumber: 3,
      notes: 'breezy',
      event: event,
    );

    await openDialog(
      tester,
      round: round,
      existingCourses: const [course],
      existingEvents: [event],
    );

    // Course name in the picker, event name in the typeahead, the round's
    // number in the stepper, and its notes in the notes field.
    expect(find.text('Augusta'), findsOneWidget);
    expect(find.text('Club Championship'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('breezy'), findsOneWidget);
  });

  testWidgets('attaching a new event to a casual round links and creates it',
      (tester) async {
    const course = Course(id: 1, name: 'Augusta', gameTitle: 'PGA');
    // Course first — the round's courseId FK needs it to exist.
    await db.courseDao.insert(
      CoursesCompanion.insert(name: 'Augusta', gameTitle: 'PGA'),
    );
    final rid = await db.roundDao.insert(
      RoundsCompanion.insert(date: '2026-04-01', courseId: 1),
    );
    final round = makeRound(id: rid);

    await openDialog(tester, round: round, existingCourses: const [course]);

    await tester.enterText(
      find.byKey(const ValueKey('event_field')),
      'Club Championship',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('edit_round_save')));
    await flush(tester);

    expect(find.byType(EditRoundDialog), findsNothing);

    final events = await tester.runAsync(() => db.eventDao.watchAll().first);
    expect(events!.map((e) => e.name), contains('Club Championship'));

    final row = await tester.runAsync(() => db.roundDao.getById(rid));
    expect(row!.eventId, isNotNull);
  });

  testWidgets('selecting an existing event reuses it without a duplicate',
      (tester) async {
    const course = Course(id: 1, name: 'Augusta', gameTitle: 'PGA');
    await db.courseDao.insert(
      CoursesCompanion.insert(name: 'Augusta', gameTitle: 'PGA'),
    );
    final eid = await db.eventDao.insert(
      EventsCompanion.insert(name: 'Club Championship'),
    );
    final rid = await db.roundDao.insert(
      RoundsCompanion.insert(date: '2026-04-01', courseId: 1),
    );
    final event = makeEvent(id: eid, name: 'Club Championship');
    final round = makeRound(id: rid);

    await openDialog(
      tester,
      round: round,
      existingCourses: const [course],
      existingEvents: [event],
    );

    // Type a prefix, then pick the suggestion from the typeahead overlay.
    await tester.enterText(
      find.byKey(const ValueKey('event_field')),
      'Club',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Club Championship').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('edit_round_save')));
    await flush(tester);

    // No second event created — the existing one was reused.
    final events = await tester.runAsync(() => db.eventDao.watchAll().first);
    expect(events, hasLength(1));

    final row = await tester.runAsync(() => db.roundDao.getById(rid));
    expect(row!.eventId, eid);
  });

  testWidgets('clearing the event field detaches the round', (tester) async {
    const course = Course(id: 1, name: 'Augusta', gameTitle: 'PGA');
    await db.courseDao.insert(
      CoursesCompanion.insert(name: 'Augusta', gameTitle: 'PGA'),
    );
    final eid = await db.eventDao.insert(
      EventsCompanion.insert(name: 'Club Championship'),
    );
    final rid = await db.roundDao.insert(
      RoundsCompanion.insert(
        date: '2026-04-01',
        courseId: 1,
        eventId: Value(eid),
      ),
    );
    final event = makeEvent(id: eid, name: 'Club Championship');
    final round = makeRound(id: rid, event: event);

    await openDialog(
      tester,
      round: round,
      existingCourses: const [course],
      existingEvents: [event],
    );

    // Field starts pre-filled with the event name; clear it to detach.
    await tester.enterText(find.byKey(const ValueKey('event_field')), '');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('edit_round_save')));
    await flush(tester);

    final row = await tester.runAsync(() => db.roundDao.getById(rid));
    expect(row!.eventId, isNull);
  });

  testWidgets(
      'editing into an existing (date, course, round#) shows an inline error',
      (tester) async {
    const course = Course(id: 1, name: 'Augusta', gameTitle: 'PGA');
    await db.courseDao.insert(
      CoursesCompanion.insert(name: 'Augusta', gameTitle: 'PGA'),
    );
    final r1 = await db.roundDao.insert(RoundsCompanion.insert(
        date: '2026-04-01', courseId: 1, roundNumber: const Value(1)));
    final r2 = await db.roundDao.insert(RoundsCompanion.insert(
        date: '2026-04-01', courseId: 1, roundNumber: const Value(2)));
    final existing = [
      makeRound(id: r1, roundNumber: 1),
      makeRound(id: r2, roundNumber: 2),
    ];

    // Editing r2, decrement its number to 1 to collide with r1.
    await openDialog(
      tester,
      round: existing[1],
      existingRounds: existing,
      existingCourses: const [course],
    );

    await tester.tap(find.byKey(const ValueKey('round_number_dec')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('edit_round_save')));
    await tester.pumpAndSettle();

    expect(find.textContaining('already exists'), findsOneWidget);
    expect(find.byType(EditRoundDialog), findsOneWidget);

    // r2 is untouched in the db (still round number 2).
    final row = await tester.runAsync(() => db.roundDao.getById(r2));
    expect(row!.roundNumber, 2);
  });

  testWidgets('editing notes persists', (tester) async {
    const course = Course(id: 1, name: 'Augusta', gameTitle: 'PGA');
    await db.courseDao.insert(
      CoursesCompanion.insert(name: 'Augusta', gameTitle: 'PGA'),
    );
    final rid = await db.roundDao.insert(
      RoundsCompanion.insert(date: '2026-04-01', courseId: 1),
    );
    final round = makeRound(id: rid);

    await openDialog(tester, round: round, existingCourses: const [course]);

    // The notes field is the last TextFormField (the event typeahead is first).
    await tester.enterText(
      find.byType(TextFormField).last,
      'gusty back nine',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('edit_round_save')));
    await flush(tester);

    final row = await tester.runAsync(() => db.roundDao.getById(rid));
    expect(row!.notes, 'gusty back nine');
  });
}
