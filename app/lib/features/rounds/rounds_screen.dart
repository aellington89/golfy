import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../courses/course_picker.dart';

class RoundsScreen extends ConsumerStatefulWidget {
  const RoundsScreen({super.key});

  @override
  ConsumerState<RoundsScreen> createState() => _RoundsScreenState();
}

class _RoundsScreenState extends ConsumerState<RoundsScreen> {
  Course? _selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Golfy')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Rounds', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'List of rounds will appear here.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            // TODO(#9): Remove this demo block once the New Round dialog
            // lands. CoursePicker should be embedded inside that dialog,
            // not on the Rounds tab itself.
            Text('Course picker (demo)', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            CoursePicker(
              value: _selected,
              onChanged: (c) => setState(() => _selected = c),
            ),
            const SizedBox(height: 8),
            Text(
              'Selected: ${_selected?.name ?? "—"}',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
