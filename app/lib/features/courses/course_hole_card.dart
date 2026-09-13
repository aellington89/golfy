import 'package:flutter/material.dart';

import '../../widgets/par_selector.dart';

/// One hole of a course's template: par, stroke index, and the selected yardage
/// set's yardage — reviewed and edited together (#81), instead of par and stroke
/// index on one screen and each set's yardages on another.
///
/// Fully controlled and free of Riverpod on purpose: the course editor renders
/// eighteen of these in a list, and Hole Entry renders exactly one in a sheet so
/// a course can be corrected mid-round without leaving the round. Both hosts own
/// the state and the saving.
///
/// The text fields are controller-backed and re-synced in [didUpdateWidget]
/// rather than seeded from `initialValue`, because switching yardage sets
/// changes [yards] underneath a card that is already on screen — an
/// `initialValue` would keep showing the previous set's number.
class CourseHoleCard extends StatefulWidget {
  const CourseHoleCard({
    super.key,
    required this.holeNumber,
    required this.par,
    required this.strokeIndex,
    required this.onParChanged,
    required this.onStrokeIndexChanged,
    this.yards,
    this.setName,
    this.onYardsChanged,
    this.isDirty = false,
    this.showStatus = true,
  });

  final int holeNumber;
  final int par;
  final int? strokeIndex;

  /// The active yardage set's yardage for this hole, or null when the course has
  /// no sets — in which case the field is disabled and says so.
  final int? yards;

  /// Labels the yardage field, so it's obvious which tee box is being edited.
  final String? setName;

  final ValueChanged<int> onParChanged;
  final ValueChanged<int?> onStrokeIndexChanged;
  final ValueChanged<int>? onYardsChanged;

  /// Whether this hole differs from what's stored, driving the status chip.
  final bool isDirty;

  /// Hosts that save immediately (the Hole Entry sheet) have no unsaved state
  /// worth showing, so they turn the chip off.
  final bool showStatus;

  @override
  State<CourseHoleCard> createState() => _CourseHoleCardState();
}

class _CourseHoleCardState extends State<CourseHoleCard> {
  late final TextEditingController _si;
  late final TextEditingController _yards;

  // A blank field means "not recorded". Stroke index is genuinely nullable;
  // yardage stores 0, which the UI shows as empty rather than a misleading "0".
  static String _siText(int? v) => v?.toString() ?? '';
  static String _yardsText(int? v) => (v == null || v == 0) ? '' : v.toString();

  @override
  void initState() {
    super.initState();
    _si = TextEditingController(text: _siText(widget.strokeIndex));
    _yards = TextEditingController(text: _yardsText(widget.yards));
  }

  @override
  void didUpdateWidget(covariant CourseHoleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Compare parsed values, not text, so an in-progress edit isn't clobbered
    // by the rebuild it just triggered.
    if (widget.strokeIndex != int.tryParse(_si.text)) {
      _si.text = _siText(widget.strokeIndex);
    }
    final shownYards = int.tryParse(_yards.text) ?? 0;
    if ((widget.yards ?? 0) != shownYards) {
      _yards.text = _yardsText(widget.yards);
    }
  }

  @override
  void dispose() {
    _si.dispose();
    _yards.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSet = widget.yards != null;
    return Card(
      key: ValueKey('course_hole_card_${widget.holeNumber}'),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Hole ${widget.holeNumber}',
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                if (widget.showStatus)
                  widget.isDirty
                      ? Chip(
                          avatar: Icon(
                            Icons.edit,
                            size: 18,
                            color: theme.colorScheme.tertiary,
                          ),
                          label: const Text('Unsaved'),
                          visualDensity: VisualDensity.compact,
                        )
                      : Chip(
                          avatar: Icon(
                            Icons.check_circle,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          label: const Text('Saved'),
                          visualDensity: VisualDensity.compact,
                        ),
              ],
            ),
            const SizedBox(height: 8),
            ParSelector(
              key: ValueKey('course_hole_par_${widget.holeNumber}'),
              value: widget.par,
              onChanged: widget.onParChanged,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: ValueKey('course_hole_si_${widget.holeNumber}'),
                    controller: _si,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Stroke index',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) =>
                        widget.onStrokeIndexChanged(int.tryParse(v.trim())),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: ValueKey('course_hole_yards_${widget.holeNumber}'),
                    controller: _yards,
                    enabled: hasSet,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: widget.setName ?? 'Yards',
                      hintText: hasSet ? null : 'Add a set',
                      helperText: hasSet ? null : 'No yardage set',
                      suffixText: 'yds',
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      // A >= 0 floor mirrors the `yards >= 0` CHECK; an empty
                      // field means "unknown" and stores 0.
                      final yards = (int.tryParse(v.trim()) ?? 0).clamp(0, 100000);
                      widget.onYardsChanged?.call(yards);
                    },
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
