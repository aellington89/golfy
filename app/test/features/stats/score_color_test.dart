import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/features/stats/score_color.dart';

void main() {
  // The app's real schemes; `scheme.error` is what the red band must equal.
  final light = ColorScheme.fromSeed(
    seedColor: Colors.deepPurple,
    brightness: Brightness.light,
  );
  final dark = ColorScheme.fromSeed(
    seedColor: Colors.deepPurple,
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
}
