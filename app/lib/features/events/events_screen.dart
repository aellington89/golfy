import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/models/round_with_course.dart';
import '../../data/repository_provider.dart';
import '../../shell/app_drawer.dart';
import '../../widgets/empty_state.dart';
import '../stats/score_color.dart';
import '../stats/score_format.dart';
import '../stats/stat_format.dart';
import 'add_event_dialog.dart';
import 'event_detail_screen.dart';
import 'event_result_badge.dart';
import 'event_result_format.dart';

/// The Events tab (#42): every event with its result badge, round count, and a
/// compact scoring line (#63), a FAB to create a new (possibly empty) event, and
/// tap-through to the [EventDetailScreen]. Backed by [eventsStreamProvider] —
/// the authoritative list, which includes events with no rounds yet. Round
/// counts and per-event scoring stats are both derived in-memory from
/// [roundsStreamProvider], so the list opens no per-tile DB watcher.
class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsStreamProvider);
    final rounds =
        ref.watch(roundsStreamProvider).value ?? const <RoundWithCourse>[];

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Events')),
      floatingActionButton: eventsAsync.when(
        loading: () => null,
        error: (_, _) => null,
        data: (events) => FloatingActionButton(
          onPressed: () => _openAddEventDialog(context, events),
          child: const Icon(Icons.add),
        ),
      ),
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load events: $e')),
        data: (events) {
          if (events.isEmpty) {
            return const EmptyState(
              icon: Icons.emoji_events_outlined,
              message: 'No events yet. Tap + to create one.',
            );
          }
          final summaries = _summaries(rounds);
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: events.length,
            itemBuilder: (context, i) {
              final event = events[i];
              return _EventTile(
                event: event,
                stats: summaries[event.id] ??
                    const _EventTileStats(roundCount: 0),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openAddEventDialog(
    BuildContext context,
    List<Event> events,
  ) async {
    await showDialog<Event>(
      context: context,
      builder: (_) => AddEventDialog(existingEvents: events),
    );
  }

  /// Per-event tile summaries keyed by event id, grouped in memory from the full
  /// rounds stream — the same source as the old round-count grouping, extended
  /// with a scoring summary (#63) so the list needs no per-tile DB watcher.
  /// Casual rounds (a null event) are skipped. The average and best mirror the
  /// per-event DB aggregate (#56): both are computed over the event's *scored*
  /// rounds (`holesEntered > 0`), so an event whose attached rounds are all
  /// empty yields a count but no scoring line.
  static Map<int, _EventTileStats> _summaries(List<RoundWithCourse> rounds) {
    final counts = <int, int>{};
    final scored = <int, int>{};
    final sumVsPar = <int, int>{};
    final bestVsPar = <int, int>{};
    for (final r in rounds) {
      final id = r.event?.id;
      if (id == null) continue;
      counts[id] = (counts[id] ?? 0) + 1;
      if (r.holesEntered > 0) {
        final rel = r.relativeToPar;
        scored[id] = (scored[id] ?? 0) + 1;
        sumVsPar[id] = (sumVsPar[id] ?? 0) + rel;
        final best = bestVsPar[id];
        if (best == null || rel < best) bestVsPar[id] = rel;
      }
    }
    return {
      for (final entry in counts.entries)
        entry.key: _EventTileStats(
          roundCount: entry.value,
          // int / int yields a double, matching the DB aggregate's REAL
          // division; null when the event has no scored round.
          avgVsPar: (scored[entry.key] ?? 0) == 0
              ? null
              : sumVsPar[entry.key]! / scored[entry.key]!,
          bestToPar: bestVsPar[entry.key],
        ),
    };
  }
}

/// A single event's tile summary, derived in memory by [EventsScreen._summaries]
/// (#63). [avgVsPar] and [bestToPar] are both null exactly when the event has no
/// scored round; [hasScore] gates the tile's scoring line on that.
class _EventTileStats {
  const _EventTileStats({
    required this.roundCount,
    this.avgVsPar,
    this.bestToPar,
  });

  /// Rounds attached to the event, including empty ones (drives the count text).
  final int roundCount;

  /// Mean strokes vs. par across the event's scored rounds, or null when none.
  final double? avgVsPar;

  /// Lowest round-to-par across the event's scored rounds, or null when none.
  final int? bestToPar;

  bool get hasScore => avgVsPar != null;
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.stats});

  final Event event;
  final _EventTileStats stats;

  @override
  Widget build(BuildContext context) {
    final count = stats.roundCount;
    final countText = count == 0
        ? 'No rounds yet'
        : (count == 1 ? '1 round' : '$count rounds');
    return ListTile(
      key: ValueKey('event_tile_${event.id}'),
      leading: const Icon(Icons.emoji_events_outlined),
      title: Text(formatEventTitle(event)),
      subtitle: _buildSubtitle(context, countText),
      trailing:
          hasRecordedResult(event) ? EventResultBadge(event: event) : null,
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (_) => EventDetailScreen(eventId: event.id),
        ),
      ),
    );
  }

  /// The subtitle: just the round count for an event with no scored round, or
  /// `count · <avg vs. par> · Best <to-par>` when it has one (#63). The count
  /// stays its own `Text` node (and ellipsizes first if space is tight) so the
  /// avg/best segments always show; both reuse the shared score colours so the
  /// tile agrees with the detail card. Segment `Text` styles inherit the
  /// ListTile subtitle style and override only the colour.
  Widget _buildSubtitle(BuildContext context, String countText) {
    if (!stats.hasScore) return Text(countText);
    final scheme = Theme.of(context).colorScheme;
    final avg = stats.avgVsPar!;
    final best = stats.bestToPar!;
    return Row(
      children: [
        Flexible(child: Text(countText, overflow: TextOverflow.ellipsis)),
        const Text(' · '),
        Text(
          formatSignedAverage(avg),
          key: ValueKey('event_tile_avg_${event.id}'),
          style: TextStyle(color: avgScoreVsParColor(avg, scheme)),
        ),
        const Text(' · '),
        Text(
          'Best ${formatRelativeToPar(best)}',
          key: ValueKey('event_tile_best_${event.id}'),
          style: TextStyle(color: scoreToParColor(best, scheme)),
        ),
      ],
    );
  }
}
