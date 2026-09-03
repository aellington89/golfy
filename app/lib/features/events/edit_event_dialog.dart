import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/repository_provider.dart';

/// Modal dialog for editing an existing [event]'s identity — its **name** and
/// **season** (#47). Pops with the updated [Event] on success, or `null` if the
/// user cancels. Mirrors [AddEventDialog].
///
/// An event is identified by `(name, season)`, so both are editable here (a
/// wrong season no longer means delete + recreate). Validates the name is
/// non-empty and the season is an integer ≥ 1, and pre-checks [existingEvents]
/// for another event sharing the new `(name, season)` (name case-insensitive,
/// excluding this event); the schema-level UNIQUE(name, season) constraint is
/// still caught as a safety net for the rare race. The caller supplies the list
/// so the dialog has no live stream dependency — that keeps widget tests free
/// of pending stream timers.
class EditEventDialog extends ConsumerStatefulWidget {
  const EditEventDialog({
    super.key,
    required this.event,
    this.existingEvents = const [],
  });

  final Event event;
  final List<Event> existingEvents;

  @override
  ConsumerState<EditEventDialog> createState() => _EditEventDialogState();
}

class _EditEventDialogState extends ConsumerState<EditEventDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _seasonController;
  String? _nameError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.event.name);
    _seasonController =
        TextEditingController(text: widget.event.season.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _seasonController.dispose();
    super.dispose();
  }

  void _clearNameError() {
    if (_nameError != null) setState(() => _nameError = null);
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final name = _nameController.text.trim();
    final season = int.parse(_seasonController.text.trim());

    // Nothing changed — don't touch the db; close with the original event.
    if (name == widget.event.name && season == widget.event.season) {
      Navigator.of(context).pop(widget.event);
      return;
    }

    final isDuplicate = widget.existingEvents.any((e) =>
        e.id != widget.event.id &&
        e.name.toLowerCase() == name.toLowerCase() &&
        e.season == season);
    if (isDuplicate) {
      setState(() => _nameError = 'Season $season already exists');
      return;
    }

    setState(() {
      _submitting = true;
      _nameError = null;
    });

    try {
      await ref
          .read(repositoryProvider)
          .updateEventDetails(widget.event.id, name: name, season: season);
      if (!mounted) return;
      Navigator.of(context)
          .pop(widget.event.copyWith(name: name, season: season));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _nameError = 'Season $season already exists';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Event'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Event Name',
                errorText: _nameError,
              ),
              textInputAction: TextInputAction.next,
              enabled: !_submitting,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
              onChanged: (_) => _clearNameError(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _seasonController,
              decoration: const InputDecoration(labelText: 'Season'),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              enabled: !_submitting,
              validator: _validateSeason,
              onChanged: (_) => _clearNameError(),
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('edit_event_save'),
          onPressed: _submitting ? null : _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Shared validator for a typed season field: a whole number ≥ 1.
String? _validateSeason(String? v) {
  final n = int.tryParse((v ?? '').trim());
  if (n == null || n < 1) return 'Enter a season of 1 or more';
  return null;
}
