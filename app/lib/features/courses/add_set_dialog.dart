import 'package:flutter/material.dart';

/// Which kind of set a dialog creates or renames.
///
/// A **tee set** is a tee box, with course yards per hole; a **pin set** is a
/// set of pin positions, with no yardage of its own. A round's yardage set is
/// one of each.
enum CourseSetKind {
  tee('tee set', 'Tee set name', 'e.g. Blue, Championship'),
  pin('pin set', 'Pin set name', 'e.g. Sunday pins, Tournament day 1');

  const CourseSetKind(this.noun, this.label, this.hint);

  /// "tee set" / "pin set", for messages.
  final String noun;
  final String label;
  final String hint;
}

/// A set already on the course, as the dialogs need it: an id to copy from and
/// a name to clash with.
typedef ExistingSet = ({int id, String name});

/// What [AddSetDialog] returns: the new set's name plus, for a tee set,
/// optionally an existing tee set to copy course yards from and a flat
/// adjustment to apply.
class NewCourseSet {
  const NewCourseSet({
    required this.name,
    this.copyFromSetId,
    this.offsetYards = 0,
  });

  final String name;
  final int? copyFromSetId;
  final int offsetYards;
}

/// Creates a tee set or a pin set (#81).
///
/// A tee set can be seeded from one that already exists: tee boxes on the same
/// course are highly correlated, so "the blues, minus 20" beats retyping
/// eighteen numbers. The offset is only an approximation — real tee boxes
/// differ hole by hole — so the caller seeds the result into the editor as
/// *unsaved* changes rather than writing it, and nothing numeric reaches the
/// database until a human has looked at it. A pin set has no yards of its own
/// to copy: its tee-to-pin yards are entered per tee set.
class AddSetDialog extends StatefulWidget {
  const AddSetDialog({
    super.key,
    required this.kind,
    this.existing = const [],
  });

  final CourseSetKind kind;

  /// Sets of [kind] already on this course — checked for a clashing name and,
  /// for tee sets, offered as copy sources. Passed in rather than watched so
  /// the dialog stays free of pending streams in widget tests.
  final List<ExistingSet> existing;

  @override
  State<AddSetDialog> createState() => _AddSetDialogState();
}

class _AddSetDialogState extends State<AddSetDialog> {
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
      setState(() => _nameError = 'Give the ${widget.kind.noun} a name');
      return;
    }
    if (widget.existing
        .any((s) => s.name.toLowerCase() == name.toLowerCase())) {
      setState(
          () => _nameError = 'A ${widget.kind.noun} with that name exists');
      return;
    }
    Navigator.of(context).pop(NewCourseSet(
      name: name,
      copyFromSetId: _copyFromSetId,
      offsetYards:
          _copyFromSetId == null ? 0 : (int.tryParse(_offset.text.trim()) ?? 0),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final canCopy =
        widget.kind == CourseSetKind.tee && widget.existing.isNotEmpty;
    return AlertDialog(
      title: Text('Add ${widget.kind.noun}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('set_name'),
            controller: _name,
            autofocus: true,
            decoration: InputDecoration(
              labelText: widget.kind.label,
              hintText: widget.kind.hint,
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
              key: const ValueKey('set_copy_from'),
              initialValue: _copyFromSetId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Copy course yards from',
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Start blank'),
                ),
                for (final s in widget.existing)
                  DropdownMenuItem<int?>(value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) => setState(() => _copyFromSetId = v),
            ),
            if (_copyFromSetId != null) ...[
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('set_offset'),
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
          key: const ValueKey('set_add'),
          onPressed: _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

/// Prompts for a (non-empty, trimmed) set name, or null on cancel. Used for
/// renaming; creating goes through [AddSetDialog].
Future<String?> promptSetName(
  BuildContext context, {
  required CourseSetKind kind,
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
          decoration: InputDecoration(
            labelText: kind.label,
            hintText: kind.hint,
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
