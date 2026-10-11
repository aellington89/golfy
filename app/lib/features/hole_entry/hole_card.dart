import 'package:flutter/material.dart';

import '../../widgets/par_selector.dart';

import 'hole_draft.dart';
import 'hole_rules.dart';
import 'shot_inference.dart';

/// Form for a single hole's entry. Stateless w.r.t. the draft data — the
/// parent owns the [HoleDraft] map and pushes a fresh card each rebuild.
/// Local state is only the notes row's open flag and whether a save has been
/// tried (which is when a missing answer starts showing as an error).
///
/// The card reads top to bottom in the order a hole is played, and each shot is
/// entered in the section whose stats it decides, so nothing sends you back up:
///
///  * **Hole** — par, yards, stroke index.
///  * **Tee shot** — the tee shot (club; its distance is the hole's yardage),
///    and whether it found the fairway, or the green on a par 3. Required.
///  * **Approach & around the green** — every shot after the tee and before
///    the green, then GIR, bunker visited and up & down attempt.
///  * **Putting** — a row per putt with its distance to the hole in feet (the
///    putts count is how many rows there are), then up & down success and sand
///    save once they apply.
///  * **Score** — penalties and the score, which counts itself from the
///    strokes above; then what's left to fix, and Save.
///
/// Every edit goes through `hole_rules.dart`, which fills in what follows from
/// it (shot 2's lie from "Fairway hit?", GIR from the strokes to the green, up &
/// down success from the putts, the score from everything) and forces the
/// combinations `HoleResultDao` rejects, so the upsert can't throw. Save Hole
/// refuses a hole with a blocking issue and says why.
class HoleCard extends StatefulWidget {
  const HoleCard({
    super.key,
    required this.holeNumber,
    required this.draft,
    required this.savedDraft,
    required this.onChanged,
    required this.onSave,
    this.courseSetName,
    this.strokeIndex,
    this.onStrokeIndexChanged,
    this.strokeIndexClashWith,
    this.strokeIndexDirty = false,
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

  /// Persists the hole. Only called once the draft has no blocking issue.
  final VoidCallback onSave;

  /// Name of the yardage set this round is played from, or null when it has
  /// none. Labels the yards field so it's obvious at the point of entry which
  /// tee box the pre-filled number came from (#81).
  final String? courseSetName;

  /// The hole's stroke index on the **course** (#81). Unlike every other field
  /// on this card it has no round-level home — `hole_results` doesn't store it —
  /// so editing it here edits the course template.
  final int? strokeIndex;
  final ValueChanged<int?>? onStrokeIndexChanged;

  /// Another hole already carrying the entered stroke index, if any. Stroke
  /// index has to be a permutation of 1..18 and this card shows one hole at a
  /// time, so the clash is called out rather than left to be discovered later.
  final int? strokeIndexClashWith;

  /// Whether the stroke index differs from what the course has stored. Feeds
  /// the Saved / Unsaved chip, which otherwise only tracks the round draft.
  final bool strokeIndexDirty;

  /// Navigates to the previous / next hole in the parent's PageView.
  /// `null` means "no neighbour in that direction" (hole 1 / hole 18) and
  /// the corresponding chevron renders disabled.
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  bool get isSaved => savedDraft != null;
  bool get isDirty =>
      savedDraft == null || savedDraft != draft || strokeIndexDirty;

  @override
  State<HoleCard> createState() => _HoleCardState();
}

class _HoleCardState extends State<HoleCard> {
  bool _notesExpanded = false;

  /// Whether Save Hole has been tapped while something still blocked it. Until
  /// then a missing answer reads as a to-do rather than an error, so a hole you
  /// have only just opened isn't already shouting at you.
  bool _attemptedSave = false;

  /// The tee shot's result, scrolled into view when a save is refused for it.
  final GlobalKey _teeResultKey = GlobalKey();

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

  void _edit(HoleDraft next) => widget.onChanged(next);

  void _save(HoleDraft d) {
    final blocking = holeIssues(d).where((i) => i.blocking).toList();
    if (blocking.isEmpty) {
      setState(() => _attemptedSave = false);
      widget.onSave();
      return;
    }
    setState(() => _attemptedSave = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(
      content: Text(
        blocking.length == 1
            ? "Can't save yet. ${blocking.single.message}"
            : "Can't save yet — ${blocking.length} things to fix.",
      ),
    ));
    // The tee shot sits at the top of the card, far from the button, so take
    // the player to it.
    if (blocking.first.kind == HoleIssueKind.teeShotResult) {
      final target = _teeResultKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 250),
          alignment: 0.2,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = withTeeShot(widget.draft);
    final issues = holeIssues(d);
    final fromBunker = d.shots.any((s) => s.lie == 'Bunker');
    final toGreen = strokesToGreen(d);

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
              const _SectionHeader('Hole'),
              ParSelector(
                value: d.par,
                onChanged: (par) => _edit(changePar(d, par)),
              ),
              const SizedBox(height: 12),
              _YardsRow(
                controller: _yardsController,
                courseSetName: widget.courseSetName,
                onChanged: (v) {
                  // Numeric keyboard + a >= 0 floor mirror the `yards >= 0`
                  // CHECK; an empty field means "unknown" and stores 0.
                  final yards = (int.tryParse(v) ?? 0).clamp(0, 100000);
                  _edit(changeYards(d, yards));
                },
              ),
              if (widget.onStrokeIndexChanged != null) ...[
                const SizedBox(height: 12),
                _StrokeIndexRow(
                  value: widget.strokeIndex,
                  clashWith: widget.strokeIndexClashWith,
                  onChanged: widget.onStrokeIndexChanged!,
                ),
              ],
              const _SectionHeader('Tee shot'),
              _ShotCard(
                key: const ValueKey('shot_row_0'),
                index: 0,
                isTee: true,
                shot: d.shots.first,
                holed: d.putts == 0 && d.shots.length == 1,
                onChanged: (s) => _edit(updateShot(d, 0, s)),
              ),
              const SizedBox(height: 8),
              _TeeResultRow(
                key: _teeResultKey,
                par: d.par,
                value: d.par == 3 ? d.gir : d.fairwayHit,
                showError: _attemptedSave && !teeShotAnswered(d),
                onChanged: (hit) => _edit(answerTeeShot(d, hit)),
              ),
              const _SectionHeader('Approach & around the green'),
              for (var i = 1; i < d.shots.length; i++)
                _ShotCard(
                  key: ValueKey('shot_row_$i'),
                  index: i,
                  shot: d.shots[i],
                  holed: d.putts == 0 && i == d.shots.length - 1,
                  onChanged: (s) => _edit(updateShot(d, i, s)),
                  onDelete: () => _edit(removeShot(d, i)),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('add_shot'),
                  onPressed: () => _edit(addShot(d)),
                  icon: const Icon(Icons.add),
                  label: const Text('Add shot'),
                ),
              ),
              // On a par 3, GIR is the tee shot's "Green hit?" answer above.
              if (d.par != 3)
                _SwitchRow(
                  label: 'GIR',
                  value: d.gir ?? false,
                  enabled: girPossible(d),
                  disabledReason: 'N/A — $toGreen strokes before putting',
                  onChanged: (v) => _edit(applyEdit(d, d.copyWith(gir: v))),
                ),
              _SwitchRow(
                label: 'Bunker visited',
                value: d.bunkerVisited,
                enabled: !fromBunker,
                disabledReason: 'A shot is played from a bunker',
                onChanged: (v) =>
                    _edit(applyEdit(d, d.copyWith(bunkerVisited: v))),
              ),
              _SwitchRow(
                label: 'Up/Down attempt',
                value: d.upDownAttempt,
                onChanged: (v) =>
                    _edit(applyEdit(d, d.copyWith(upDownAttempt: v))),
              ),
              const _SectionHeader('Putting'),
              for (var i = 0; i < d.puttShots.length; i++)
                _PuttCard(
                  key: ValueKey('putt_row_$i'),
                  index: i,
                  shotNumber: d.shots.length + i + 1,
                  putt: d.puttShots[i],
                  holed: i == d.puttShots.length - 1,
                  onChanged: (p) => _edit(updatePutt(d, i, p)),
                  onDelete: () => _edit(removePutt(d, i)),
                ),
              if (d.puttShots.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'No putts — holed from off the green.',
                    key: const ValueKey('no_putts'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('add_putt'),
                  onPressed: () => _edit(addPutt(d)),
                  icon: const Icon(Icons.add),
                  label: const Text('Add putt'),
                ),
              ),
              // The outcomes the putts decide, right under them, and only once
              // there is something to decide.
              if (d.upDownAttempt)
                _SwitchRow(
                  label: 'Up/Down success',
                  value: d.upDownSuccess,
                  enabled: d.putts <= 1,
                  disabledReason: 'N/A — 2+ putts',
                  onChanged: (v) =>
                      _edit(applyEdit(d, d.copyWith(upDownSuccess: v))),
                ),
              if (d.bunkerVisited)
                _SwitchRow(
                  label: 'Sand save',
                  value: d.sandSave,
                  enabled: d.putts <= 1,
                  disabledReason: 'N/A — 2+ putts',
                  onChanged: (v) =>
                      _edit(applyEdit(d, d.copyWith(sandSave: v))),
                ),
              const _SectionHeader('Score'),
              _StepperRow(
                key: const ValueKey('penalty'),
                label: 'Penalty strokes',
                value: d.penaltyStrokes,
                min: 0,
                onChanged: (v) =>
                    _edit(applyEdit(d, d.copyWith(penaltyStrokes: v))),
              ),
              const SizedBox(height: 12),
              _StepperRow(
                key: const ValueKey('score'),
                label: 'Score',
                value: d.score,
                // Score must exceed putts — at least the tee shot isn't a putt.
                min: d.putts + 1,
                helperText:
                    d.score == d.countedScore ? strokeTally(d) : null,
                errorText: d.score == d.countedScore
                    ? null
                    : 'The strokes add up to ${d.countedScore}',
                onChanged: (v) => _edit(applyEdit(d, d.copyWith(score: v))),
              ),
              const SizedBox(height: 12),
              _NotesSection(
                value: d.notes,
                expanded: _notesExpanded,
                onExpansionChanged: (open) =>
                    setState(() => _notesExpanded = open),
                onChanged: (v) => _edit(d.copyWith(notes: v)),
              ),
              if (issues.isNotEmpty) ...[
                const SizedBox(height: 12),
                _IssuesPanel(
                  issues: issues,
                  attemptedSave: _attemptedSave,
                  onFix: (fix) => _edit(fix.apply(d)),
                ),
              ],
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
                        onPressed: () => _save(d),
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

/// A stage sub-header ("Hole", "Tee shot", "Approach & around the green",
/// "Putting", "Score") that labels each group of fields. Purely visual — it makes the
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

/// The hole's yardage, labelled with the yardage set it came from.
///
/// Naming the set here rather than only in the app bar puts it exactly where
/// the number it explains appears — and when the round has no set, says so,
/// because that is why the field arrived blank (#81).
class _YardsRow extends StatelessWidget {
  const _YardsRow({
    required this.controller,
    required this.onChanged,
    this.courseSetName,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? courseSetName;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('yards'),
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: courseSetName == null ? 'Yards' : 'Yards · $courseSetName',
        border: const OutlineInputBorder(),
        hintText: 'e.g. 420',
        suffixText: 'yds',
        helperText: courseSetName == null
            ? "No yardage set on this round — yardages are not pre-filled"
            : null,
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
    this.helperText,
    this.errorText,
  });

  final String label;
  final int value;
  final int min;
  final ValueChanged<int> onChanged;
  final String? helperText;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        helperText: helperText,
        errorText: errorText,
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

/// The hole's stroke index, editable during play (#81).
///
/// Sits with par and yards because it is hole metadata you read off the same
/// scorecard — but it is the one field here that belongs to the *course* rather
/// than the round, so the helper text says so. That is also why it is worth
/// having on this form at all: stroke index has no round-level column, so
/// without it the only way to record one mid-round is a separate sheet.
///
/// Controller-backed and re-synced in [didUpdateWidget] so a value that changes
/// from outside (a page swipe to another hole, or the course stream loading)
/// refreshes without clobbering active typing.
class _StrokeIndexRow extends StatefulWidget {
  const _StrokeIndexRow({
    required this.value,
    required this.onChanged,
    this.clashWith,
  });

  final int? value;
  final int? clashWith;
  final ValueChanged<int?> onChanged;

  @override
  State<_StrokeIndexRow> createState() => _StrokeIndexRowState();
}

class _StrokeIndexRowState extends State<_StrokeIndexRow> {
  late final TextEditingController _controller;

  static String _text(int? v) => v?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _text(widget.value));
  }

  @override
  void didUpdateWidget(covariant _StrokeIndexRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != int.tryParse(_controller.text)) {
      _controller.text = _text(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.value;
    final outOfRange = v != null && (v < 1 || v > 18);
    final clash = widget.clashWith;
    return TextField(
      key: const ValueKey('stroke_index'),
      controller: _controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Stroke index',
        border: const OutlineInputBorder(),
        hintText: 'e.g. 7',
        errorText: outOfRange
            ? "Must be 1-18"
            : clash != null
                ? "Already used on hole $clash"
                : null,
        helperText: "Saved on the course, not this round",
      ),
      onChanged: (raw) => widget.onChanged(int.tryParse(raw.trim())),
    );
  }
}

/// The tee shot's result: whether it found the fairway, or on a par 3 the
/// green (which is GIR). Required — Save Hole won't go through without it,
/// because the fairway and GIR stats would otherwise be recorded as a guess.
///
/// Starts with neither answer selected, and once answered can be switched but
/// not cleared.
class _TeeResultRow extends StatelessWidget {
  const _TeeResultRow({
    super.key,
    required this.par,
    required this.value,
    required this.showError,
    required this.onChanged,
  });

  final int par;
  final bool? value;
  final bool showError;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final answered = value;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: par == 3 ? 'Green hit?' : 'Fairway hit?',
        border: const OutlineInputBorder(),
        helperText: answered == null && !showError ? 'Required' : null,
        errorText: showError ? 'Required before saving' : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SegmentedButton<bool>(
          key: const ValueKey('tee_result'),
          segments: const [
            ButtonSegment(value: true, label: Text('Yes')),
            ButtonSegment(value: false, label: Text('No')),
          ],
          selected: answered == null ? const <bool>{} : {answered},
          emptySelectionAllowed: true,
          onSelectionChanged: (sel) {
            if (sel.isNotEmpty) onChanged(sel.first);
          },
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

/// What still stands between this hole and Save Hole, then anything merely
/// worth a look, each with its one-tap fixes (see [holeIssues]).
///
/// Before a save has been tried, blocking issues read as a neutral to-do list;
/// after a refused save they turn into errors.
class _IssuesPanel extends StatelessWidget {
  const _IssuesPanel({
    required this.issues,
    required this.attemptedSave,
    required this.onFix,
  });

  final List<HoleIssue> issues;
  final bool attemptedSave;
  final ValueChanged<HoleFix> onFix;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final blocking = issues.where((i) => i.blocking).toList();
    final warnings = issues.where((i) => !i.blocking).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (blocking.isNotEmpty)
          _IssueBox(
            key: const ValueKey('hole_errors'),
            title: attemptedSave ? "Can't save yet" : 'Before saving',
            icon: attemptedSave ? Icons.error_outline : Icons.checklist,
            background: attemptedSave
                ? scheme.errorContainer
                : scheme.secondaryContainer,
            foreground: attemptedSave
                ? scheme.onErrorContainer
                : scheme.onSecondaryContainer,
            issues: blocking,
            onFix: onFix,
          ),
        if (blocking.isNotEmpty && warnings.isNotEmpty)
          const SizedBox(height: 8),
        if (warnings.isNotEmpty)
          _IssueBox(
            key: const ValueKey('hole_warnings'),
            title: 'Worth a look',
            icon: Icons.info_outline,
            background: scheme.tertiaryContainer,
            foreground: scheme.onTertiaryContainer,
            issues: warnings,
            onFix: onFix,
          ),
      ],
    );
  }
}

class _IssueBox extends StatelessWidget {
  const _IssueBox({
    super.key,
    required this.title,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.issues,
    required this.onFix,
  });

