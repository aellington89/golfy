import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/dashboard_stats.dart';
import '../../data/repository_provider.dart';
import '../../shell/app_drawer.dart';
import '../../widgets/empty_state.dart';
import '../stats/score_color.dart';
import '../stats/score_format.dart';
import '../stats/stat_format.dart';

/// Lifetime-stats dashboard: a scrollable list of aggregates computed across
/// every entered hole, grouped into Scoring / Score distribution / Accuracy /
/// Around-the-green cards. Sourced from [dashboardStatsStreamProvider], so it
/// updates live as rounds are entered. Null aggregates (e.g. up/down with no
/// attempts) render as an em-dash via the stat_format helpers.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsStreamProvider);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Dashboard')),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load stats: $e')),
        data: (stats) {
          // roundsPlayed counts DISTINCT round_id in hole_results, so a round
          // with no holes entered still reads 0 — i.e. "nothing to show yet".
          if (stats.roundsPlayed == 0) {
            return const EmptyState(
              icon: Icons.insights_outlined,
              message: 'Play a round to see your stats here.',
            );
          }
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            children: [
              _ScoringSection(stats: stats),
              _ScoreDistributionSection(stats: stats),
              _AccuracySection(stats: stats),
              _AroundTheGreenSection(stats: stats),
            ],
          );
        },
      ),
    );
  }
}

/// A titled [Card] grouping related stat rows. Matches the scorecard totals
/// card's Card → Padding → Column(titleLarge header, rows) structure.
class _StatSection extends StatelessWidget {
  const _StatSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// A single label + right-aligned value row. Mirrors the scorecard's
/// `_TotalRow`; [valueKey] makes the value addressable in widget tests.
class _StatRow extends StatelessWidget {
  const _StatRow({
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

class _ScoringSection extends StatelessWidget {
  const _ScoringSection({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Colour the average to match its displayed value; the shared helper rounds
    // to one decimal first so a value that renders as "E" stays neutral, then
    // maps the sign onto scoreToParColor's bands (under par → green) so the
    // dashboard, the event detail card, and the events list all agree.
    final avgVsParColor =
        avgScoreVsParColor(stats.avgScoreVsPar, theme.colorScheme);

    return _StatSection(
      title: 'Scoring',
      children: [
        _StatRow(
          label: 'Rounds played',
          value: '${stats.roundsPlayed}',
          valueKey: const ValueKey('stat_rounds_played'),
        ),
        _StatRow(
          label: 'Avg score per round',
          value: formatDecimal(stats.avgScorePerRound),
          valueKey: const ValueKey('stat_avg_score'),
        ),
        _StatRow(
          label: 'Avg score vs. par',
          value: formatSignedAverage(stats.avgScoreVsPar),
          valueColor: avgVsParColor,
          valueKey: const ValueKey('stat_avg_vs_par'),
        ),
        _BestRoundRow(best: stats.bestRound),
      ],
    );
  }
}

/// Best round: the +/E/- to-par value with the course and date beneath the
/// label. [best] is only null when there are no scored rounds, in which case
/// the dashboard shows its empty state instead — guarded here for safety.
class _BestRoundRow extends StatelessWidget {
  const _BestRoundRow({required this.best});

  final BestRound? best;

  static final _displayFormat = DateFormat.yMMMMd();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final best = this.best;
    if (best == null) {
      return const _StatRow(
        label: 'Best round',
        value: '—',
        valueKey: ValueKey('stat_best_round'),
      );
    }

    // Same green / amber / red bands as the rounds list and scorecard.
    final color = scoreToParColor(best.toPar, theme.colorScheme);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Best round', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 2),
                Text(
                  '${best.courseName} · ${_formatDate(best.date)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatRelativeToPar(best.toPar),
            key: const ValueKey('stat_best_round'),
            style: theme.textTheme.titleMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  static String _formatDate(String iso) {
    try {
      return _displayFormat.format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }
}

class _ScoreDistributionSection extends StatelessWidget {
  const _ScoreDistributionSection({required this.stats});

  final DashboardStats stats;

  static const _countKeys = <String, String>{
    'Eagles': 'dist_eagles',
    'Birdies': 'dist_birdies',
    'Pars': 'dist_pars',
    'Bogeys': 'dist_bogeys',
    'Double+': 'dist_double_plus',
  };

  @override
  Widget build(BuildContext context) {
    final categories = groupScoreDistribution(stats.scoreDistribution);
    final maxCount =
        categories.fold<int>(0, (m, c) => c.count > m ? c.count : m);
    final total = categories.fold<int>(0, (s, c) => s + c.count);

    return _StatSection(
      title: 'Score distribution',
      children: [
        for (final c in categories)
          _DistributionBar(
            label: c.label,
            count: c.count,
            total: total,
            maxCount: maxCount,
            countKey: ValueKey(_countKeys[c.label]!),
            percentKey: ValueKey('${_countKeys[c.label]!}_pct'),
          ),
      ],
    );
  }
}

/// One category's horizontal bar: the label, a track whose filled portion is
/// proportional to this category's share of the busiest one ([count] /
/// [maxCount]), and a trailing cell with the category's share of *all* holes
/// ([count] / [total]) shown prominently above the raw [count]. The bar fill and
/// the percentage use different denominators on purpose — the bar reads
/// relatively (against the tallest category), the percentage absolutely.
class _DistributionBar extends StatelessWidget {
  const _DistributionBar({
    required this.label,
    required this.count,
    required this.total,
    required this.maxCount,
    required this.countKey,
    required this.percentKey,
  });

  final String label;
  final int count;
  final int total;
  final int maxCount;
  final Key countKey;
  final Key percentKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = maxCount == 0 ? 0.0 : count / maxCount;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 12,
                color: theme.colorScheme.surfaceContainerHighest,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: fraction,
                  child: ColoredBox(color: theme.colorScheme.primary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatPercent(total == 0 ? null : count / total),
                  key: percentKey,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  '$count',
                  key: countKey,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccuracySection extends StatelessWidget {
  const _AccuracySection({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return _StatSection(
      title: 'Accuracy',
      children: [
        _StatRow(
          label: 'Fairway hit %',
          value: formatPercent(stats.fairwayHitPct),
          valueKey: const ValueKey('stat_fairway_pct'),
        ),
        _StatRow(
          label: 'Greens in regulation %',
          value: formatPercent(stats.girPct),
          valueKey: const ValueKey('stat_gir_pct'),
        ),
        _StatRow(
          label: 'Penalty strokes / hole',
          value: formatDecimal(stats.avgPenaltyStrokesPerHole, digits: 2),
          valueKey: const ValueKey('stat_penalty_rate'),
        ),
        _StatRow(
          label: 'Holes with a penalty',
          value: formatPercent(stats.penaltyHolePct),
          valueKey: const ValueKey('stat_penalty_hole_pct'),
        ),
      ],
    );
  }
}

class _AroundTheGreenSection extends StatelessWidget {
  const _AroundTheGreenSection({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return _StatSection(
      title: 'Around the green',
      children: [
        _StatRow(
          label: 'Avg putts per hole',
          value: formatDecimal(stats.avgPuttsPerHole),
          valueKey: const ValueKey('stat_putts'),
        ),
        _StatRow(
          label: 'Up & down conversion %',
          value: formatPercent(stats.upDownPct),
          valueKey: const ValueKey('stat_updown_pct'),
        ),
      ],
    );
  }
}
