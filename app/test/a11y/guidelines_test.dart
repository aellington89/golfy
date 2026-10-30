// The accessibility guidelines flutter_test ships, on every screen, in the
// light and dark themes the app really uses (#73). A screen that fails one
// fails here, named, before it reaches a TalkBack user.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_harness.dart';

void main() {
  /// Each guideline, by the name its tests carry.
  final guidelines = <String, AccessibilityGuideline>{
    // Text against its rendered background: 4.5:1, or 3:1 for large text.
    'text contrast meets WCAG AA': textContrastGuideline,
  };

  for (final screen in a11yScreens) {
    group(screen.name, () {
      for (final brightness in Brightness.values) {
        for (final guideline in guidelines.entries) {
          testWidgets('${brightness.name}: ${guideline.key}', (tester) async {
            final semantics = tester.ensureSemantics();
            await pumpA11yScreen(tester, screen, brightness: brightness);
            await expectLater(tester, meetsGuideline(guideline.value));
            semantics.dispose();
          });
        }
      }
    });
  }
}
