import 'package:flutter/material.dart';

class HoleEntryScreen extends StatelessWidget {
  const HoleEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Golfy')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Hole Entry', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Per-hole data entry form will live here.',
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
