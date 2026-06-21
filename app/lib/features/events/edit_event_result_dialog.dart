import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/repository_provider.dart';

/// Dialog to record or edit an [Event]'s result (#35): a finishing position
/// with an optional "Tied" flag, or "Missed cut" (mutually exclusive with a
/// position). Clearing the position and leaving both switches off records
/// "no result yet". Saving persists via the repository; the rounds stream
/// re-emits and the grouped list's result badge updates.
class EditEventResultDialog extends ConsumerStatefulWidget {
  const EditEventResultDialog({super.key, required this.event});

  final Event event;

  @override
  ConsumerState<EditEventResultDialog> createState() =>
      _EditEventResultDialogState();
}

class _EditEventResultDialogState extends ConsumerState<EditEventResultDialog> {
  late final TextEditingController _positionController;
  late bool _tied;
  late bool _missedCut;
  bool _submitting = false;
  String? _positionError;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _positionController =
        TextEditingController(text: e.finishPosition?.toString() ?? '');
    _tied = e.tied;
    _missedCut = e.missedCut;
  }

  @override
  void dispose() {
    _positionController.dispose();
    super.dispose();
  }

  void _onMissedCutChanged(bool value) {
    setState(() {
      _missedCut = value;
      if (value) {
        // A cut and a finishing position are mutually exclusive.
        _positionController.clear();
        _tied = false;
        _positionError = null;
      }
    });
  }

  Future<void> _submit() async {
    int? position;
    if (!_missedCut) {
      final raw = _positionController.text.trim();
      if (raw.isNotEmpty) {
        position = int.tryParse(raw);
        if (position == null || position < 1) {
          setState(() => _positionError = 'Enter a position of 1 or higher');
          return;
        }
      }
    }
    if (_tied && position == null) {
      setState(() => _positionError = 'A tie needs a finishing position');
      return;
    }

    setState(() {
      _submitting = true;
      _positionError = null;
    });

    try {
      await ref.read(repositoryProvider).setEventResult(
            widget.event.id,
            finishPosition: _missedCut ? null : position,
            tied: _missedCut ? false : _tied,
            missedCut: _missedCut,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _positionError = 'Failed to save result: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.event.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('event_position_field'),
            controller: _positionController,
            enabled: !_submitting && !_missedCut,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Finish position',
              hintText: 'e.g. 1 for a win',
              border: const OutlineInputBorder(),
              errorText: _positionError,
            ),
            onChanged: (_) {
              if (_positionError != null) {
                setState(() => _positionError = null);
              }
            },
          ),
          SwitchListTile(
            key: const ValueKey('event_tied_switch'),
            title: const Text('Tied'),
            subtitle: const Text('Shared finish (renders "T-3")'),
            value: _tied,
            onChanged: _submitting || _missedCut
                ? null
                : (v) => setState(() => _tied = v),
          ),
          SwitchListTile(
            key: const ValueKey('event_missed_cut_switch'),
            title: const Text('Missed cut'),
            value: _missedCut,
            onChanged: _submitting ? null : _onMissedCutChanged,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('event_result_save'),
          onPressed: _submitting ? null : _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