  final String title;
  final IconData icon;
  final Color background;
  final Color foreground;
  final List<HoleIssue> issues;
  final ValueChanged<HoleFix> onFix;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 8),
              Text(
                title,
                style: text.titleSmall?.copyWith(color: foreground),
              ),
            ],
          ),
          for (final issue in issues) ...[
            const SizedBox(height: 6),
            Text(
              issue.message,
              style: text.bodySmall?.copyWith(color: foreground),
            ),
            if (issue.fixes.isNotEmpty)
              Wrap(
                spacing: 8,
                children: [
                  for (final fix in issue.fixes)
                    TextButton(
                      key: ValueKey('fix_${fix.id}'),
                      style: TextButton.styleFrom(
                        foregroundColor: foreground,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => onFix(fix),
                      child: Text(fix.label),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

/// One shot's editable card: lie (not for the tee shot — it's always from the
/// tee), club and distance, a Penalty toggle, and a delete action for every
/// shot but the tee shot. The last stroke before the hole is complete with no
/// putts carries a "Holed" badge; the form sets that itself.
///
/// Nothing here suggests a club, and only the tee shot arrives with a distance.
/// The distance field is backed by a controller synced in [didUpdateWidget] so
/// a value that changes from the outside (e.g. a deleted earlier shot shifting
/// this card's data up) refreshes without clobbering active typing.
class _ShotCard extends StatefulWidget {
  const _ShotCard({
    super.key,
    required this.index,
    required this.shot,
    required this.onChanged,
    this.onDelete,
    this.isTee = false,
    this.holed = false,
  });

  final int index;
  final ShotDraft shot;
  final ValueChanged<ShotDraft> onChanged;
  final VoidCallback? onDelete;
  final bool isTee;
  final bool holed;

  @override
  State<_ShotCard> createState() => _ShotCardState();
}

class _ShotCardState extends State<_ShotCard> {
  late final TextEditingController _distance;

  @override
  void initState() {
    super.initState();
    _distance = TextEditingController(
      text: widget.shot.distanceYards?.toString() ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _ShotCard oldWidget) {
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
    final i = widget.index;
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
                  'Shot ${i + 1}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (widget.holed) ...[
                  const SizedBox(width: 8),
                  Chip(
                    key: ValueKey('shot_holed_$i'),
                    avatar: const Icon(Icons.flag, size: 16),
                    label: const Text('Holed'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
                const Spacer(),
                FilterChip(
                  key: ValueKey('shot_penalty_$i'),
                  label: const Text('Penalty'),
                  selected: s.isPenalty,
                  visualDensity: VisualDensity.compact,
                  onSelected: (on) => widget.onChanged(
                    s.copyWith(result: on ? penaltyResult : null),
                  ),
                ),
                if (widget.onDelete != null)
                  IconButton(
                    key: ValueKey('shot_delete_$i'),
                    icon: const Icon(Icons.close),
                    tooltip: 'Remove shot',
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onDelete,
                  )
                else
                  const SizedBox(width: 8),
              ],
            ),
            if (!widget.isTee) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _ShotDropdown(
                  fieldKey: ValueKey('shot_lie_$i'),
                  label: 'Played from',
                  value: s.lie,
                  options: shotLies,
                  onChanged: (v) => widget.onChanged(s.copyWith(lie: v)),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ShotDropdown(
                    fieldKey: ValueKey('shot_club_$i'),
                    label: 'Club',
                    value: s.club,
                    options: shotClubs,
                    onChanged: (v) => widget.onChanged(s.copyWith(club: v)),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 96,
                  child: TextField(
                    key: ValueKey('shot_distance_$i'),
                    controller: _distance,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'To pin',
                      isDense: true,
                      suffixText: 'yds',
                    ),
                    onChanged: (v) {
                      final text = v.trim();
                      final yards = text.isEmpty
                          ? null
                          : (int.tryParse(text) ?? 0).clamp(0, 100000);
                      widget.onChanged(s.copyWith(distanceYards: yards));
                    },
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One putt's card: its distance to the hole, in feet, and a delete action.
/// Club and lie aren't asked — every putt is a putter from the green. The last
/// putt carries a "Holed" badge, which the form sets itself.
///
/// The distance field is controller-backed and synced in [didUpdateWidget], as
/// on [_ShotCard], so removing an earlier putt — which shifts this card's data
/// up — refreshes it without clobbering active typing.
class _PuttCard extends StatefulWidget {
  const _PuttCard({
    super.key,
    required this.index,
    required this.shotNumber,
    required this.putt,
    required this.holed,
    required this.onChanged,
    required this.onDelete,
  });

  /// Which putt this is, from 0.
  final int index;

  /// Its place among all the hole's strokes, from 1 — what "Shot N" means
  /// everywhere else on the card.
  final int shotNumber;
  final ShotDraft putt;
  final bool holed;
  final ValueChanged<ShotDraft> onChanged;
  final VoidCallback onDelete;

  @override
  State<_PuttCard> createState() => _PuttCardState();
}

class _PuttCardState extends State<_PuttCard> {
  late final TextEditingController _distance;

  @override
  void initState() {
    super.initState();
    _distance = TextEditingController(
      text: widget.putt.distanceFeet?.toString() ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _PuttCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.putt.distanceFeet != int.tryParse(_distance.text)) {
      _distance.text = widget.putt.distanceFeet?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _distance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final i = widget.index;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // The one part of the row that can give way on a narrow
                // screen or at a large text size.
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: 'Putt ${i + 1}',
                        style: theme.textTheme.titleSmall,
                      ),
                      TextSpan(
                        text: '  ·  Shot ${widget.shotNumber}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.holed)
                  Chip(
                    key: ValueKey('putt_holed_$i'),
                    avatar: const Icon(Icons.flag, size: 16),
                    label: const Text('Holed'),
                    visualDensity: VisualDensity.compact,
                  ),
                IconButton(
                  key: ValueKey('putt_delete_$i'),
                  icon: const Icon(Icons.close),
                  tooltip: 'Remove putt',
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onDelete,
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 140,
                child: TextField(
                  key: ValueKey('putt_distance_$i'),
                  controller: _distance,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'To hole',
                    isDense: true,
                    suffixText: 'ft',
                  ),
                  onChanged: (v) {
                    final text = v.trim();
                    final feet = text.isEmpty
                        ? null
                        : (int.tryParse(text) ?? 0).clamp(0, 100000);
                    widget.onChanged(
                      widget.putt.copyWith(distanceFeet: feet),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small nullable preset dropdown for a shot's club / lie. The first item
/// ("—") clears the value.
///
/// Deliberately an [InputDecorator] wrapping a plain [DropdownButton] rather
/// than a [DropdownButtonFormField]: the form-field variant seeds itself from
/// `initialValue` and never re-applies it once the user has interacted
/// (`FormFieldState.didUpdateWidget` only refreshes `forceErrorText`). Rows are
/// keyed by index, so deleting shot 1 of 3 shifts every later shot's data up
/// into a reused state object — and the form field would keep displaying the
/// deleted shot's club. [DropdownButton] is controlled by `value`, so it always
/// shows what the draft actually holds.
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
    return InputDecorator(
      decoration: InputDecoration(labelText: label, isDense: true),
      child: DropdownButton<String?>(
        key: fieldKey,
        value: selected,
        isDense: true,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('—')),
          for (final o in options)
            DropdownMenuItem<String?>(value: o, child: Text(o)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
