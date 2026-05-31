import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../rounds/active_round_provider.dart';

class HoleEntryScreen extends ConsumerWidget {
  const HoleEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activeRoundId = ref.watch(activeRoundIdProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Golfy')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Hole Entry', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              activeRoundId == null
                  ? 'Per-hole data entry form will live here.'
                  : 'Round #$activeRoundId — entry form arrives with #10.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
