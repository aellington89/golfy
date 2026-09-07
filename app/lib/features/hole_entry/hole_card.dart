import 'package:flutter/material.dart';

import 'hole_draft.dart';

/// Form for a single hole's entry. Stateless w.r.t. the draft data — the
/// parent owns the [HoleDraft] map and pushes a fresh card each rebuild.
/// The only local state is the `ExpansionTile` open flag for the notes
/// row.
///
/// Fields are grouped into stage sections (Tee → Approach & Around the
/// Green → Putting → Score) following the order a golfer learns each value
/// during play, so Score is entered last once the hole is complete (#34).
///
/// Conditional resets and bounds enforced here mirror the DAO invariants in
/// `hole_result_dao.dart::_assertInvariants` so the upsert can't throw:
///
///  * `par == 3` → fairwayHit forced to `null`
///  * `upDownAttempt == false` → upDownSuccess forced to `false`
///  * `putts > 1` → upDownSuccess forced to `false` (an up & down is a 1-putt)
///  * `bunkerVisited == false` → sandSave forced to `false`
///  * putts is capped at `score - 1` and score floored at `putts + 1` (the tee
///    shot is never a putt)
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

  /// Controller for the free-entry yards field. Kept in state (rather than a
  /// `TextFormField.initialValue`) so an auto-fill that arrives after the first
  /// build — the course template stream emitting `yards` — updates the field,
  /// while active typing is never clobbered. A `0` shows as empty so an
  /// un-set / template-less hole reads blank rather than a misleading "0".
  late final TextEditingController _yardsController;

  @override
  void initState() {
    super.initState();
    _notesExpanded = widget.draft.notes.isNotEmpty;
    _yardsController = TextEditingController(text: _yardsText(widget.draft.yards));
  }

  static String _yardsText(int yards) => yards == 0 ? '' : yards.toString();

  @override
  void didUpdateWidget(covariant HoleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync the field only when the incoming yards differ from what's already
    // shown — e.g. the template auto-fill landing — so we don't fight the
    // cursor while the user is typing (a self-originated change round-trips to
    // the same value and is a no-op here).
    final incoming = widget.draft.yards;
    final shown = int.tryParse(_yardsController.text) ?? 0;
    if (incoming != shown) {
      _yardsController.text = _yardsText(incoming);
    }
  }

  @override
  void dispose() {
    _yardsController.dispose();
    super.dispose();
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
              const _SectionHeader('Tee'),
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
              _YardsRow(
                controller: _yardsController,
                onChanged: (v) {
                  // Numeric keyboard + a >= 0 floor mirror the `yards >= 0`
                  // CHECK; an empty field means "unknown" and stores 0.
                  final yards = (int.tryParse(v) ?? 0).clamp(0, 100000);
                  widget.onChanged(d.copyWith(yards: yards));
                },
              ),
              const SizedBox(height: 12),
              _FairwayRow(
                value: d.fairwayHit,
                disabled: d.par == 3,
                onChanged: (v) =>
                    widget.onChanged(d.copyWith(fairwayHit: v)),
              ),
              const _SectionHeader('Approach & Around the Green'),
              _SwitchRow(
                label: 'GIR',
                value: d.gir,
                onChanged: (v) => widget.onChanged(d.copyWith(gir: v)),
              ),
              const SizedBox(height: 8),
              _SwitchRow(
                label: 'Up/Down attempt',
                value: d.upDownAttempt,
                onChanged: (v) {
                  // Turning attempt off cancels any recorded success — the
                  // DAO won't accept success=true without attempt=true. The
                  // success toggle itself lives in the Score section below.
                  widget.onChanged(d.copyWith(
                    upDownAttempt: v,
                    upDownSuccess: v ? d.upDownSuccess : false,
                  ));
                },
              ),
              const SizedBox(height: 8),
              _SwitchRow(
                label: 'Bunker visited',
                value: d.bunkerVisited,
                onChanged: (v) {
                  // Its success half (sand save) lives in the Score section.
                  widget.onChanged(d.copyWith(
                    bunkerVisited: v,
                    sandSave: v ? d.sandSave : false,
                  ));
                },
              ),
              const _SectionHeader('Putting'),
              _StepperRow(
                key: const ValueKey('putts'),
                label: 'Putts',
                value: d.putts,
                min: 0,
                // Putts can't reach the score — the tee shot is never a putt.
                max: d.score - 1,
                onChanged: (v) => widget.onChanged(d.copyWith(
                  putts: v,
                  // An up & down is a 1-putt (or chip-in); 2+ putts can't be a
                  // recorded success, and the DAO would reject it.
                  upDownSuccess: v > 1 ? false : d.upDownSuccess,
                )),
              ),
              const _SectionHeader('Score'),
              // Up/down success and sand save are scoring outcomes known only
              // once the hole is done, so they sit here with the tally — their
              // enabling toggles (attempt / bunker) stay in the Approach group.
              _SwitchRow(
                label: 'Up/Down success',
                value: d.upDownSuccess,
                enabled: d.upDownAttempt && d.putts <= 1,
                disabledReason:
                    d.upDownAttempt && d.putts > 1 ? 'N/A — 2+ putts' : null,
                onChanged: (v) =>
                    widget.onChanged(d.copyWith(upDownSuccess: v)),
              ),
              _SwitchRow(
                label: 'Sand save',
                value: d.sandSave,
                enabled: d.bunkerVisited,
                onChanged: (v) => widget.onChanged(d.copyWith(sandSave: v)),
              ),
              const SizedBox(height: 8),
              _StepperRow(
                key: const ValueKey('penalty'),
                label: 'Penalty strokes',
                value: d.penaltyStrokes,
                min: 0,
                onChanged: (v) =>
                    widget.onChanged(d.copyWith(penaltyStrokes: v)),
              ),
              const SizedBox(height: 12),
              _StepperRow(
                key: const ValueKey('score'),
                label: 'Score',
                value: d.score,
                // Score must exceed putts — at least the tee shot isn't a putt.
                min: d.putts + 1,
                onChanged: (v) => widget.onChanged(d.copyWith(score: v)),
              ),
              const _SectionHeader('Shots'),
              _ShotsSection(
                shots: d.shots,
                onShotsChanged: (list) =>
                    widget.onChanged(d.copyWith(shots: list)),
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

/// A stage sub-header ("Tee", "Approach & Around the Green", "Putting",
/// "Score") that labels each group of fields. Purely visual — it makes the
/// play-order sequence explicit and carries its own top spacing so sections
/// are separated without extra `SizedBox`es around it.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
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

/// Free-entry field for the hole's length. A plain [TextField] (driven by a
/// parent-owned controller) rather than a stepper — yardages span a wide range,
/// so tapping +/- hundreds of times would be absurd. Auto-filled from the
/// course template when one exists (#36) and freely editable per round.
class _YardsRow extends StatelessWidget {
  const _YardsRow({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('yards'),
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Yards',
        border: OutlineInputBorder(),
        hintText: 'e.g. 420',
        suffixText: 'yds',
      ),
      onChanged: onChanged,
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
    this.max,
  });

  final String label;
  final int value;
  final int min;

  /// Optional upper bound; the increment button disables once `value` reaches
  /// it. `null` means unbounded (the default for penalty strokes).
  final int? max;
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
            onPressed: (max != null && value >= max!)
                ? null
                : () => onChanged(value + 1),
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
    this.disabledReason,
  });

  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  /// Optional note shown as the tile subtitle while the row is disabled,
  /// explaining why (e.g. "N/A — 2+ putts"). Ignored when enabled.
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(label),
      subtitle:
          !enabled && disabledReason != null ? Text(disabledReason!) : null,
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

