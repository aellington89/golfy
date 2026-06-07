import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/database.dart';
import 'package:golfy_app/data/database_provider.dart';
import 'package:golfy_app/features/dashboard/dashboard_screen.dart';

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

  // Tall + 1:1 pixel ratio so every section card lands in the viewport for
  // find.byKey, with no horizontal overflow on the stat / bar rows.
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

  Widget wrap(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: DashboardScreen()),
    );
  }

  // Lets the drift stats stream deliver its first frame before we settle —
  // otherwise the loading spinner animates forever and times out.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
  }

  String textOfKey(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(ValueKey(key))).data!;

  Future<int> seedRound() async {
    final cid = await fx.insertCourse(name: 'Augusta', gameTitle: 'PGA');
    return fx.insertRound(cid, date: '2026-05-25');
  }

  testWidgets('empty database shows the play-a-round copy and no stats',
      (tester) async {
    final container = makeContainer();
    addTearDown(container.dispose);

    resizeTall(tester);
    await tester.pumpWidget(wrap(container));
    await settle(tester);

    expect(find.text('Play a round to see your stats.'), findsOneWidget);
    expect(find.byKey(const ValueKey('stat_rounds_played')), findsNothing);
  });

  testWidgets('renders every stat with the correct formatted value',
      (tester) async {
    final rid = await seedRound();
    // One round of par-4s: birdie, par, par, bogey → to-par 0.
    await fx.upsertHole(rid, 1, score: 3, fairwayHit: true, gir: true);
    await fx.upsertHole(rid, 2, score: 4, fairwayHit: true, gir: true);
    await fx.upsertHole(rid, 3, score: 4, fairwayHit: false, gir: true);
    await fx.upsertHole(rid, 4, score: 5, fairwayHit: false, gir: false);

    final container = makeContainer();
    addTearDown(container.dispose);

    resizeTall(tester);
    await tester.pumpWidget(wrap(container));
    await settle(tester);

    // Scoring.
    expect(textOfKey(tester, 'stat_rounds_played'), '1');
    expect(textOfKey(tester, 'stat_avg_score'), '16.0'); // 3+4+4+5
    expect(textOfKey(tester, 'stat_avg_vs_par'), 'E'); // to-par 0
    expect(textOfKey(tester, 'stat_best_round'), 'E');

    // Accuracy.
    expect(textOfKey(tester, 'stat_fairway_pct'), '50.0%'); // 2 of 4
    expect(textOfKey(tester, 'stat_gir_pct'), '75.0%'); // 3 of 4
    expect(textOfKey(tester, 'stat_penalty_rate'), '0.00'); // none
    expect(textOfKey(tester, 'stat_penalty_hole_pct'), '0.0%');

    // Around the green.
    expect(textOfKey(tester, 'stat_putts'), '2.0');
    expect(textOfKey(tester, 'stat_updown_pct'), '—'); // no attempts

    // Score distribution.
    expect(textOfKey(tester, 'dist_eagles'), '0');
    expect(textOfKey(tester, 'dist_birdies'), '1');
    expect(textOfKey(tester, 'dist_pars'), '2');
    expect(textOfKey(tester, 'dist_bogeys'), '1');
    expect(textOfKey(tester, 'dist_double_plus'), '0');
  });

  testWidgets('a par-3-only round shows — for fairway %', (tester) async {
    final rid = await seedRound();
    await fx.upsertHole(rid, 1, par: 3, score: 3, fairwayHit: null);
    await fx.upsertHole(rid, 2, par: 3, score: 3, fairwayHit: null);

    final container = makeContainer();
    addTearDown(container.dispose);

    resizeTall(tester);
    await tester.pumpWidget(wrap(container));
    await settle(tester);

    expect(textOfKey(tester, 'stat_fairway_pct'), '—');
  });

  testWidgets('score distribution folds eagles and double-plus', (tester) async {
    final rid = await seedRound();
    await fx.upsertHole(rid, 1, par: 5, score: 3); // eagle (-2)
    await fx.upsertHole(rid, 2, par: 4, score: 6); // double bogey (+2)
    await fx.upsertHole(rid, 3, par: 4, score: 8); // (+4)

    final container = makeContainer();
    addTearDown(container.dispose);

    resizeTall(tester);
    await tester.pumpWidget(wrap(container));
    await settle(tester);

    expect(textOfKey(tester, 'dist_eagles'), '1');
    expect(textOfKey(tester, 'dist_double_plus'), '2');
  });

  testWidgets('best round vs par carries its sign', (tester) async {
    final rid = await seedRound();
    // Two birdies on par 4s → to-par -2.
    await fx.upsertHole(rid, 1, score: 3);
    await fx.upsertHole(rid, 2, score: 3);

    final container = makeContainer();
    addTearDown(container.dispose);

    resizeTall(tester);
    await tester.pumpWidget(wrap(container));
    await settle(tester);

    expect(textOfKey(tester, 'stat_best_round'), '-2');
    expect(textOfKey(tester, 'stat_avg_vs_par'), '-2.0'); // -2 total / 1 round
    expect(find.text('Augusta · May 25, 2026'), findsOneWidget);
  });
}
