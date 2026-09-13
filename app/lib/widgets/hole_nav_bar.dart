import 'package:flutter/material.dart';

/// A horizontal strip of hole chips with a progress counter above it, for use
/// as an [AppBar.bottom].
///
/// Each chip jumps to that hole on tap, carries a check when the hole is
/// [complete] and a pencil when it has unsaved edits, and highlights when it's
/// the current one. Above the strip, a small "`label`: X / N" counter gives the
/// at-a-glance progress signal the chips alone don't.
///
/// Generalised out of the Hole Entry screen so the course editor gets the same
/// navigation and completeness signal (#81) rather than an imitation of it. The
/// counter string is built here, not passed in, so the two screens can't drift
/// apart in format.
class HoleNavBar extends StatefulWidget implements PreferredSizeWidget {
  const HoleNavBar({
    super.key,
    required this.holeCount,
    required this.currentIndex,
    required this.complete,
    required this.label,
    required this.onTapHole,
    this.dirty = const {},
    this.keyPrefix = 'hole_chip',
  });

  final int holeCount;

  /// Zero-based index of the hole currently shown.
  final int currentIndex;

  /// One-based hole numbers that count as done.
  final Set<int> complete;

  /// One-based hole numbers with unsaved edits.
  final Set<int> dirty;

  /// Leads the counter, e.g. `'Holes saved'` → "Holes saved: 4 / 18".
  final String label;

  /// Receives the tapped hole's zero-based index.
  final ValueChanged<int> onTapHole;

  /// Chip keys are `'<keyPrefix>_<holeNumber>'`. Distinct per screen so two
  /// strips on different screens don't collide in tests.
  final String keyPrefix;

  @override
  Size get preferredSize => const Size.fromHeight(80);

  @override
  State<HoleNavBar> createState() => _HoleNavBarState();
}

class _HoleNavBarState extends State<HoleNavBar> {
  final ScrollController _scrollController = ScrollController();
  static const double _chipExtent = 52;

  @override
  void didUpdateWidget(covariant HoleNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _scrollToCurrent();
    }
  }

  void _scrollToCurrent() {
    if (!_scrollController.hasClients) return;
    final viewport = _scrollController.position.viewportDimension;
    final target =
        widget.currentIndex * _chipExtent - viewport / 2 + _chipExtent / 2;
    final clamped =
        target.clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      clamped,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completeCount = widget.complete.length;
    return SizedBox(
      height: 80,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
            child: Text(
              '${widget.label}: $completeCount / ${widget.holeCount}',
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: widget.holeCount,
              itemBuilder: (context, i) {
                final hole = i + 1;
                final active = widget.currentIndex == i;
                // Unsaved edits outrank "done" — a hole you've changed since
                // saving is the one you still need to act on.
                final isDirty = widget.dirty.contains(hole);
                final isComplete = widget.complete.contains(hole);
                final icon = isDirty
                    ? Icons.edit
                    : isComplete
                        ? Icons.check
                        : null;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: ChoiceChip(
                    key: ValueKey('${widget.keyPrefix}_$hole'),
                    label: Text('$hole'),
                    avatar: icon == null
                        ? null
                        : Icon(
                            icon,
                            size: 16,
                            color: active
                                ? theme.colorScheme.onSecondaryContainer
                                : isDirty
                                    ? theme.colorScheme.tertiary
                                    : theme.colorScheme.primary,
                          ),
                    selected: active,
                    onSelected: (_) => widget.onTapHole(i),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
