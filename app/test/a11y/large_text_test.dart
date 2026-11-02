// Every screen at the largest Android font size (200%) on a small phone, and
// at 1.3×, the largest size at which rows that stack beyond it still lay out
// side by side (#73). A RenderFlex overflow fails a test by itself; text
// clipped by a bar of fixed height doesn't, so those are checked directly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/widgets/hole_nav_bar.dart';

import '_harness.dart';

void main() {
  for (final scale in const [1.3, 2.0]) {
    for (final screen in a11yScreens) {
      testWidgets('${screen.name} fits a 360 dp phone at $scale× text',
          (tester) async {
        await pumpA11yScreen(
          tester,
          screen,
          textScale: scale,
          size: const Size(360, 1600),
        );

        expectTextInside(tester, find.byType(NavigationToolbar));
        expectTextInside(tester, find.byType(HoleNavBar));
      });
    }
  }
}

/// Every line of text in each of [containers] lies within its top and bottom:
/// a toolbar or chip strip too short for its text clips it without an error.
/// Only the vertical edges: the chip strip scrolls sideways.
void expectTextInside(WidgetTester tester, Finder containers) {
  for (final container in containers.evaluate()) {
    final bounds = tester.getRect(find.byElementPredicate((e) => e == container));
    final texts = find.descendant(
      of: find.byElementPredicate((e) => e == container),
      matching: find.byType(RichText),
    );
    for (final text in texts.evaluate()) {
      final rect = tester.getRect(find.byElementPredicate((e) => e == text));
      final what = (text.widget as RichText).text.toPlainText();
      expect(rect.top, greaterThanOrEqualTo(bounds.top - 0.5), reason: what);
      expect(rect.bottom, lessThanOrEqualTo(bounds.bottom + 0.5), reason: what);
    }
  }
}
