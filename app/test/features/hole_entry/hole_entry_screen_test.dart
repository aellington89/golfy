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

    expect(find.text('No active round'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Go to Rounds'), findsOneWidget);
  });

  testWidgets(
      'Go to Rounds button switches the shell back to the Rounds tab',
      (tester) async {
    final container = makeContainer();
    addTearDown(container.dispose);
    // Pretend the user is currently on the Hole Entry tab.
    container.read(tabIndexProvider.notifier).set(1);

    await tester.pumpWidget(wrap(container));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Go to Rounds'));
    await tester.pump();

    expect(container.read(tabIndexProvider), 0);
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
      'after all 18 holes are saved, Finish FAB appears and resets the shell',
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

    await tester.tap(find.byKey(const ValueKey('finish_round')));
    await tester.pumpAndSettle();

    expect(container.read(activeRoundIdProvider), isNull);
    expect(container.read(tabIndexProvider), 0);
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
}
