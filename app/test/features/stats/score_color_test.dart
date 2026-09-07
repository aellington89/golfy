import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/features/stats/score_color.dart';

void main() {
  // Green-seeded schemes mirroring the app's golf palette; `scheme.error` is
  // what the red (two-over) band must equal.
  final light = ColorScheme.fromSeed(
    seedColor: Colors.green,
    brightness: Brightness.light,
  );
  final dark = ColorScheme.fromSeed(
    seedColor: Colors.green,
    brightness: Brightness.dark,
  );

  group('scoreToParColor (light scheme)', () {
    test('under par is green (one shade for any amount under)', () {
      expect(scoreToParColor(-1, light), Colors.green.shade700);
      expect(scoreToParColor(-2, light), Colors.green.shade700);
      expect(scoreToParColor(-9, light), Colors.green.shade700);
    });

    test('even par is null so the caller uses the default text colour', () {
      expect(scoreToParColor(0, light), isNull);
    });

    test('exactly one over par is amber', () {
      expect(scoreToParColor(1, light), Colors.amber.shade800);
    });

    test('two or more over par is the theme error colour', () {
      expect(scoreToParColor(2, light), light.error);
      expect(scoreToParColor(5, light), light.error);
    });
  });

  group('scoreToParColor (dark scheme)', () {
    test('under par uses a lighter green for contrast on dark surfaces', () {
      expect(scoreToParColor(-1, dark), Colors.green.shade400);
      expect(scoreToParColor(-3, dark), Colors.green.shade400);
    });

    test('even par is still null', () {
      expect(scoreToParColor(0, dark), isNull);
    });

    test('one over uses a lighter amber', () {
      expect(scoreToParColor(1, dark), Colors.amber.shade400);
    });

    test("two or more over tracks the dark scheme's error colour", () {
      expect(scoreToParColor(2, dark), dark.error);
      expect(scoreToParColor(5, dark), dark.error);
    });
  });

  group('avgScoreVsParColor', () {
    test('a null average (no data) is null in either scheme', () {
      expect(avgScoreVsParColor(null, light), isNull);
      expect(avgScoreVsParColor(null, dark), isNull);
    });

    test('any positive average is the theme error colour (over par → red)', () {
      // Unlike a single hole, a small over-par average is red, not amber.
      expect(avgScoreVsParColor(0.3, light), light.error);
      expect(avgScoreVsParColor(2.4, light), light.error);
      expect(avgScoreVsParColor(2.4, dark), dark.error);
    });

    test('any negative average is green', () {
      expect(avgScoreVsParColor(-0.3, light), Colors.green.shade700);
      expect(avgScoreVsParColor(-1.5, light), Colors.green.shade700);
      expect(avgScoreVsParColor(-1.5, dark), Colors.green.shade400);
    });

    test('an average that rounds to zero stays neutral (null)', () {
      expect(avgScoreVsParColor(0.0, light), isNull);
      expect(avgScoreVsParColor(0.04, light), isNull); // rounds to 0.0
      expect(avgScoreVsParColor(-0.04, dark), isNull);
    });
  });
}
