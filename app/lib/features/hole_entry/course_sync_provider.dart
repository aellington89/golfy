import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether saving a hole should also push its par and yardage back into the
/// course's template (#81).
///
/// You learn a course's real par and yardages *while* playing it for the first
/// time, and before this the only way to act on that was to leave the round,
/// open the course editor from the drawer, and come back. With this on, every
/// "Save Hole" quietly keeps the course template in step with what you just
/// entered.
///
/// Deliberately session state rather than a stored preference: persisting it
/// would mean a schema change, and it is a per-round intent ("I'm learning this
/// course") rather than a lasting setting. [HoleEntryScreen] arms it
/// automatically when the round's course has no saved card yet — exactly the
/// first-play case — and resets it when the active round changes.
class CourseSyncEnabled extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;

  void toggle() => state = !state;
}

final courseSyncEnabledProvider =
    NotifierProvider<CourseSyncEnabled, bool>(CourseSyncEnabled.new);
