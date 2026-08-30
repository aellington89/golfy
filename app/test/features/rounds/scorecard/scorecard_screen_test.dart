import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/database.dart';
import 'package:golfy_app/data/database_provider.dart';
import 'package:golfy_app/features/rounds/active_round_provider.dart';
import 'package:golfy_app/features/rounds/scorecard/scorecard_screen.dart';
import 'package:golfy_app/shell/tab_index_provider.dart';

import '../../../dao/_fixtures.dart';

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

  // Tall + 1:1 pixel ratio so every (lazily-built) hole card lands in the
  // viewport for find.byKey, with no horizontal overflow on the stat row.
  void resizeTall(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  }

  Widget wrap(ProviderContainer container, int roundId) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: ScorecardScreen(roundId: roundId)),
    );
  }

  // Lets the drift round / hole streams deliver their first frames before we
  // settle — otherwise the loading spinner animates forever and times out.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
  }

  Future<int> seedRound() async {
    final cid = await fx.insertCourse(name: 'Augusta', gameTitle: 'PGA');
    return fx.insertRound(cid, date: '2026-05-25');
  }

  String textOfKey(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(ValueKey(key))).data!;

  testWidgets('renders the totals card and all 18 hole cards', (tester) async {
    final rid = await seedRound();
    for (var h = 1; h <= 18; h++) {
      await fx.upsertHole(rid, h);
    }
    final container = makeContainer();
    addTearDown(container.dispose);

    resizeTall(tester);
    await tester.pumpWidget(wrap(container, rid));
    await settle(tester);

    expect(find.byKey(const ValueKey('scorecard_totals')), findsOneWidget);
    for (var h = 1; h <= 18; h++) {
      expect(
        find.byKey(ValueKey('scorecard_hole_$h')),
        findsOneWidget,
        reason: 'hole $h card should be present',
      );
    }
    expect(find.text('Augusta'), findsOneWidget);
  });

  testWidgets('totals and per-hole score-to-par are correct', (tester) async {
    final rid = await seedRound();
    // Hole 1: par 4, bogey (+1), fairway hit, missed green, up & down made.
    await fx.upsertHole(rid, 1,
        par: 4,
        score: 5,
        putts: 1,
        fairwayHit: true,
        gir: false,
        upDownAttempt: true,
        upDownSuccess: true);
    // Hole 2: par 3, birdie (-1), no fairway (par 3), green hit.
    await fx.upsertHole(rid, 2,
        par: 3, score: 2, putts: 1, fairwayHit: null, gir: true);
    // Hole 3: par 5, par (E), fairway missed, green hit, up & down missed.
    await fx.upsertHole(rid, 3,
        par: 5,
        score: 5,
        putts: 3,
        fairwayHit: false,
        gir: true,
        upDownAttempt: true,
        upDownSuccess: false);

    final container = makeContainer();
    addTearDown(container.dispose);

    resizeTall(tester);
    await tester.pumpWidget(wrap(container, rid));
    await settle(tester);

    expect(textOfKey(tester, 'total_score'), '12'); // 5 + 2 + 5
    expect(textOfKey(tester, 'total_par'), '12'); // 4 + 3 + 5
    expect(textOfKey(tester, 'total_rel'), 'E'); // 12 - 12
    expect(textOfKey(tester, 'total_fairways'), '1/2'); // 1 hit of 2 non-par-3
    expect(textOfKey(tester, 'total_gir'), '2/3'); // greens 2 of 3 holes
    expect(textOfKey(tester, 'total_putts'), '5'); // 1 + 1 + 3
    expect(textOfKey(tester, 'total_updown'), '1/2'); // 1 made of 2 tries

    Finder inHole(int hole, String text) => find.descendant(
          of: find.byKey(ValueKey('scorecard_hole_$hole')),
          matching: find.text(text),
        );
    expect(inHole(1, '+1'), findsOneWidget);
    expect(inHole(2, '-1'), findsOneWidget);
    expect(inHole(2, 'N/A'), findsOneWidget); // par-3 fairway
    expect(inHole(3, 'E'), findsOneWidget);
  });

  testWidgets('par-3 hole shows N/A for fairway', (tester) async {
    final rid = await seedRound();
    await fx.upsertHole(rid, 1, par: 3, score: 3, fairwayHit: null);

    final container = makeContainer();
    addTearDown(container.dispose);

    resizeTall(tester);
    await tester.pumpWidget(wrap(container, rid));
    await settle(tester);

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('scorecard_hole_1')),
        matching: find.text('N/A'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('holes beyond those entered render as dashes', (tester) async {
    final rid = await seedRound();
    for (var h = 1; h <= 9; h++) {
      await fx.upsertHole(rid, h); // defaults: par 4 / score 4
    }
    final container = makeContainer();
    addTearDown(container.dispose);

    resizeTall(tester);
    await tester.pumpWidget(wrap(container, rid));
    await settle(tester);

    // Hole 18 was never entered → its card is full of em dashes.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('scorecard_hole_18')),
        matching: find.text('—'),
      ),
      findsWidgets,
    );
    // Totals cover only the 9 entered holes.
    expect(textOfKey(tester, 'total_score'), '36');
    expect(textOfKey(tester, 'total_rel'), 'E');
  });

  testWidgets('empty round renders dashes and does not crash', (tester) async {
    final rid = await seedRound();
    final container = makeContainer();
    addTearDown(container.dispose);

    resizeTall(tester);
    await tester.pumpWidget(wrap(container, rid));
    await settle(tester);

    expect(find.byKey(const ValueKey('scorecard_totals')), findsOneWidget);
    expect(textOfKey(tester, 'total_score'), '—');
    expect(textOfKey(tester, 'total_fairways'), '—');
    expect(textOfKey(tester, 'total_updown'), '—');
  });

  testWidgets('Edit sets the active round, switches tab, and pops',
      (tester) async {
    final rid = await seedRound();
    final container = makeContainer();
    addTearDown(container.dispose);

    resizeTall(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ScorecardScreen(roundId: rid),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await settle(tester);
    expect(find.byType(ScorecardScreen), findsOneWidget);
    expect(container.read(activeRoundIdProvider), isNull);
    expect(container.read(tabIndexProvider), 0);

    await tester.tap(find.byKey(const ValueKey('scorecard_edit_button')));
    await tester.pumpAndSettle();

    expect(container.read(activeRoundIdProvider), rid);
    expect(container.read(tabIndexProvider), ShellTabs.holeEntry);
    expect(find.byType(ScorecardScreen), findsNothing);
  });

  testWidgets(
      'Delete confirms, removes the round + holes, clears active id, and pops',
      (tester) async {
    final rid = await seedRound();
    for (var h = 1; h <= 3; h++) {
      await fx.upsertHole(rid, h);
    }
    final container = makeContainer();
    addTearDown(container.dispose);
    container.read(activeRoundIdProvider.notifier).set(rid);

    // Push the scorecard over a launcher so pop() has somewhere to land.
    resizeTall(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ScorecardScreen(roundId: rid),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await settle(tester);
    expect(find.byType(ScorecardScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('scorecard_delete_button')));
    await tester.pumpAndSettle();
    expect(find.text('Delete round?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    // Real async: let the in-memory delete + stream re-emit run before settling.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    // Popped back to the launcher; round + holes gone; active id cleared.
    expect(find.byType(ScorecardScreen), findsNothing);
    expect(container.read(activeRoundIdProvider), isNull);

    final rounds = await tester.runAsync(
      () => db.roundDao.watchAllWithCourse().first,
    );
    expect(rounds, isEmpty);
    final holes = await tester.runAsync(
      () => db.holeResultDao.countForRound(rid),
    );
    expect(holes, 0);
  });

  testWidgets('Delete cancel keeps the round and stays on the scorecard',
      (tester) async {
    final rid = await seedRound();
    final container = makeContainer();
    addTearDown(container.dispose);

    resizeTall(tester);
    await tester.pumpWidget(wrap(container, rid));
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('scorecard_delete_button')));
    await tester.pumpAndSettle();
    expect(find.text('Delete round?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(ScorecardScreen), findsOneWidget);
    final rounds = await tester.runAsync(
      () => db.roundDao.watchAllWithCourse().first,
    );
    expect(rounds, hasLength(1));
  });
}
