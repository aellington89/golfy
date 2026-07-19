import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/repository_provider.dart';
import 'add_event_dialog.dart';

/// Controlled event picker: parent owns the selected [Event] and supplies
/// [value] + [onChanged]. Tapping the field opens a modal sheet listing all
/// events (sorted alphabetically by name). Because an event is optional, the
/// first row is "No event / Casual round" (selects `null`); the last entry is
/// "+ Add new event…" which launches [AddEventDialog] and selects the
/// newly-created event on success. Mirrors [CoursePicker].
class EventPicker extends ConsumerWidget {
  const EventPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.labelText = 'Event (optional)',
  });

  final Event? value;
  final ValueChanged<Event?> onChanged;
  final String labelText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsStreamProvider);
    final theme = Theme.of(context);

    final field = InputDecorator(
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.arrow_drop_down),
      ),
      child: Text(
        value?.name ?? 'No event (casual round)',
        style: value == null
            ? theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )
            : theme.textTheme.bodyLarge,
      ),
    );

    return eventsAsync.when(
      loading: () => AbsorbPointer(child: field),
      error: (e, _) => InputDecorator(
        decoration: InputDecoration(
          labelText: labelText,
          border: const OutlineInputBorder(),
        ),
        child: Text(
          'Could not load events',
          style: TextStyle(color: theme.colorScheme.error),
        ),
      ),
      data: (events) => InkWell(
        onTap: () => _openPicker(context, events),
        borderRadius: BorderRadius.circular(4),
        child: field,
      ),
    );
  }

  Future<void> _openPicker(BuildContext context, List<Event> events) async {
    final result = await showModalBottomSheet<_PickerResult>(
      context: context,
      showDragHandle: true,
      builder: (_) => _EventPickerSheet(
        events: events,
        selectedId: value?.id,
      ),
    );

    if (result == null) return;

    if (result.addNew) {
      if (!context.mounted) return;
      final newEvent = await showDialog<Event>(
        context: context,
        builder: (_) => AddEventDialog(existingEvents: events),
      );
      if (newEvent != null) onChanged(newEvent);
      return;
    }

    // Both a picked event and the "No event" clear row flow through here —
    // `result.event` is null for the clear row.
    onChanged(result.event);
  }
}

class _PickerResult {
  const _PickerResult.event(this.event) : addNew = false;
  const _PickerResult.clear()
      : event = null,
        addNew = false;
  const _PickerResult.addNew()
      : event = null,
        addNew = true;

  final Event? event;
  final bool addNew;
}

class _EventPickerSheet extends StatelessWidget {
  const _EventPickerSheet({
    required this.events,
    required this.selectedId,
  });

  final List<Event> events;
  final int? selectedId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const Icon(Icons.golf_course_outlined),
            title: const Text('No event / Casual round'),
            trailing: selectedId == null ? const Icon(Icons.check) : null,
            onTap: () =>
                Navigator.of(context).pop(const _PickerResult.clear()),
          ),
          const Divider(height: 0),
          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('No events yet — add one below.'),
            ),
          for (final e in events)
            ListTile(
              title: Text(e.name),
              trailing: e.id == selectedId ? const Icon(Icons.check) : null,
              onTap: () =>
                  Navigator.of(context).pop(_PickerResult.event(e)),
            ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Add new event…'),
            onTap: () =>
                Navigator.of(context).pop(const _PickerResult.addNew()),
          ),
        ],
      ),
    );
  }
}
