import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/repository_provider.dart';

/// Modal dialog for adding a new event. Pops with the newly-inserted [Event]
/// on success, or `null` if the user cancels. Mirrors [AddCourseDialog].
///
/// An event is identified by `(name, season)` — the same name recurs each
/// season as a distinct occurrence (#47) — so the dialog collects a season (a
/// 1-based number, default 1) alongside the name. When the typed name matches
/// an existing event, the season auto-advances to the next unused one (unless
/// the user has stepped it), so logging "next season" of an existing event is
/// one tap.
///
/// Validates that Name is non-empty and pre-checks [existingEvents] for a
/// duplicate `(name, season)` (name case-insensitive); the schema-level
/// UNIQUE(name, season) constraint is still caught as a safety net for the rare
/// race. The caller supplies the list so the dialog has no live stream
/// dependency — that keeps widget tests free of pending stream timers.
class AddEventDialog extends ConsumerStatefulWidget {
  const AddEventDialog({super.key, this.existingEvents = const []});

  final List<Event> existingEvents;

  @override
  ConsumerState<AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends ConsumerState<AddEventDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _seasonController = TextEditingController(text: '1');
  String? _nameError;
  bool _submitting = false;

  /// True once the user edits the season field by hand — after which the typed
  /// season is left alone rather than auto-advanced on name changes.
  bool _userEditedSeason = false;

  @override
  void dispose() {
    _nameController.dispose();
    _seasonController.dispose();
    super.dispose();
  }

  void _clearNameError() {
    if (_nameError != null) setState(() => _nameError = null);
  }

  /// The next unused season for [name] among [AddEventDialog.existingEvents]
  /// (case-insensitive): `max(existing seasons) + 1`, or 1 when the name is new.
  int _nextSeasonFor(String name) {
    final lower = name.trim().toLowerCase();
    if (lower.isEmpty) return 1;
    var max = 0;
    for (final e in widget.existingEvents) {
      if (e.name.toLowerCase() == lower && e.season > max) max = e.season;
    }
    return max + 1;
  }

  void _onNameChanged(String value) {
    // Auto-advance the season to the next unused one for this name, unless the
    // user has taken over the field. Setting `.text` doesn't fire the season
    // field's onChanged, so this never trips [_userEditedSeason].
    if (!_userEditedSeason) {
      final suggested = _nextSeasonFor(value).toString();
      if (_seasonController.text != suggested) {
        _seasonController.text = suggested;
      }
    }
    _clearNameError();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final name = _nameController.text.trim();
    final season = int.parse(_seasonController.text.trim());

    final isDuplicate = widget.existingEvents.any(
      (e) => e.name.toLowerCase() == name.toLowerCase() && e.season == season,
    );
    if (isDuplicate) {
      setState(() => _nameError = 'Season $season already exists');
      return;
    }

    setState(() {
      _submitting = true;
      _nameError = null;
    });

    try {
      final repo = ref.read(repositoryProvider);
      final id = await repo.insertEvent(
        EventsCompanion.insert(name: name, season: Value(season)),
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        Event(
          id: id,
          name: name,
          season: season,
          tied: false,
          missedCut: false,
        ),
      );
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
      title: const Text('Add Event'),
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
              onChanged: _onNameChanged,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _seasonController,
              decoration: const InputDecoration(labelText: 'Season'),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              enabled: !_submitting,
              validator: _validateSeason,
              onChanged: (_) {
                _userEditedSeason = true;
                _clearNameError();
              },
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

/// Shared validator for a typed season field: a whole number ≥ 1.
String? _validateSeason(String? v) {
  final n = int.tryParse((v ?? '').trim());
  if (n == null || n < 1) return 'Enter a season of 1 or more';
  return null;
}
