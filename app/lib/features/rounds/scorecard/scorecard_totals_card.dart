import 'package:flutter/material.dart';

import '../../../data/database.dart';
import '../../stats/score_color.dart';
import '../../stats/score_format.dart';

/// Column totals for a round, aggregated from the entered holes only.
///
/// All figures are plain sums/counts (no percentages) so there is never a
/// divide-by-zero: an empty round yields zeroes that the card renders as
/// dashes. Fairway eligibility excludes par-3s (which have no fairway).
class ScorecardTotals {
  const ScorecardTotals({
    required this.holesEntered,
    required this.totalScore,
    required this.totalPar,
    required this.fairwayHits,
    required this.fairwayEligible,
    required this.gir,
    required this.totalPutts,
    required this.upDownMade,
    required this.upDownAttempts,
  });

  factory ScorecardTotals.fromHoles(List<HoleResult> holes) {
    var totalScore = 0;
    var totalPar = 0;
    var fairwayHits = 0;
    var fairwayEligible = 0;
    var gir = 0;
    var totalPutts = 0;
    var upDownMade = 0;
    var upDownAttempts = 0;

    for (final h in holes) {
      totalScore += h.score;
      totalPar += h.par;
      totalPutts += h.putts;
      if (h.gir) gir++;
      if (h.par != 3) {
        fairwayEligible++;
        if (h.fairwayHit == true) fairwayHits++;
      }
      if (h.upDownAttempt) {
        upDownAttempts++;
        if (h.upDownSuccess) upDownMade++;
      }
    }

    return ScorecardTotals(
      holesEntered: holes.length,
      totalScore: totalScore,
      totalPar: totalPar,
      fairwayHits: fairwayHits,
      fairwayEligible: fairwayEligible,
      gir: gir,
      totalPutts: totalPutts,
      upDownMade: upDownMade,
      upDownAttempts: upDownAttempts,
    );
  }

  final int holesEntered;
  final int totalScore;
  final int totalPar;
  final int fairwayHits;
  final int fairwayEligible;
  final int gir;
  final int totalPutts;
  final int upDownMade;
  final int upDownAttempts;

  bool get isEmpty => holesEntered == 0;
  int get relativeToPar => totalScore - totalPar;
}

/// Summary [Card] shown at the top of the scorecard with the round's column
/// totals. Sits above the per-hole cards so the headline numbers are visible
/// without scrolling.
class ScorecardTotalsCard extends StatelessWidget {
  const ScorecardTotalsCard({super.key, required this.holes});

  final List<HoleResult> holes;

  static const String _dash = '—';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = ScorecardTotals.fromHoles(holes);
    final empty = t.isEmpty;

    final relText = empty ? _dash : formatRelativeToPar(t.relativeToPar);
    final fairwayText = t.fairwayEligible == 0
        ? _dash
        : '${t.fairwayHits}/${t.fairwayEligible}';
    final girText = empty ? _dash : '${t.gir}/${t.holesEntered}';
    final upDownText = empty ? _dash : '${t.upDownMade}/${t.upDownAttempts}';

    final relColor =
        empty ? null : scoreToParColor(t.relativeToPar, theme.colorScheme);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Totals', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            _TotalRow(
              label: 'Score',
              value: empty ? _dash : '${t.totalScore}',
              valueKey: const ValueKey('total_score'),
            ),
            _TotalRow(
              label: 'Par',
              value: empty ? _dash : '${t.totalPar}',
              valueKey: const ValueKey('total_par'),
            ),
            _TotalRow(
              label: '± Par',
              value: relText,
              valueColor: relColor,
              valueKey: const ValueKey('total_rel'),
            ),
            _TotalRow(
              label: 'Fairways',
              value: fairwayText,
              valueKey: const ValueKey('total_fairways'),
            ),
            _TotalRow(
              label: 'GIR',
              value: girText,
              valueKey: const ValueKey('total_gir'),
            ),
            _TotalRow(
              label: 'Putts',
              value: empty ? _dash : '${t.totalPutts}',
              valueKey: const ValueKey('total_putts'),
            ),
            _TotalRow(
              label: 'Up & down',
              value: upDownText,
              valueKey: const ValueKey('total_updown'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.valueKey,
    this.valueColor,
  });

  final String label;
  final String value;
  final Key? valueKey;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            value,
            key: valueKey,
            style: theme.textTheme.titleMedium?.copyWith(color: valueColor),
          ),
        ],
      ),
    );
  }
}
