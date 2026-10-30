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

  group('spokenRelativeToPar', () {
    test('zero is even par, not "E"', () {
      expect(spokenRelativeToPar(0), 'even par');
    });

    test('over par', () {
      expect(spokenRelativeToPar(1), '1 over par');
      expect(spokenRelativeToPar(12), '12 over par');
    });

    test('under par drops the minus sign', () {
      expect(spokenRelativeToPar(-3), '3 under par');
    });
  });

  group('holeScoreName', () {
    test('names every result from condor to quadruple bogey', () {
      expect(
        [for (var d = -4; d <= 4; d++) holeScoreName(d)],
        [
          'condor',
          'albatross',
          'eagle',
          'birdie',
          'par',
          'bogey',
          'double bogey',
          'triple bogey',
          'quadruple bogey',
        ],
      );
    });

    test('has no name past quadruple bogey', () {
      expect(holeScoreName(5), isNull);
      expect(holeScoreName(9), isNull);
    });
  });
}
