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
}