/// The ordered per-hole shot list (#22): one [_ShotRow] per shot plus an
/// "Add shot" button. Stateless w.r.t. the data — the parent owns the list and
/// gets a whole new list on any add / edit / delete.
class _ShotsSection extends StatelessWidget {
  const _ShotsSection({required this.shots, required this.onShotsChanged});

  final List<ShotDraft> shots;
  final ValueChanged<List<ShotDraft>> onShotsChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < shots.length; i++)
          _ShotRow(
            key: ValueKey('shot_row_$i'),
            index: i,
            shot: shots[i],
            onChanged: (s) {
              final next = [...shots];
              next[i] = s;
              onShotsChanged(next);
            },
            onDelete: () => onShotsChanged([...shots]..removeAt(i)),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('add_shot'),
            onPressed: () => onShotsChanged([...shots, const ShotDraft()]),
            icon: const Icon(Icons.add),
            label: const Text('Add shot'),
          ),
        ),
      ],
    );
  }
}

/// One shot's editable row: club + distance (free entry) and lie + result
/// (small preset dropdowns), with a delete action. The text fields are backed
/// by controllers synced in [didUpdateWidget] so a value that changes from the
/// outside (e.g. a deleted earlier shot shifting this row's data up) refreshes
/// without clobbering active typing.
class _ShotRow extends StatefulWidget {
  const _ShotRow({
    super.key,
    required this.index,
    required this.shot,
    required this.onChanged,
    required this.onDelete,
  });

