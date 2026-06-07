import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/models/dashboard_stats.dart';
import 'package:golfy_app/features/stats/stat_format.dart';

void main() {
  group('formatPercent', () {
    test('formats a fraction as a one-decimal percent', () {
      expect(formatPercent(0.625), '62.5%');
      expect(formatPercent(1.0), '100.0%');
      expect(formatPercent(0.0), '0.0%');
    });

    test('rounds to one decimal', () {
      expect(formatPercent(25 / 36), '69.4%');
    });

    test('null renders an em-dash', () {
      expect(formatPercent(null), '—');
    });
  });

  group('formatDecimal', () {
    test('defaults to one decimal', () {
      expect(formatDecimal(71.0), '71.0');
      expect(formatDecimal(1.83), '1.8');
    });

    test('respects the digits argument', () {
      expect(formatDecimal(2 / 36, digits: 2), '0.06');
    });

    test('null renders an em-dash', () {
      expect(formatDecimal(null), '—');
      expect(formatDecimal(null, digits: 2), '—');
    });
  });

  group('formatSignedAverage', () {
    test('under par keeps its - sign', () {
      expect(formatSignedAverage(-1.0), '-1.0');
    });

    test('over par gets an explicit +', () {
      expect(formatSignedAverage(2.34), '+2.3');
    });

    test('exactly zero is E', () {
      expect(formatSignedAverage(0.0), 'E');
    });

    test('a value that rounds to zero is E (no -0.0 / +0.0)', () {
      expect(formatSignedAverage(-0.04), 'E');
      expect(formatSignedAverage(0.04), 'E');
    });

    test('null renders an em-dash', () {
      expect(formatSignedAverage(null), '—');
    });
  });

  group('groupScoreDistribution', () {
    test('maps the central buckets to their categories, zero-filling', () {
      final result = groupScoreDistribution(const [
        ScoreBucket(scoreVsPar: -1, count: 6),
        ScoreBucket(scoreVsPar: 0, count: 26),
        ScoreBucket(scoreVsPar: 1, count: 4),
      ]);

      expect(result, const [
        ScoreCategoryCount(label: 'Eagles', count: 0),
        ScoreCategoryCount(label: 'Birdies', count: 6),
        ScoreCategoryCount(label: 'Pars', count: 26),
        ScoreCategoryCount(label: 'Bogeys', count: 4),
        ScoreCategoryCount(label: 'Double+', count: 0),
      ]);
    });

    test('folds albatross/eagle into Eagles and triple+ into Double+', () {
      final result = groupScoreDistribution(const [
        ScoreBucket(scoreVsPar: -3, count: 1), // albatross
        ScoreBucket(scoreVsPar: -2, count: 2), // eagle
        ScoreBucket(scoreVsPar: 2, count: 3), // double bogey
        ScoreBucket(scoreVsPar: 4, count: 1), // quadruple bogey
      ]);

      expect(result.first, const ScoreCategoryCount(label: 'Eagles', count: 3));
      expect(result.last, const ScoreCategoryCount(label: 'Double+', count: 4));
    });

    test('empty input yields all five categories at zero', () {
      final result = groupScoreDistribution(const []);

      expect(result.map((c) => c.count), [0, 0, 0, 0, 0]);
      expect(
        result.map((c) => c.label),
        ['Eagles', 'Birdies', 'Pars', 'Bogeys', 'Double+'],
      );
    });
  });
}
