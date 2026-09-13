import 'package:flutter/material.dart';

import '../../data/database.dart';

/// What [AddYardageSetDialog] returns: the new set's name plus, optionally, an
/// existing set to copy yardages from and a flat adjustment to apply.
class NewYardageSet {
  const NewYardageSet({
    required this.name,
    this.copyFromSetId,
    this.offsetYards = 0,
  });

  final String name;
  final int? copyFromSetId;
  final int offsetYards;
}

/// Creates a yardage set — a tee box or pin set — optionally seeded from one
/// that already exists (#81).
///
/// Tee boxes on the same course are highly correlated, so "the blues, minus 20"
/// beats retyping eighteen numbers. The offset is only an approximation — real
/// tee boxes differ hole by hole — so the caller seeds the result into the
/// editor as *unsaved* changes rather than writing it, and nothing numeric
/// reaches the database until a human has looked at it.
class AddYardageSetDialog extends StatefulWidget {
  const AddYardageSetDialog({super.key, this.existingSets = const []});

  /// Sets already on this course, offered as copy sources. Passed in rather than
  /// watched so the dialog stays free of pending streams in widget tests.
  final List<CourseSet> existingSets;

  @override
  State<AddYardageSetDialog> createState() => _AddYardageSetDialogState();
}

class _AddYardageSetDialogState extends State<AddYardageSetDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _offset = TextEditingController(text: '0');
  int? _copyFromSetId;
  String? _nameError;

  @override
  void dispose() {
    _name.dispose();
    _offset.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Give the set a name');
      return;
    }
    if (widget.existingSets
        .any((s) => s.name.toLowerCase() == name.toLowerCase())) {
      setState(() => _nameError = 'A set with that name already exists');
      return;
    }
    Navigator.of(context).pop(NewYardageSet(
      name: name,
      copyFromSetId: _copyFromSetId,
      offsetYards:
          _copyFromSetId == null ? 0 : (int.tryParse(_offset.text.trim()) ?? 0),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final canCopy = widget.existingSets.isNotEmpty;
    return AlertDialog(
      title: const Text('Add yardage set'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('yardage_set_name'),
            controller: _name,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Set name',
              hintText: 'e.g. Blue tees, Sunday pins',
              errorText: _nameError,
            ),
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
            onSubmitted: (_) => _submit(),
          ),
          if (canCopy) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              key: const ValueKey('yardage_set_copy_from'),
              initialValue: _copyFromSetId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Copy yardages from',
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Start blank'),
                ),
                for (final s in widget.existingSets)
                  DropdownMenuItem<int?>(value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) => setState(() => _copyFromSetId = v),
            ),
            if (_copyFromSetId != null) ...[
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('yardage_set_offset'),
                controller: _offset,
                keyboardType:
                    const TextInputType.numberWithOptions(signed: true),
                decoration: const InputDecoration(
                  labelText: 'Adjust every hole by',
                  helperText: 'e.g. -20 for a shorter tee box',
                  suffixText: 'yds',
                  isDense: true,
                ),
              ),
            ],
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('yardage_set_add'),
          onPressed: _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

/// Prompts for a (non-empty, trimmed) yardage-set name, or null on cancel. Used
/// for renaming; creating goes through [AddYardageSetDialog].
Future<String?> promptSetName(
  BuildContext context, {
  required String title,
  String? initial,
}) async {
  final controller = TextEditingController(text: initial ?? '');
  try {
    return await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Set name',
            hintText: 'e.g. Blue tees, Sunday pins',
          ),
          onSubmitted: (_) {
            final t = controller.text.trim();
            Navigator.of(ctx).pop(t.isEmpty ? null : t);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final t = controller.text.trim();
              Navigator.of(ctx).pop(t.isEmpty ? null : t);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
}
