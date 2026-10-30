import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/widgets/hole_nav_bar.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    int holeCount = 18,
    int currentIndex = 0,
    Set<int> complete = const {},
    Set<int> dirty = const {},
    String label = 'Holes saved',
    String keyPrefix = 'hole_chip',
    ValueChanged<int>? onTapHole,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Hole entry'),
          bottom: HoleNavBar(
            holeCount: holeCount,
            currentIndex: currentIndex,
            complete: complete,
            dirty: dirty,
            label: label,
            keyPrefix: keyPrefix,
            onTapHole: onTapHole ?? (_) {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// The avatar icon on a hole's chip, or null when it has none.
  IconData? avatarIcon(WidgetTester tester, String key) {
    final chip = tester.widget<ChoiceChip>(find.byKey(ValueKey(key)));
    final avatar = chip.avatar;
    return avatar is Icon ? avatar.icon : null;
  }

  testWidgets('counts complete holes against the total', (tester) async {
    await pump(tester, complete: {1, 2, 3, 7});
    expect(find.text('Holes saved: 4 / 18'), findsOneWidget);
  });

  testWidgets('builds the counter from the supplied label', (tester) async {
    await pump(tester, holeCount: 18, complete: {5}, label: 'Holes set');
    expect(find.text('Holes set: 1 / 18'), findsOneWidget);
  });

  testWidgets('checks complete holes and leaves untouched ones bare',
      (tester) async {
    await pump(tester, complete: {1});
    expect(avatarIcon(tester, 'hole_chip_1'), Icons.check);
    expect(avatarIcon(tester, 'hole_chip_2'), isNull);
  });

  testWidgets('unsaved edits outrank completeness on a chip', (tester) async {
    // A hole that is saved *and* edited since needs attention, so it shows the
    // pencil rather than the check.
    await pump(tester, complete: {1, 2}, dirty: {2});
    expect(avatarIcon(tester, 'hole_chip_1'), Icons.check);
    expect(avatarIcon(tester, 'hole_chip_2'), Icons.edit);
  });

  testWidgets('highlights the current hole only', (tester) async {
    await pump(tester, currentIndex: 2);
    expect(
      tester.widget<ChoiceChip>(find.byKey(const ValueKey('hole_chip_3'))).selected,
      isTrue,
    );
    expect(
      tester.widget<ChoiceChip>(find.byKey(const ValueKey('hole_chip_1'))).selected,
      isFalse,
    );
  });

  testWidgets('reports the tapped hole as a zero-based index', (tester) async {
    int? tapped;
    await pump(tester, onTapHole: (i) => tapped = i);

    await tester.tap(find.byKey(const ValueKey('hole_chip_4')));
    await tester.pumpAndSettle();

    expect(tapped, 3);
  });

  testWidgets('namespaces its chip keys so two strips can coexist',
      (tester) async {
    await pump(tester, keyPrefix: 'course_hole_chip');
    expect(find.byKey(const ValueKey('course_hole_chip_1')), findsOneWidget);
    expect(find.byKey(const ValueKey('hole_chip_1')), findsNothing);
  });

  // #73: the check and pencil only show a hole's state; its chip says it.
  testWidgets('each chip and the counter read their state in words',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, complete: {1, 2}, dirty: {2});

    expect(find.bySemanticsLabel('Hole 1, saved'), findsOneWidget);
    expect(find.bySemanticsLabel('Hole 2, unsaved changes'), findsOneWidget);
    expect(find.bySemanticsLabel('Hole 3'), findsOneWidget);
    expect(find.bySemanticsLabel('Holes saved: 2 of 18'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a screen that sets holes says "set", not "saved"',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          bottom: HoleNavBar(
            holeCount: 18,
            currentIndex: 0,
            complete: const {1},
            label: 'Holes set',
            completeState: 'set',
            onTapHole: (_) {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Hole 1, set'), findsOneWidget);
    semantics.dispose();
  });

  test('is 80 dp tall at the default text size', () {
    expect(HoleNavBar.heightFor(TextScaler.noScaling), 80);
  });

  // #73: at a fixed 80 dp, a large text size squeezed the chips until their
  // numbers were clipped.
  for (final scale in const [1.5, 2.0]) {
    testWidgets('grows so the counter and chips fit at $scale× text',
        (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              bottom: HoleNavBar(
                holeCount: 18,
                currentIndex: 0,
                complete: const {1},
                dirty: const {2},
                label: 'Holes saved',
                onTapHole: (_) {},
                textScaler: MediaQuery.textScalerOf(context),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final bar = tester.getRect(find.byType(HoleNavBar));
      expect(bar.height, greaterThan(80));
      final counter = tester.getRect(find.textContaining('Holes saved'));
      expect(counter.top, greaterThanOrEqualTo(bar.top));
      for (final hole in const [1, 2, 3]) {
        final label = tester.getRect(find.descendant(
          of: find.byKey(ValueKey('hole_chip_$hole')),
          matching: find.text('$hole'),
        ));
        expect(label.top, greaterThan(counter.bottom), reason: 'hole $hole');
        expect(label.bottom, lessThanOrEqualTo(bar.bottom),
            reason: 'hole $hole');
      }
    });
  }

  testWidgets('moving to a far hole scrolls its chip into view',
      (tester) async {
    Future<void> show(int index) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            bottom: HoleNavBar(
              holeCount: 18,
              currentIndex: index,
              complete: const {},
              label: 'Holes saved',
              onTapHole: (_) {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await show(0);
    for (var i = 1; i <= 17; i++) {
      await show(i);
    }

    final chip = tester.getRect(find.byKey(const ValueKey('hole_chip_18')));
    expect(chip.left, greaterThanOrEqualTo(0));
    expect(chip.right, lessThanOrEqualTo(360));
  });
}
