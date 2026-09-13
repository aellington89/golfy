import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/features/courses/course_template.dart';

void main() {
  group('standardPar72', () {
    test('covers 18 holes', () {
      expect(standardPar72, hasLength(18));
    });

    test('adds up to par 72, 36 out and 36 in', () {
      expect(standardPar72.reduce((a, b) => a + b), 72);
      expect(standardPar72.take(9).reduce((a, b) => a + b), 36);
      expect(standardPar72.skip(9).reduce((a, b) => a + b), 36);
    });

    test('has the conventional four par 3s and four par 5s', () {
      expect(standardPar72.where((p) => p == 3), hasLength(4));
      expect(standardPar72.where((p) => p == 5), hasLength(4));
      expect(standardPar72.where((p) => p == 4), hasLength(10));
    });

    test('every value satisfies the par BETWEEN 3 AND 5 constraint', () {
      expect(standardPar72.every((p) => p >= 3 && p <= 5), isTrue);
    });
  });

  group('defaultParForHole', () {
    test('reads the template by 1-based hole number', () {
      expect(defaultParForHole(1), 4);
      expect(defaultParForHole(2), 5);
      expect(defaultParForHole(3), 3);
      expect(defaultParForHole(18), 4);
    });

    test('falls back to par 4 outside the standard 18', () {
      expect(defaultParForHole(0), 4);
      expect(defaultParForHole(19), 4);
      expect(defaultParForHole(-1), 4);
    });
  });

  group('applyYardOffset', () {
    test('shifts every hole by the offset', () {
      expect(applyYardOffset([400, 150, 520], 20), [420, 170, 540]);
      expect(applyYardOffset([400, 150, 520], -25), [375, 125, 495]);
    });

    test('clamps at zero rather than violating the yards >= 0 constraint', () {
      expect(applyYardOffset([10, 0, 300], -50), [0, 0, 250]);
    });

    test('a zero offset is a plain copy', () {
      expect(applyYardOffset([400, 150], 0), [400, 150]);
    });

    test('an empty card stays empty', () {
      expect(applyYardOffset(const [], 30), isEmpty);
    });
  });
}
