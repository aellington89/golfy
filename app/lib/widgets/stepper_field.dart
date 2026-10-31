import 'package:flutter/material.dart';

/// A small whole number in an outlined field, changed with − and + buttons:
/// a hole's score and penalty strokes on the Hole Entry card, and a round's
/// number in the new / edit round dialogs.
///
/// Shared so the three read the same way to a screen reader (#73): each button
/// says what it does ("Decrease score"), and the number is one item with its
/// name — "Score, 5" — that TalkBack can adjust directly with a swipe up or
/// down, and that announces itself when it changes. Before, the buttons were
/// just "Button" and the number was read without saying what it was.
///
/// [onDecrease] / [onIncrease] are null when that direction is unavailable
/// (at the minimum, or while a dialog is submitting), which disables the
/// button and drops the matching adjust action.
class StepperField extends StatelessWidget {
  const StepperField({
    super.key,
    required this.label,
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
    required this.decreaseKey,
    required this.increaseKey,
    this.helperText,
    this.errorText,
  });

  /// The field's name, shown as its label and spoken with the value.
  final String label;
  final int value;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  /// Keys for the two buttons, which widget tests tap.
  final Key decreaseKey;
  final Key increaseKey;

  final String? helperText;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = label.toLowerCase();
    return InputDecorator(
      decoration: InputDecoration(
        // The value below carries the name for a screen reader; read here too,
        // it would be said twice.
        label: ExcludeSemantics(child: Text(label)),
        border: const OutlineInputBorder(),
        helperText: helperText,
        errorText: errorText,
      ),
      child: Row(
        children: [
          IconButton(
            key: decreaseKey,
            tooltip: 'Decrease $name',
            onPressed: onDecrease,
            icon: const Icon(Icons.remove),
          ),
          Expanded(
            child: Center(
              child: Semantics(
                label: label,
                value: '$value',
                decreasedValue: onDecrease == null ? null : '${value - 1}',
                increasedValue: onIncrease == null ? null : '${value + 1}',
                onDecrease: onDecrease,
                onIncrease: onIncrease,
                liveRegion: true,
                excludeSemantics: true,
                child: Text('$value', style: theme.textTheme.titleMedium),
              ),
            ),
          ),
          IconButton(
            key: increaseKey,
            tooltip: 'Increase $name',
            onPressed: onIncrease,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
