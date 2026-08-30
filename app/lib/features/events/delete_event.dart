import 'package:flutter/material.dart';

/// Shows the "Delete event?" confirmation dialog and resolves to whether the
/// user tapped Delete. Deleting an event is **non-destructive to rounds**: the
/// event's rounds are kept and detached to "No event" (the schema clears their
/// `event_id` via `ON DELETE SET NULL` — see `EventDao.deleteById`), so the
/// copy spells that out. The caller performs the actual delete
/// (`repo.deleteEvent`) once this resolves true. [roundCount] tailors the copy.
Future<bool> confirmDeleteEvent(
  BuildContext context, {
  required String eventName,
  required int roundCount,
}) async {
  final rounds = roundCount == 1 ? '1 round' : '$roundCount rounds';
  final body = roundCount == 0
      ? 'This will delete the event "$eventName". It has no rounds.'
      : 'This will delete the event "$eventName". Its $rounds will be kept and '
          'moved to "No event" — no round or hole data is deleted.';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete event?'),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
