import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

    expect(
      find.text('Play a round to see your stats here.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.insights_outlined), findsOneWidget);
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

    // Score distribution — raw counts plus each category's share of all 4
    // holes. Every one of the ten rows renders, zero-filled.
    const expected = {
      'dist_ace': ('0', '0.0%'),
      'dist_condor': ('0', '0.0%'),
      'dist_albatross': ('0', '0.0%'),
      'dist_eagle': ('0', '0.0%'),
      'dist_birdie': ('1', '25.0%'), // 1 of 4
      'dist_par': ('2', '50.0%'), // 2 of 4
      'dist_bogey': ('1', '25.0%'), // 1 of 4
      'dist_double_bogey': ('0', '0.0%'),
      'dist_triple_bogey': ('0', '0.0%'),
      'dist_quadruple_plus': ('0', '0.0%'),
    };
    for (final MapEntry(key: key, value: (count, pct)) in expected.entries) {
      expect(textOfKey(tester, key), count, reason: key);
      expect(textOfKey(tester, '${key}_pct'), pct, reason: '${key}_pct');
    }
    expect(find.byKey(const ValueKey('dist_ace_note')), findsOneWidget);
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

  testWidgets('score distribution splits double, triple and quadruple+ bogeys',
      (tester) async {
    final rid = await seedRound();
    await fx.upsertHole(rid, 1, par: 5, score: 3); // eagle (-2)
    await fx.upsertHole(rid, 2, par: 4, score: 6); // double bogey (+2)
    await fx.upsertHole(rid, 3, par: 4, score: 7); // triple bogey (+3)
    await fx.upsertHole(rid, 4, par: 4, score: 8); // quadruple bogey (+4)
    await fx.upsertHole(rid, 5, par: 4, score: 10); // (+6) → Quadruple+
    await fx.upsertHole(rid, 6, par: 4, score: 4); // par

    final container = makeContainer();
    addTearDown(container.dispose);

    resizeTall(tester);
    await tester.pumpWidget(wrap(container));
    await settle(tester);

    expect(textOfKey(tester, 'dist_eagle'), '1');
    expect(textOfKey(tester, 'dist_double_bogey'), '1');
    expect(textOfKey(tester, 'dist_triple_bogey'), '1');
    expect(textOfKey(tester, 'dist_quadruple_plus'), '2');
    // Shares of all 6 holes — also exercises one-decimal rounding.
    expect(textOfKey(tester, 'dist_eagle_pct'), '16.7%'); // 1 of 6
    expect(textOfKey(tester, 'dist_quadruple_plus_pct'), '33.3%'); // 2 of 6
  });

  testWidgets('an ace counts in its own row and in its par-relative row',
      (tester) async {
    final rid = await seedRound();
    await fx.upsertHole(rid, 1,
        par: 3, score: 1, putts: 0, fairwayHit: null); // ace + eagle
    await fx.upsertHole(rid, 2, par: 5, score: 1, putts: 0); // ace + condor
    await fx.upsertHole(rid, 3, par: 4, score: 8); // quadruple bogey
    await fx.upsertHole(rid, 4, par: 4, score: 4); // par

    final container = makeContainer();
    addTearDown(container.dispose);

    resizeTall(tester);
    await tester.pumpWidget(wrap(container));
    await settle(tester);

    expect(textOfKey(tester, 'dist_ace'), '2');
    expect(textOfKey(tester, 'dist_eagle'), '1');
    expect(textOfKey(tester, 'dist_condor'), '1');
    expect(textOfKey(tester, 'dist_albatross'), '0');
    expect(textOfKey(tester, 'dist_quadruple_plus'), '1');
    // Percentages divide by the 4 holes played, not the 6 row entries: the
    // Ace row overlays the others rather than adding to the total.
    expect(textOfKey(tester, 'dist_ace_pct'), '50.0%'); // 2 of 4
    expect(textOfKey(tester, 'dist_eagle_pct'), '25.0%'); // 1 of 4
    expect(textOfKey(tester, 'dist_par_pct'), '25.0%'); // 1 of 4
    expect(find.byKey(const ValueKey('dist_ace_note')), findsOneWidget);
  });

  testWidgets('no distribution label is cut off when the card has room',
      (tester) async {
    final rid = await seedRound();
    await fx.upsertHole(rid, 1, par: 4, score: 4);

    final container = makeContainer();
    addTearDown(container.dispose);

    resizeTall(tester);
    await tester.pumpWidget(wrap(container));
    await settle(tester);

    // The label column is sized to the widest label, so even the longest
    // one lays out on one line without its ellipsis.
    for (final label in const [
      'Ace',
      'Condor',
      'Albatross',
      'Eagle',
      'Birdie',
      'Par',
      'Bogey',
      'Double bogey',
      'Triple bogey',
      'Quadruple+ bogey',
    ]) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      expect(paragraph.didExceedMaxLines, isFalse, reason: label);
    }
  });

  testWidgets('distribution rows fit a phone at a large text size',
      (tester) async {
    final rid = await seedRound();
    await fx.upsertHole(rid, 1, par: 4, score: 8); // fills Quadruple+ bogey

    final container = makeContainer();
    addTearDown(container.dispose);

    // 360 dp — a small Android phone — at double text size. The label column
    // is capped there, so the bars keep their room and nothing overflows (a
    // RenderFlex overflow would fail the test).
    tester.view.physicalSize = const Size(360, 4000);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(wrap(container));
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Quadruple+ bogey'), findsOneWidget);
    expect(textOfKey(tester, 'dist_quadruple_plus_pct'), '100.0%');
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

    // Under par is green here too — the same band as the rounds list and
    // scorecard, not the theme's primary (#16 colour unification).
    Color? colorOfKey(String key) =>
        tester.widget<Text>(find.byKey(ValueKey(key))).style?.color;
    const underParGreen = Color(0xFF006E1C); // the light theme's (#73)
    expect(colorOfKey('stat_best_round'), underParGreen);
    expect(colorOfKey('stat_avg_vs_par'), underParGreen);
  });

  // #73: what TalkBack reads on the dashboard.
  group('screen reader', () {
    testWidgets('a distribution row is one item with its count and share',
        (tester) async {
      final semantics = tester.ensureSemantics();
      final rid = await seedRound();
      await fx.upsertHole(rid, 1, par: 4, score: 5); // bogey
      await fx.upsertHole(rid, 2, par: 4, score: 5); // bogey
      await fx.upsertHole(rid, 3, par: 4, score: 4); // par
      await fx.upsertHole(rid, 4, par: 3, score: 1, putts: 0, fairwayHit: null);

      final container = makeContainer();
      addTearDown(container.dispose);
      resizeTall(tester);
      await tester.pumpWidget(wrap(container));
      await settle(tester);

      SemanticsNode row(String key) =>
          tester.getSemantics(find.byKey(ValueKey(key)));
      Matcher reads(String label) => isSemantics(label: label);
      expect(row('dist_bogey'), reads('Bogey: 2 holes, 50.0%'));
      expect(row('dist_par'), reads('Par: 1 hole, 25.0%'));
      expect(row('dist_ace'), reads('Ace: 1 hole, 25.0%'));
      expect(row('dist_condor'), reads('Condor: 0 holes, 0.0%'));
      semantics.dispose();
    });

    testWidgets('scores to par read in words; section titles are headings',
        (tester) async {
      final semantics = tester.ensureSemantics();
      final rid = await seedRound();
      await fx.upsertHole(rid, 1, par: 4, score: 6, gir: false);

      final container = makeContainer();
      addTearDown(container.dispose);
      resizeTall(tester);
      await tester.pumpWidget(wrap(container));
      await settle(tester);

      expect(
        tester.getSemantics(find.byKey(const ValueKey('stat_avg_vs_par'))),
        isSemantics(label: 'Avg score vs. par\n2.0 over par'),
      );
      expect(
        tester.getSemantics(find.byKey(const ValueKey('stat_best_round'))),
        isSemantics(
          label: 'Best round\nAugusta · May 25, 2026\n2 over par',
        ),
      );
      for (final title in const [
        'Scoring',
        'Score distribution',
        'Accuracy',
        'Around the green',
      ]) {
        // Each title alone: the ace note stays out of its heading.
        expect(
          tester.getSemantics(find.text(title)),
          matchesSemantics(label: title, isHeader: true),
          reason: title,
        );
      }
      semantics.dispose();
    });

    testWidgets('a stat with no data reads "no data"', (tester) async {
      final semantics = tester.ensureSemantics();
      final rid = await seedRound();
      await fx.upsertHole(rid, 1, par: 4, score: 4); // no up-and-down attempts

      final container = makeContainer();
      addTearDown(container.dispose);
      resizeTall(tester);
      await tester.pumpWidget(wrap(container));
      await settle(tester);

      expect(
        tester.getSemantics(find.byKey(const ValueKey('stat_updown_pct'))),
        isSemantics(label: 'Up & down conversion %\nno data'),
      );
      semantics.dispose();
    });
  });
}
