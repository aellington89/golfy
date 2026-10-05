import 'package:flutter/material.dart';

import '../features/courses/courses_screen.dart';
import '../features/settings/settings_screen.dart';

/// App-wide navigation drawer — the top-level home for managing reference data
/// that doesn't warrant its own bottom-nav tab (#36 workflow): **Courses** and
/// **Settings**, which carries the backup action (#69) and will grow the
/// version / licences / privacy / support rows (#72).
///
/// Added as `drawer:` on each top-level tab screen's Scaffold (Events, Rounds,
/// Hole Entry, Dashboard), so every tab's AppBar shows the hamburger and opens
/// the same menu. Tapping an item closes the drawer and pushes over the shell.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration:
                BoxDecoration(color: theme.colorScheme.primaryContainer),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'Golfy',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          ListTile(
            key: const ValueKey('drawer_courses'),
            leading: const Icon(Icons.golf_course),
            title: const Text('Courses'),
            subtitle: const Text('Add & edit course layouts'),
            onTap: () {
              Navigator.of(context).pop(); // close the drawer
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CoursesScreen(),
                ),
              );
            },
          ),
          ListTile(
            key: const ValueKey('drawer_settings'),
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            subtitle: const Text('Back up your data'),
            onTap: () {
              Navigator.of(context).pop(); // close the drawer
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
