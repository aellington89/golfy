import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The id of the round currently being viewed / edited on the Hole Entry
/// tab. Set when a round is created (or, later, when the user resumes one
/// from the rounds list) and read by [HoleEntryScreen] to decide between
/// the empty state and the per-hole form (#10).
///
/// `null` means "no active round" — Hole Entry then shows #16's empty state.
class ActiveRoundId extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int id) => state = id;
  void clear() => state = null;
}

final activeRoundIdProvider =
    NotifierProvider<ActiveRoundId, int?>(ActiveRoundId.new);
