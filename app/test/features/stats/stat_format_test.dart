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
    const labels = [
      'Ace',
      'Condor',
      'Albatross',
      'Eagle',
      'Birdie',
      'Par',
      'Bogey',
      'Double bogey',
      'Triple bogey',
      'Quadruple+ bogey',
    ];

    int countOf(List<ScoreCategoryCount> rows, String label) =>
        rows.singleWhere((c) => c.label == label).count;

    test('maps the central buckets to their categories, zero-filling', () {
      final result = groupScoreDistribution(const [
        ScoreBucket(scoreVsPar: -1, count: 6),
        ScoreBucket(scoreVsPar: 0, count: 26),
        ScoreBucket(scoreVsPar: 1, count: 4),
      ]);

      expect(result, const [
        ScoreCategoryCount(label: 'Ace', count: 0, isAce: true),
        ScoreCategoryCount(label: 'Condor', count: 0),
        ScoreCategoryCount(label: 'Albatross', count: 0),
        ScoreCategoryCount(label: 'Eagle', count: 0),
        ScoreCategoryCount(label: 'Birdie', count: 6),
        ScoreCategoryCount(label: 'Par', count: 26),
        ScoreCategoryCount(label: 'Bogey', count: 4),
        ScoreCategoryCount(label: 'Double bogey', count: 0),
        ScoreCategoryCount(label: 'Triple bogey', count: 0),
        ScoreCategoryCount(label: 'Quadruple+ bogey', count: 0),
      ]);
    });

    test('gives every score-to-par value from -4 to +3 its own row', () {
      final result = groupScoreDistribution([
        for (var d = -4; d <= 3; d++) ScoreBucket(scoreVsPar: d, count: d + 10),
      ]);

      expect(countOf(result, 'Condor'), 6);
      expect(countOf(result, 'Albatross'), 7);
      expect(countOf(result, 'Eagle'), 8);
      expect(countOf(result, 'Birdie'), 9);
      expect(countOf(result, 'Par'), 10);
      expect(countOf(result, 'Bogey'), 11);
      expect(countOf(result, 'Double bogey'), 12);
      expect(countOf(result, 'Triple bogey'), 13);
    });

    test('Quadruple+ bogey absorbs +4 and worse; Condor absorbs -4 and better',
        () {
      final result = groupScoreDistribution(const [
        ScoreBucket(scoreVsPar: -5, count: 1), // not possible today (par ≤ 5)
        ScoreBucket(scoreVsPar: -4, count: 1),
        ScoreBucket(scoreVsPar: 4, count: 2),
        ScoreBucket(scoreVsPar: 5, count: 3),
        ScoreBucket(scoreVsPar: 6, count: 4),
      ]);

      expect(countOf(result, 'Condor'), 2);
      expect(countOf(result, 'Triple bogey'), 0);
      expect(countOf(result, 'Quadruple+ bogey'), 9);
    });

    test('aces are summed across buckets and also stay in their own row', () {
      final result = groupScoreDistribution(const [
        ScoreBucket(scoreVsPar: -4, count: 1, aces: 1), // ace on a par 5
        ScoreBucket(scoreVsPar: -3, count: 2, aces: 1), // ace on a par 4
        ScoreBucket(scoreVsPar: -2, count: 3, aces: 1), // ace on a par 3
        ScoreBucket(scoreVsPar: 0, count: 10),
      ]);

      expect(result.first,
          const ScoreCategoryCount(label: 'Ace', count: 3, isAce: true));
      expect(countOf(result, 'Condor'), 1);
      expect(countOf(result, 'Albatross'), 2);
      expect(countOf(result, 'Eagle'), 3);
      // The par-relative rows still add up to the number of holes.
      final holes = result
          .where((c) => !c.isAce)
          .fold<int>(0, (s, c) => s + c.count);
      expect(holes, 16);
    });

    test('empty input yields all ten categories at zero, only Ace flagged', () {
      final result = groupScoreDistribution(const []);

      expect(result.map((c) => c.label), labels);
      expect(result.map((c) => c.count), List.filled(10, 0));
      expect(result.where((c) => c.isAce).map((c) => c.label), ['Ace']);
    });
  });
}
