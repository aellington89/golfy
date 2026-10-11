import 'package:flutter/material.dart';

import '../../widgets/par_selector.dart';

/// One hole of a course's template: par, stroke index, the selected tee set's
/// course yards and the selected yardage set's tee-to-pin yards — reviewed and
/// edited together (#81).
///
/// Par and stroke index are the hole's whatever it is played from. Course
/// yards are the tee set's scorecard number, the same whichever pin set is
/// used; tee-to-pin is the distance from that tee set to the selected pin set's
/// pin, so it moves with both.
///
/// Fully controlled and free of Riverpod on purpose: the course editor renders
/// eighteen of these in a list, and Hole Entry renders exactly one in a sheet so
/// a course can be corrected mid-round without leaving the round. Both hosts own
/// the state and the saving.
///
/// The text fields are controller-backed and re-synced in [didUpdateWidget]
/// rather than seeded from `initialValue`, because switching tee or pin sets
/// changes the yards underneath a card that is already on screen — an
/// `initialValue` would keep showing the previous set's number.
class CourseHoleCard extends StatefulWidget {
  const CourseHoleCard({
    super.key,
    required this.holeNumber,
    required this.par,
    required this.strokeIndex,
    required this.onParChanged,
    required this.onStrokeIndexChanged,
    this.courseYards,
    this.teeSetName,
    this.onCourseYardsChanged,
    this.teeToPinYards,
    this.pinSetName,
    this.onTeeToPinYardsChanged,
    this.isDirty = false,
    this.showStatus = true,
  });

  final int holeNumber;
  final int par;
  final int? strokeIndex;

  /// The selected tee set's course yards for this hole, or null when there is
  /// no tee set — in which case the field is disabled and says so.
  final int? courseYards;

  /// Labels the course-yards field, so it's obvious which tee set is edited.
  final String? teeSetName;

  /// The selected (tee set, pin set) pair's tee-to-pin yards for this hole, or
  /// null when there is no pin set (or no tee set to measure from) — in which
  /// case the field is disabled and says so.
  final int? teeToPinYards;

  /// Labels the tee-to-pin field with the pin set it measures to.
  final String? pinSetName;

  final ValueChanged<int> onParChanged;
  final ValueChanged<int?> onStrokeIndexChanged;
  final ValueChanged<int>? onCourseYardsChanged;
  final ValueChanged<int>? onTeeToPinYardsChanged;

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
  late final TextEditingController _courseYards;
  late final TextEditingController _teeToPin;

  // A blank field means "not recorded". Stroke index is genuinely nullable;
  // yardage stores 0, which the UI shows as empty rather than a misleading "0".
  static String _siText(int? v) => v?.toString() ?? '';
  static String _yardsText(int? v) => (v == null || v == 0) ? '' : v.toString();

  @override
  void initState() {
    super.initState();
    _si = TextEditingController(text: _siText(widget.strokeIndex));
    _courseYards =
        TextEditingController(text: _yardsText(widget.courseYards));
    _teeToPin = TextEditingController(text: _yardsText(widget.teeToPinYards));
  }

  @override
  void didUpdateWidget(covariant CourseHoleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Compare parsed values, not text, so an in-progress edit isn't clobbered
    // by the rebuild it just triggered.
    if (widget.strokeIndex != int.tryParse(_si.text)) {
      _si.text = _siText(widget.strokeIndex);
    }
    _resync(_courseYards, widget.courseYards);
    _resync(_teeToPin, widget.teeToPinYards);
  }

  static void _resync(TextEditingController field, int? yards) {
    if ((yards ?? 0) != (int.tryParse(field.text) ?? 0)) {
      field.text = _yardsText(yards);
    }
  }

  @override
  void dispose() {
    _si.dispose();
    _courseYards.dispose();
    _teeToPin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTee = widget.courseYards != null;
    final hasPin = widget.teeToPinYards != null;
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
                  child: _YardsField(
                    fieldKey:
                        ValueKey('course_hole_yards_${widget.holeNumber}'),
                    controller: _courseYards,
                    enabled: hasTee,
                    label: widget.teeSetName == null
                        ? 'Course yards'
                        : 'Course yards · ${widget.teeSetName}',
                    missing: 'No tee set',
                    onChanged: widget.onCourseYardsChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _YardsField(
              fieldKey:
                  ValueKey('course_hole_tee_to_pin_${widget.holeNumber}'),
              controller: _teeToPin,
              enabled: hasPin,
              label: widget.pinSetName == null
                  ? 'Tee to pin'
                  : 'Tee to pin · ${widget.pinSetName}',
              missing: hasTee ? 'No pin set' : 'Needs a tee set and a pin set',
              onChanged: widget.onTeeToPinYardsChanged,
            ),
          ],
        ),
      ),
    );
  }
}

/// A yardage field: blank means "not recorded", which stores 0.
class _YardsField extends StatelessWidget {
  const _YardsField({
    required this.fieldKey,
    required this.controller,
    required this.enabled,
    required this.label,
    required this.missing,
    required this.onChanged,
  });

  /// Keys the [TextField] itself, so tests can read and type into it.
  final Key fieldKey;
  final TextEditingController controller;
  final bool enabled;
  final String label;

  /// Why the field is disabled, shown in place of a value.
  final String missing;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        helperText: enabled ? null : missing,
        suffixText: 'yds',
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onChanged: (v) {
        // A >= 0 floor mirrors the `yards >= 0` CHECK; an empty field means
        // "unknown" and stores 0.
        final yards = (int.tryParse(v.trim()) ?? 0).clamp(0, 100000);
        onChanged?.call(yards);
      },
    );
  }
}
