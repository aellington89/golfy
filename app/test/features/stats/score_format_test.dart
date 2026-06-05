import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/features/stats/score_format.dart';

void main() {
  group('formatScoreToPar', () {
    test('even par renders E', () {
      expect(formatScoreToPar(4, 4), 'E');
    });

    test('over par renders a signed +', () {
      expect(formatScoreToPar(5, 4), '+1');
      expect(formatScoreToPar(8, 4), '+4');
    });

    test('under par carries its - sign', () {
      expect(formatScoreToPar(3, 4), '-1');
      expect(formatScoreToPar(2, 5), '-3');
    });
  });

  group('formatRelativeToPar', () {
    test('zero is E', () {
      expect(formatRelativeToPar(0), 'E');
    });

    test('positive gets an explicit +', () {
      expect(formatRelativeToPar(7), '+7');
    });

    test('negative keeps its -', () {
      expect(formatRelativeToPar(-5), '-5');
    });
  });
}
