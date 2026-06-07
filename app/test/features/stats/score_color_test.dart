import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/features/stats/score_color.dart';

void main() {
  // The app's real scheme; `scheme.error` is what the red band must equal.
  final scheme = ColorScheme.fromSeed(seedColor: Colors.deepPurple);

  group('scoreToParColor', () {
    test('under par is green (one shade for any amount under)', () {
      expect(scoreToParColor(-1, scheme), Colors.green.shade700);
      expect(scoreToParColor(-2, scheme), Colors.green.shade700);
      expect(scoreToParColor(-9, scheme), Colors.green.shade700);
    });

    test('even par is null so the caller uses the default text colour', () {
      expect(scoreToParColor(0, scheme), isNull);
    });

    test('exactly one over par is amber', () {
      expect(scoreToParColor(1, scheme), Colors.amber.shade800);
    });

    test('two or more over par is the theme error colour', () {
      expect(scoreToParColor(2, scheme), scheme.error);
      expect(scoreToParColor(5, scheme), scheme.error);
    });
  });
}
