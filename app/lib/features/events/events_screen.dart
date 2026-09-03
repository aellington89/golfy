import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/models/round_with_course.dart';
import '../../data/repository_provider.dart';
import '../../widgets/empty_state.dart';
import 'add_event_dialog.dart';
import 'event_detail_screen.dart';
import 'event_result_badge.dart';
import 'event_result_format.dart';

/// The Events tab (#42): every event with its result badge and round count, a
/// FAB to create a new (possibly empty) event, and tap-through to the
/// [EventDetailScreen]. Backed by [eventsStreamProvider] — the authoritative
/// list, which includes events with no rounds yet; round counts are derived
/// in-memory from [roundsStreamProvider].
class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsStreamProvider);
    final rounds =
        ref.watch(roundsStreamProvider).value ?? const <RoundWithCourse>[];

    return Scaffold(
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
          final counts = _roundCounts(rounds);
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: events.length,
            itemBuilder: (context, i) {
              final event = events[i];
              return _EventTile(
                event: event,
                roundCount: counts[event.id] ?? 0,
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

  /// Rounds attached to each event id, keyed by event id (casual rounds — a
  /// null event — are not counted).
  static Map<int, int> _roundCounts(List<RoundWithCourse> rounds) {
    final counts = <int, int>{};
    for (final r in rounds) {
      final id = r.event?.id;
      if (id != null) counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.roundCount});

  final Event event;
  final int roundCount;

  @override
  Widget build(BuildContext context) {
    final subtitle = roundCount == 0
        ? 'No rounds yet'
        : (roundCount == 1 ? '1 round' : '$roundCount rounds');
    return ListTile(
      key: ValueKey('event_tile_${event.id}'),
      leading: const Icon(Icons.emoji_events_outlined),
      title: Text(formatEventTitle(event)),
      subtitle: Text(subtitle),
      trailing:
          hasRecordedResult(event) ? EventResultBadge(event: event) : null,
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (_) => EventDetailScreen(eventId: event.id),
        ),
      ),
    );
  }
}
