import 'package:flutter/material.dart';

import 'hole_draft.dart';

/// Form for a single hole's entry. Stateless w.r.t. the draft data — the
/// parent owns the [HoleDraft] map and pushes a fresh card each rebuild.
/// The only local state is the `ExpansionTile` open flag for the notes
/// row.
///
/// Conditional resets enforced here mirror the three DAO invariants in
/// `hole_result_dao.dart::_assertInvariants` so the upsert can't throw:
///
///  * `par == 3` → fairwayHit forced to `null`
///  * `upDownAttempt == false` → upDownSuccess forced to `false`
///  * `bunkerVisited == false` → sandSave forced to `false`
class HoleCard extends StatefulWidget {
  const HoleCard({
    super.key,
    required this.holeNumber,
    required this.draft,
    required this.savedDraft,
    required this.onChanged,
    required this.onSave,
    this.onPrev,
    this.onNext,
  });

  final int holeNumber;
  final HoleDraft draft;

  /// The last persisted draft for this hole, or `null` if the hole has
  /// never been saved. Used to render the "Saved" indicator and to decide
  /// whether the current draft has unsaved changes.
  final HoleDraft? savedDraft;

  final ValueChanged<HoleDraft> onChanged;
  final VoidCallback onSave;

  /// Navigates to the previous / next hole in the parent's PageView.
  /// `null` means "no neighbour in that direction" (hole 1 / hole 18) and
  /// the corresponding chevron renders disabled.
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  bool get isSaved => savedDraft != null;
  bool get isDirty => savedDraft == null || savedDraft != draft;

  @override
  State<HoleCard> createState() => _HoleCardState();
}

class _HoleCardState extends State<HoleCard> {
  bool _notesExpanded = false;

