import 'package:drift/drift.dart';

/// A named competition or outing that groups one or more [Rounds] — a club
/// tournament, league night, charity scramble, or a casual get-together (#35).
/// A round's link is optional (`Rounds.eventId` is nullable); deleting an event
/// detaches its rounds via `SET NULL` rather than destroying their hole data.
///
/// The result is entered by hand once the event concludes and is modelled
/// structurally: a finishing [finishPosition] (1 = win) with a [tied] flag for
/// shared places (renders "T-3"), or [missedCut] when the player was cut. The
/// three are mutually constrained in [EventDao] so a row represents exactly one
/// of "placed", "cut", or "not recorded yet".
class Events extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// Finishing position (1 = win). Null until a result is recorded.
  IntColumn get finishPosition => integer().nullable()();

  /// Whether [finishPosition] was a tie (renders "T-3"). Requires a position.
  BoolColumn get tied => boolean().withDefault(const Constant(false))();

  /// Player missed the cut. Mutually exclusive with [finishPosition] / [tied].
  BoolColumn get missedCut => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {name},
      ];
}
