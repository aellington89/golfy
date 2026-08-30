import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Named indices for the [AppShell] bottom-navigation destinations, so tab
/// jumps read as `ShellTabs.holeEntry` rather than a bare `1`. Keep these in
/// sync with the order of `AppShell`'s IndexedStack children / destinations.
abstract final class ShellTabs {
  static const int events = 0;
  static const int rounds = 1;
  static const int holeEntry = 2;
  static const int dashboard = 3;
}

class TabIndex extends Notifier<int> {
  @override
  int build() => 0;

  void set(int value) => state = value;
}

final tabIndexProvider = NotifierProvider<TabIndex, int>(TabIndex.new);
