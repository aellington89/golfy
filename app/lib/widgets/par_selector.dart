import 'package:flutter/material.dart';

/// The 3 / 4 / 5 par choice, as a labelled [SegmentedButton].
///
/// Extracted from the Hole Entry card so the course editor renders the *same*
/// control rather than a lookalike (#81) — picking par while setting a course up
/// and picking it while playing are the same decision, and used to be a dropdown
/// in one place and a segmented button in the other.
///
/// Deliberately still a `SegmentedButton<int>` under the decoration: it is what
/// makes the three options visible at a glance instead of one tap away, and
/// widget tests locate par controls by that type.
class ParSelector extends StatelessWidget {
  const ParSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.labelText = 'Par',
  });

  final int value;
  final ValueChanged<int> onChanged;
  final String labelText;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 3, label: Text('3')),
            ButtonSegment(value: 4, label: Text('4')),
            ButtonSegment(value: 5, label: Text('5')),
          ],
          selected: {value},
          onSelectionChanged: (sel) => onChanged(sel.first),
        ),
      ),
    );
  }
}
