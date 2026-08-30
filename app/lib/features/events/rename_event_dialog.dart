import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/repository_provider.dart';

/// Modal dialog for renaming an existing [event]. Pops with the updated [Event]
/// on success, or `null` if the user cancels. Mirrors [AddEventDialog].
///
/// Validates that the name is non-empty and pre-checks [existingEvents] for a
/// duplicate name (case-insensitive, excluding this event); the schema-level
/// UNIQUE constraint on `events.name` is still caught as a safety net for the
/// rare race. The caller supplies the list so the dialog has no live stream
/// dependency — that keeps widget tests free of pending stream timers.
class RenameEventDialog extends ConsumerStatefulWidget {
  const RenameEventDialog({
    super.key,
    required this.event,
    this.existingEvents = const [],
  });

  final Event event;
  final List<Event> existingEvents;

  @override
  ConsumerState<RenameEventDialog> createState() => _RenameEventDialogState();
}

class _RenameEventDialogState extends ConsumerState<RenameEventDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  String? _nameError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.event.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _clearNameError() {
    if (_nameError != null) setState(() => _nameError = null);
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final name = _nameController.text.trim();

    // Unchanged name — nothing to persist; just close with the original event.
    if (name == widget.event.name) {
      Navigator.of(context).pop(widget.event);
      return;
    }

    final isDuplicate = widget.existingEvents.any((e) =>
        e.id != widget.event.id &&
        e.name.toLowerCase() == name.toLowerCase());
    if (isDuplicate) {
      setState(() => _nameError = 'Event already exists');
      return;
    }

    setState(() {
      _submitting = true;
      _nameError = null;
    });

    try {
      await ref.read(repositoryProvider).renameEvent(widget.event.id, name);
      if (!mounted) return;
      Navigator.of(context).pop(widget.event.copyWith(name: name));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _nameError = 'Event already exists';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename Event'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Event Name',
                errorText: _nameError,
              ),
              textInputAction: TextInputAction.done,
              enabled: !_submitting,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
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
          key: const ValueKey('rename_event_save'),
          onPressed: _submitting ? null : _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
