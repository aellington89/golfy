import 'package:flutter/material.dart';

import '../../../data/database.dart';
import '../../stats/score_color.dart';
import '../../stats/score_format.dart';

/// One row of the read-only scorecard: a [Card] summarising a single hole.
///
/// Pure render from its inputs — [result] is `null` for a hole that hasn't
/// been entered yet, in which case every value shows an em dash so all 18
/// rows are always present. Fairway shows `N/A` on par-3s (which never store
/// a fairway value) and a check / cross otherwise.
class HoleScorecardCard extends StatelessWidget {
  const HoleScorecardCard({
    super.key,
    required this.holeNumber,
    required this.result,
  });

  final int holeNumber;
  final HoleResult? result;

  static const String _dash = '—';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = result;

    final parText = r == null ? _dash : 'Par ${r.par}';
    final relText = r == null ? _dash : formatScoreToPar(r.score, r.par);
    final scoreText = r == null ? _dash : 'Score ${r.score}';

    final relColor =
        r == null ? null : scoreToParColor(r.score - r.par, theme.colorScheme);

    final fairwayText = r == null
        ? _dash
        : r.par == 3
            ? 'N/A'
            : r.fairwayHit == null
                ? _dash
                : (r.fairwayHit! ? '✓' : '✗');
    final girText = r == null ? _dash : (r.gir ? '✓' : '✗');
    final puttsText = r == null ? _dash : '${r.putts}';
    final upDownText = r == null
        ? _dash
        : !r.upDownAttempt
            ? _dash
            : (r.upDownSuccess ? '✓' : '✗');

    final mutedSmall = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final hole = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 52),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$holeNumber', style: theme.textTheme.titleLarge),
          Text(parText, style: mutedSmall),
        ],
      ),
    );
    final score = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            relText,
            style: theme.textTheme.titleMedium?.copyWith(color: relColor),
          ),
          Text(scoreText, style: mutedSmall),
        ],
      ),
    );
    final stats = Wrap(
      alignment: WrapAlignment.spaceEvenly,
      spacing: 8,
      runSpacing: 4,
      children: [
        _StatCell(label: 'FW', value: fairwayText),
        _StatCell(label: 'GIR', value: girText),
        _StatCell(label: 'Putts', value: puttsText),
        _StatCell(label: 'U/D', value: upDownText),
      ],
    );
    // One line at the default size. At a large text size the hole and score
    // sit above the stats, which then have the card's full width (#73).
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 14 * 1.3;

    // One sentence for a screen reader in place of the cells, whose "FW",
    // "✓" and "—" read as letters and symbol names (#73).
    return Semantics(
      container: true,
      label: spokenHoleSummary(holeNumber, r),
      excludeSemantics: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: largeText
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(spacing: 16, runSpacing: 4, children: [hole, score]),
                    const SizedBox(height: 8),
                    stats,
                  ],
                )
              : Row(
                  children: [
                    hole,
                    const SizedBox(width: 8),
                    score,
                    Expanded(child: stats),
                  ],
                ),
        ),
      ),
    );
  }
}

/// What a screen reader says for one scorecard row: "Hole 4, par 4. Score 5,
/// bogey, 1 over par. Fairway hit. Green in regulation missed. 2 putts. No up
/// and down." A hole not entered yet is "Hole 4, not entered." Par 3s leave
/// the fairway out, as the card shows N/A (#73).
String spokenHoleSummary(int holeNumber, HoleResult? r) {
  if (r == null) return 'Hole $holeNumber, not entered.';
  final diff = r.score - r.par;
  // "Score 4, even par": "par, even par" would say it twice.
  final name = diff == 0 ? null : holeScoreName(diff);
  final fairwayHit = r.fairwayHit;
  return [
    'Hole $holeNumber, par ${r.par}',
    'Score ${r.score}, ${name == null ? '' : '$name, '}'
        '${spokenRelativeToPar(diff)}',
    if (r.par != 3)
      fairwayHit == null
          ? 'Fairway not recorded'
          : (fairwayHit ? 'Fairway hit' : 'Fairway missed'),
    r.gir ? 'Green in regulation' : 'Green in regulation missed',
    r.putts == 1 ? '1 putt' : '${r.putts} putts',
    if (!r.upDownAttempt)
      'No up and down'
    else
      r.upDownSuccess ? 'Up and down made' : 'Up and down missed',
  ].map((part) => '$part.').join(' ');
}

/// A small labelled stat (label above value), used for the FW / GIR / Putts /
/// U/D columns of a [HoleScorecardCard].
class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
