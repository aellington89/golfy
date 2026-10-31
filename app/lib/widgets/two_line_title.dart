import 'dart:math' as math;

import 'package:flutter/material.dart';

/// An app bar title in two lines, a name over a detail: the course over the
/// round's date on Hole Entry and the scorecard, the course over its game in
/// the course editor.
///
/// An [AppBar]'s toolbar is 56 dp tall whatever the text size, and a title
/// taller than that is clipped without an overflow error: at a large text size
/// the second line simply went missing. Screens that use this title pass
/// [toolbarHeight] to their app bar, so the bar grows with the text instead
/// (#73). Each line still ellipsises if it is too long for the width.
class TwoLineTitle extends StatelessWidget {
  const TwoLineTitle({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  /// The toolbar height that fits both lines at the ambient text size: the
  /// standard 56 dp until the two lines need more.
  static double toolbarHeight(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scaler = MediaQuery.textScalerOf(context);
    double lineHeight(TextStyle? style) {
      final painter = TextPainter(
        text: TextSpan(text: 'Hg', style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final height = painter.height;
      painter.dispose();
      return height;
    }

    const padding = 8.0;
    return math.max(
      kToolbarHeight,
      lineHeight(textTheme.titleLarge) +
          lineHeight(textTheme.bodySmall) +
          padding,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.titleLarge,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          subtitle,
          style: textTheme.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