  @override
  void initState() {
    super.initState();
    _notesExpanded = widget.draft.notes.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = widget.draft;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'Hole ${widget.holeNumber}',
                    style: theme.textTheme.titleLarge,
                  ),
                  const Spacer(),
                  if (widget.isSaved && !widget.isDirty)
                    Chip(
                      avatar: Icon(
                        Icons.check_circle,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      label: const Text('Saved'),
                      visualDensity: VisualDensity.compact,
                    )
                  else if (widget.isSaved && widget.isDirty)
                    Chip(
                      avatar: Icon(
                        Icons.edit,
                        size: 18,
                        color: theme.colorScheme.tertiary,
                      ),
                      label: const Text('Unsaved'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _ParRow(
                par: d.par,
                onChanged: (newPar) {
                  // Switching to par 3 wipes fairwayHit — par 3s have no
                  // fairway and the DAO will throw otherwise.
                  widget.onChanged(d.copyWith(
                    par: newPar,
                    score: d.score < 1 ? 1 : d.score,
                    fairwayHit: newPar == 3 ? null : d.fairwayHit,
                  ));
                },
              ),
              const SizedBox(height: 12),
              _StepperRow(
                key: const ValueKey('score'),
                label: 'Score',
                value: d.score,
                min: 1,
                onChanged: (v) => widget.onChanged(d.copyWith(score: v)),
              ),
              const SizedBox(height: 12),
              _FairwayRow(
                value: d.fairwayHit,
                disabled: d.par == 3,
                onChanged: (v) =>
                    widget.onChanged(d.copyWith(fairwayHit: v)),
              ),
              const SizedBox(height: 4),
              _SwitchRow(
                label: 'GIR',
                value: d.gir,
                onChanged: (v) => widget.onChanged(d.copyWith(gir: v)),
              ),
              const SizedBox(height: 8),
              _StepperRow(
                key: const ValueKey('putts'),
                label: 'Putts',
                value: d.putts,
                min: 0,
                onChanged: (v) => widget.onChanged(d.copyWith(putts: v)),
              ),
              const SizedBox(height: 12),
              _SwitchRow(
                label: 'Up/Down attempt',
                value: d.upDownAttempt,
                onChanged: (v) {
                  // Turning attempt off cancels any recorded success — the
                  // DAO won't accept success=true without attempt=true.
                  widget.onChanged(d.copyWith(
                    upDownAttempt: v,
                    upDownSuccess: v ? d.upDownSuccess : false,
                  ));
                },
              ),
              _SwitchRow(
                label: 'Up/Down success',
                value: d.upDownSuccess,
                enabled: d.upDownAttempt,
                onChanged: (v) =>
                    widget.onChanged(d.copyWith(upDownSuccess: v)),
              ),
              const SizedBox(height: 8),
              _SwitchRow(
                label: 'Bunker visited',
                value: d.bunkerVisited,
                onChanged: (v) {
                  widget.onChanged(d.copyWith(
                    bunkerVisited: v,
                    sandSave: v ? d.sandSave : false,
                  ));
                },
              ),
              _SwitchRow(
                label: 'Sand save',
                value: d.sandSave,
                enabled: d.bunkerVisited,
                onChanged: (v) => widget.onChanged(d.copyWith(sandSave: v)),
              ),
              const SizedBox(height: 12),
              _StepperRow(
                key: const ValueKey('penalty'),
                label: 'Penalty strokes',
                value: d.penaltyStrokes,
                min: 0,
                onChanged: (v) =>
                    widget.onChanged(d.copyWith(penaltyStrokes: v)),
              ),
              const SizedBox(height: 12),
              _NotesSection(
                value: d.notes,
                expanded: _notesExpanded,
                onExpansionChanged: (open) =>
                    setState(() => _notesExpanded = open),
                onChanged: (v) => widget.onChanged(d.copyWith(notes: v)),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  IconButton.filledTonal(
                    key: const ValueKey('hole_prev'),
                    onPressed: widget.onPrev,
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous hole',
                  ),
                  Expanded(
                    child: Center(
                      child: FilledButton.icon(
                        onPressed: widget.onSave,
                        icon: const Icon(Icons.save),
                        label: const Text('Save Hole'),
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    key: const ValueKey('hole_next'),
                    onPressed: widget.onNext,
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next hole',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParRow extends StatelessWidget {
  const _ParRow({required this.par, required this.onChanged});

  final int par;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Par',
        border: OutlineInputBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 3, label: Text('3')),
            ButtonSegment(value: 4, label: Text('4')),
            ButtonSegment(value: 5, label: Text('5')),
          ],
          selected: {par},
          onSelectionChanged: (sel) => onChanged(sel.first),
        ),
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      child: Row(
        children: [
          IconButton(
            key: ValueKey('${label}_dec'),
            onPressed: value <= min ? null : () => onChanged(value - 1),
            icon: const Icon(Icons.remove),
          ),
          Expanded(
            child: Center(
              child: Text(
                '$value',
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
          IconButton(
            key: ValueKey('${label}_inc'),
            onPressed: () => onChanged(value + 1),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _FairwayRow extends StatelessWidget {
  const _FairwayRow({
    required this.value,
    required this.disabled,
    required this.onChanged,
  });

  final bool? value;
  final bool disabled;
  final ValueChanged<bool?> onChanged;

  // `null` is the "N/A" selection. SegmentedButton can't hold a null in
  // its Set<T>, so we map null to a sentinel int and back.
  static const int _yes = 1;
  static const int _no = 0;
  static const int _na = -1;

  int _encode(bool? v) {
    if (v == null) return _na;
    return v ? _yes : _no;
  }

  bool? _decode(int v) {
    if (v == _na) return null;
    return v == _yes;
  }

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: disabled ? 'Fairway hit (N/A on par 3)' : 'Fairway hit',
        border: const OutlineInputBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: _yes, label: Text('Yes')),
            ButtonSegment(value: _no, label: Text('No')),
            ButtonSegment(value: _na, label: Text('N/A')),
          ],
          selected: {disabled ? _na : _encode(value)},
          onSelectionChanged:
              disabled ? null : (sel) => onChanged(_decode(sel.first)),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(label),
      value: value,
      onChanged: enabled ? onChanged : null,
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _NotesSection extends StatelessWidget {
  const _NotesSection({
    required this.value,
    required this.expanded,
    required this.onExpansionChanged,
    required this.onChanged,
  });

  final String value;
  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Theme(
      // Suppress the default divider lines on ExpansionTile so it sits
      // cleanly inside the card.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: const Text('Notes'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        initiallyExpanded: expanded,
        onExpansionChanged: onExpansionChanged,
        children: [
          TextFormField(
            initialValue: value,
            maxLines: 3,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Optional',
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
