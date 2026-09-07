import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/database.dart';
import 'package:golfy_app/data/database_provider.dart';
import 'package:golfy_app/features/hole_entry/hole_entry_screen.dart';
import 'package:golfy_app/features/rounds/active_round_provider.dart';
import 'package:golfy_app/shell/tab_index_provider.dart';

import '../../dao/_fixtures.dart';

void main() {
  late GolfyDatabase db;
  late TestFixtures fx;

  setUp(() {
    db = GolfyDatabase.forTesting(NativeDatabase.memory());
    fx = TestFixtures(db);
  });

  tearDown(() async {
    await db.close();
  });

  void resizeForForm(WidgetTester tester) {
    // Default 800x600 is shorter than the form card. Resize so the Save
    // button and all switches land on-screen.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget wrap(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: HoleEntryScreen()),
    );
  }

  ProviderContainer makeContainer({int? activeRoundId}) {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    if (activeRoundId != null) {
      container.read(activeRoundIdProvider.notifier).set(activeRoundId);
    }
    return container;
  }

  Future<({int courseId, int roundId})> seedRound() async {
    final cid = await fx.insertCourse(name: 'Augusta', gameTitle: 'PGA');
    final rid = await fx.insertRound(cid, date: '2026-05-25');
    return (courseId: cid, roundId: rid);
  }

  testWidgets('with no active round, shows the empty state', (tester) async {
    final container = makeContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(wrap(container));
    await tester.pumpAndSettle();

    expect(
      find.text('No active round. Go to Rounds to start one.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Go to Rounds'), findsOneWidget);
  });

  testWidgets(
      'Go to Rounds button switches the shell back to the Rounds tab',
      (tester) async {
    final container = makeContainer();
    addTearDown(container.dispose);
    // Pretend the user is currently on the Hole Entry tab.
    container.read(tabIndexProvider.notifier).set(ShellTabs.holeEntry);

    await tester.pumpWidget(wrap(container));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Go to Rounds'));
    await tester.pump();

    expect(container.read(tabIndexProvider), ShellTabs.rounds);
  });

  testWidgets(
      'active round with 0 saved holes: progress reads 0/18 and no Finish FAB',
      (tester) async {
    final seed = await seedRound();
    final container = makeContainer(activeRoundId: seed.roundId);
    addTearDown(container.dispose);

    resizeForForm(tester);
    await tester.pumpWidget(wrap(container));
    // Wait for the round / hole streams to deliver their first frames.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(find.text('Augusta'), findsOneWidget);
    expect(find.text('Holes saved: 0 / 18'), findsOneWidget);
    expect(find.byKey(const ValueKey('finish_round')), findsNothing);
  });

  testWidgets(
      're-opening a complete round shows a "Done" FAB that resets the shell',
      (tester) async {
    final seed = await seedRound();
    for (var h = 1; h <= 18; h++) {
      await fx.upsertHole(seed.roundId, h);
    }

    final container = makeContainer(activeRoundId: seed.roundId);
    addTearDown(container.dispose);

    await tester.pumpWidget(wrap(container));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(find.text('Holes saved: 18 / 18'), findsOneWidget);
    expect(find.byKey(const ValueKey('finish_round')), findsOneWidget);
    // The round arrived already complete (the edit flow), so the FAB reads
    // "Done" rather than "Finish Round".
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Finish Round'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('finish_round')));
    await tester.pumpAndSettle();

    expect(container.read(activeRoundIdProvider), isNull);
    expect(container.read(tabIndexProvider), ShellTabs.rounds);
  });

  testWidgets(
      'saving a hole writes the row and increments the progress counter',
      (tester) async {
    final seed = await seedRound();
    final container = makeContainer(activeRoundId: seed.roundId);
    addTearDown(container.dispose);

    resizeForForm(tester);
    await tester.pumpWidget(wrap(container));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(find.text('Holes saved: 0 / 18'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Save Hole'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(find.text('Holes saved: 1 / 18'), findsOneWidget);

    final rows = await tester
        .runAsync(() => db.holeResultDao.watchForRound(seed.roundId).first);
    expect(rows, hasLength(1));
    expect(rows!.single.holeNumber, 1);
  });

  testWidgets(
      'tapping a hole chip in the nav bar advances the PageView to that hole',
      (tester) async {
    final seed = await seedRound();
    final container = makeContainer(activeRoundId: seed.roundId);
    addTearDown(container.dispose);

    resizeForForm(tester);
    await tester.pumpWidget(wrap(container));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    // Initial page is hole 1 — its card carries a known key.
    expect(find.byKey(const ValueKey('hole_card_1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('hole_chip_5')));
    await tester.pumpAndSettle();

    // PageView's keepAlive can leave hole_card_1 in the tree but no longer
    // visible; assert hole 5's card is now built and on-screen instead.
    expect(find.byKey(const ValueKey('hole_card_5')), findsOneWidget);
    expect(
      tester.getCenter(find.byKey(const ValueKey('hole_card_5'))).dx,
      closeTo(400, 50),
    );
  });

  testWidgets('saving the same hole twice keeps a single row (upsert)',
      (tester) async {
    final seed = await seedRound();
    final container = makeContainer(activeRoundId: seed.roundId);
    addTearDown(container.dispose);

    resizeForForm(tester);
    await tester.pumpWidget(wrap(container));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    // Save once with default score.
    await tester.tap(find.widgetWithText(FilledButton, 'Save Hole'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    // Bump score, save again.
    await tester.tap(find.byKey(const ValueKey('Score_inc')));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save Hole'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    final rows = await tester
        .runAsync(() => db.holeResultDao.watchForRound(seed.roundId).first);
    expect(rows, hasLength(1));
    expect(rows!.single.score, 5);
    expect(find.text('Holes saved: 1 / 18'), findsOneWidget);
  });

  testWidgets(
      'editing a saved round pre-fills its cards with the persisted values',
      (tester) async {
    final seed = await seedRound();
    // Distinctive, non-default values so a pre-filled card is unmistakable.
    await fx.upsertHole(seed.roundId, 1,
        par: 5, score: 6, putts: 3, gir: true, fairwayHit: false);
    await fx.upsertHole(seed.roundId, 2,
        par: 3, score: 2, putts: 1, fairwayHit: null);

    final container = makeContainer(activeRoundId: seed.roundId);
    addTearDown(container.dispose);

    resizeForForm(tester);
    await tester.pumpWidget(wrap(container));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    // Hole 1's card shows its saved score (6) and putts (3), tagged "Saved".
    expect(
      find.descendant(
        of: find.descendant(
          of: find.byKey(const ValueKey('hole_card_1')),
          matching: find.byKey(const ValueKey('score')),
        ),
        matching: find.text('6'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.descendant(
          of: find.byKey(const ValueKey('hole_card_1')),
          matching: find.byKey(const ValueKey('putts')),
        ),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('hole_card_1')),
        matching: find.text('Saved'),
      ),
      findsOneWidget,
    );

    // A second card pre-fills too — jump to hole 2 and check its score (2).
    await tester.tap(find.byKey(const ValueKey('hole_chip_2')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.descendant(
          of: find.byKey(const ValueKey('hole_card_2')),
          matching: find.byKey(const ValueKey('score')),
        ),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'editing a pre-saved hole upserts the same row with the new value',
      (tester) async {
    final seed = await seedRound();
    final savedId = await fx.upsertHole(seed.roundId, 1, score: 5);

    final container = makeContainer(activeRoundId: seed.roundId);
    addTearDown(container.dispose);

    resizeForForm(tester);
    await tester.pumpWidget(wrap(container));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    // Pre-filled to the saved score and marked "Saved".
    expect(
      find.descendant(
        of: find.descendant(
          of: find.byKey(const ValueKey('hole_card_1')),
          matching: find.byKey(const ValueKey('score')),
        ),
        matching: find.text('5'),
      ),
      findsOneWidget,
    );
    expect(find.text('Saved'), findsOneWidget);

    // Bump the score; the card flips to "Unsaved" until saved again.
    await tester.tap(find.byKey(const ValueKey('Score_inc')));
    await tester.pump();
    expect(find.text('Unsaved'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Save Hole'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    // The same row was updated in place (id preserved) — not duplicated.
    final rows = await tester
        .runAsync(() => db.holeResultDao.watchForRound(seed.roundId).first);
    expect(rows, hasLength(1));
    expect(rows!.single.id, savedId);
    expect(rows.single.score, 6);

    // Counter stays at 1 and the card is "Saved" again.
    expect(find.text('Holes saved: 1 / 18'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets(
      'pre-fills an untouched hole: par from the course, yards from the '
      "round's set (#36)", (tester) async {
    final cid = await fx.insertCourse(name: 'Augusta', gameTitle: 'PGA');
    // Distinctive values (default is par 4) so the auto-fill is unmistakable:
    // par from the shared course card, yards from the round's chosen set.
    await fx.insertCourseHoles(cid, par: 5);
    final setId = await fx.insertCourseSet(cid, name: 'Blue');
    await fx.insertCourseSetYards(setId, yards: 540);
    final rid = await fx.insertRound(cid, date: '2026-05-25', courseSetId: setId);

    final container = makeContainer(activeRoundId: rid);
    addTearDown(container.dispose);

    resizeForForm(tester);
    await tester.pumpWidget(wrap(container));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    // Hole 1's par control is pre-selected to 5 and its yards field shows 540.
    final parButton = tester.widget<SegmentedButton<int>>(
      find
          .descendant(
            of: find.byKey(const ValueKey('hole_card_1')),
            matching: find.byType(SegmentedButton<int>),
          )
          .first,
    );
    expect(parButton.selected, {5});

    final yards = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('hole_card_1')),
        matching: find.byKey(const ValueKey('yards')),
      ),
    );
    expect(yards.controller!.text, '540');

    // Saving the untouched hole persists the auto-filled par/yards.
    await tester.tap(find.widgetWithText(FilledButton, 'Save Hole'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    final rows = await tester
        .runAsync(() => db.holeResultDao.watchForRound(rid).first);
    expect(rows!.single.par, 5);
    expect(rows.single.yards, 540);
  });

  testWidgets(
      'a course with no template falls back to defaults (par 4, blank yards)',
      (tester) async {
    final seed = await seedRound(); // no course_holes inserted

    final container = makeContainer(activeRoundId: seed.roundId);
    addTearDown(container.dispose);

    resizeForForm(tester);
    await tester.pumpWidget(wrap(container));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    final parButton = tester.widget<SegmentedButton<int>>(
      find
          .descendant(
            of: find.byKey(const ValueKey('hole_card_1')),
            matching: find.byType(SegmentedButton<int>),
          )
          .first,
    );
    expect(parButton.selected, {4});

    final yards = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('hole_card_1')),
        matching: find.byKey(const ValueKey('yards')),
      ),
    );
    expect(yards.controller!.text, '');
  });

  testWidgets(
      'completing the final hole during entry shows a "Finish Round" FAB',
      (tester) async {
    final seed = await seedRound();
    // Holes 2..18 saved before mount (17 total); hole 1 — shown first — is the
    // one still missing, so the round is not complete on entry.
    for (var h = 2; h <= 18; h++) {
      await fx.upsertHole(seed.roundId, h);
    }

    final container = makeContainer(activeRoundId: seed.roundId);
    addTearDown(container.dispose);

    resizeForForm(tester);
    await tester.pumpWidget(wrap(container));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(find.text('Holes saved: 17 / 18'), findsOneWidget);
    expect(find.byKey(const ValueKey('finish_round')), findsNothing);

    // Saving the missing hole 1 (shown by default) reaches 18/18 in-session,
    // so the FAB must read "Finish Round" — not "Done".
    await tester.tap(find.widgetWithText(FilledButton, 'Save Hole'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(find.text('Holes saved: 18 / 18'), findsOneWidget);
    expect(find.byKey(const ValueKey('finish_round')), findsOneWidget);
    expect(find.text('Finish Round'), findsOneWidget);
    expect(find.text('Done'), findsNothing);
  });
}