  final int index;
  final ShotDraft shot;
  final ValueChanged<ShotDraft> onChanged;
  final VoidCallback onDelete;

  /// Standard bag, longest to shortest. Stored as text, so a value outside this
  /// list still round-trips (the dropdown just shows it as unset).
  static const List<String> clubs = [
    'Driver',
    '3 Wood',
    '5 Wood',
    '7 Wood',
    '3 Hybrid',
    '4 Hybrid',
    '5 Hybrid',
    '2 Iron',
    '3 Iron',
    '4 Iron',
    '5 Iron',
    '6 Iron',
    '7 Iron',
    '8 Iron',
    '9 Iron',
    'Pitching Wedge',
    'Gap Wedge',
    'Sand Wedge',
    'Lob Wedge',
    'Putter',
  ];
  static const List<String> lies = [
    'Tee',
    'Fairway',
    'Light Rough',
    'Deep Rough',
    'Bunker',
    'Green',
    'Recovery',
  ];
  // A shot's normal end-spot is just the *next* shot's lie, so `result` only
  // captures the terminal outcomes a next shot can't imply: the ball was holed,
  // or a penalty was incurred (OB / water / lost). Leave it blank otherwise.
  static const List<String> results = [
    'Holed',
    'Penalty',
  ];

  @override
  State<_ShotRow> createState() => _ShotRowState();
}

class _ShotRowState extends State<_ShotRow> {
  // Only distance is a free-entry field (club / lie / result are dropdowns).
  late final TextEditingController _distance;

  @override
  void initState() {
    super.initState();
    _distance = TextEditingController(
      text: widget.shot.distanceYards?.toString() ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _ShotRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shot.distanceYards != int.tryParse(_distance.text)) {
      _distance.text = widget.shot.distanceYards?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _distance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.shot;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Shot ${widget.index + 1}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                IconButton(
                  key: ValueKey('shot_delete_${widget.index}'),
                  icon: const Icon(Icons.close),
                  tooltip: 'Remove shot',
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onDelete,
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _ShotDropdown(
                    fieldKey: ValueKey('shot_club_${widget.index}'),
                    label: 'Club',
                    value: s.club,
                    options: _ShotRow.clubs,
                    onChanged: (v) => widget.onChanged(s.copyWith(club: v)),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 96,
                  child: TextField(
                    key: ValueKey('shot_distance_${widget.index}'),
                    controller: _distance,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Dist',
                      isDense: true,
                      suffixText: 'yds',
                    ),
                    onChanged: (v) {
                      final text = v.trim();
                      final d = text.isEmpty
                          ? null
                          : (int.tryParse(text) ?? 0).clamp(0, 100000);
                      widget.onChanged(s.copyWith(distanceYards: d));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ShotDropdown(
                    fieldKey: ValueKey('shot_lie_${widget.index}'),
                    label: 'Lie',
                    value: s.lie,
                    options: _ShotRow.lies,
                    onChanged: (v) => widget.onChanged(s.copyWith(lie: v)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ShotDropdown(
                    fieldKey: ValueKey('shot_result_${widget.index}'),
                    label: 'Result',
                    value: s.result,
                    options: _ShotRow.results,
                    onChanged: (v) => widget.onChanged(s.copyWith(result: v)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A small nullable preset dropdown for a shot's lie / result. The first item
/// ("—") clears the value.
class _ShotDropdown extends StatelessWidget {
  const _ShotDropdown({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final Key fieldKey;
  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    // Guard against a stored value not in the option list (keeps the dropdown
    // from asserting); such a value is treated as unset in the control.
    final selected = options.contains(value) ? value : null;
    return DropdownButtonFormField<String?>(
      key: fieldKey,
      initialValue: selected,
      isDense: true,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('—')),
        for (final o in options)
          DropdownMenuItem<String?>(value: o, child: Text(o)),
      ],
      onChanged: onChanged,
    );
  }
}
