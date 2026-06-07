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

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$holeNumber', style: theme.textTheme.titleLarge),
                  Text(parText, style: mutedSmall),
                ],
              ),
            ),
            SizedBox(
              width: 68,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    relText,
                    style:
                        theme.textTheme.titleMedium?.copyWith(color: relColor),
                  ),
                  Text(scoreText, style: mutedSmall),
                ],
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatCell(label: 'FW', value: fairwayText),
                  _StatCell(label: 'GIR', value: girText),
                  _StatCell(label: 'Putts', value: puttsText),
                  _StatCell(label: 'U/D', value: upDownText),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
