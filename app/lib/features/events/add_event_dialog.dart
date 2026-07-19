import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/repository_provider.dart';

/// Modal dialog for adding a new event. Pops with the newly-inserted [Event]
/// on success, or `null` if the user cancels. Mirrors [AddCourseDialog].
///
/// Validates that Name is non-empty and pre-checks [existingEvents] for a
/// duplicate name (case-insensitive); the schema-level UNIQUE constraint on
/// `events.name` is still caught as a safety net for the rare race. The caller
/// supplies the list so the dialog has no live stream dependency — that keeps
/// widget tests free of pending stream timers.
class AddEventDialog extends ConsumerStatefulWidget {
  const AddEventDialog({super.key, this.existingEvents = const []});

  final List<Event> existingEvents;

  @override
  ConsumerState<AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends ConsumerState<AddEventDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _nameError;
  bool _submitting = false;

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

    final isDuplicate = widget.existingEvents
        .any((e) => e.name.toLowerCase() == name.toLowerCase());
    if (isDuplicate) {
      setState(() => _nameError = 'Event already exists');
      return;
    }

    setState(() {
      _submitting = true;
      _nameError = null;
    });

    try {
      final repo = ref.read(repositoryProvider);
      final id = await repo.insertEvent(EventsCompanion.insert(name: name));
      if (!mounted) return;
      Navigator.of(context).pop(
        Event(id: id, name: name, tied: false, missedCut: false),
      );
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
      title: const Text('Add Event'),
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
          onPressed: _submitting ? null : _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
