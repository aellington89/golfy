import 'package:drift/drift.dart';

/// A named competition or outing that groups one or more [Rounds] — a club
/// tournament, league night, charity scramble, or a casual get-together (#35).
/// A round's link is optional (`Rounds.eventId` is nullable); deleting an event
/// detaches its rounds via `SET NULL` rather than destroying their hole data.
///
/// A recurring competition is a distinct occurrence each time it is held, so
/// identity is `(name, season)` — not [name] alone (#47). "The Legends
/// Championship" in [season] 1 and in season 2 are separate rows with separate
/// ids, results, and rounds; nothing is shared across seasons but the name.
///
/// The result is entered by hand once the event concludes and is modelled
/// structurally: a finishing [finishPosition] (1 = win) with a [tied] flag for
/// shared places (renders "T-3"), or [missedCut] when the player was cut. The
/// three are mutually constrained in [EventDao] so a row represents exactly one
/// of "placed", "cut", or "not recorded yet". Because the result lives on the
/// row, each season's occurrence keeps its own — recording one never overwrites
/// another's.
class Events extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// Which occurrence of [name] this is — a 1-based season number (#47).
  /// NOT NULL with a default of 1 (the first/sole occurrence): a nullable
  /// season would defeat the `(name, season)` UNIQUE, since SQLite treats NULLs
  /// as distinct and would let unlimited same-name rows through.
  IntColumn get season => integer().withDefault(const Constant(1))();

  /// Finishing position (1 = win). Null until a result is recorded.
  IntColumn get finishPosition => integer().nullable()();

  /// Whether [finishPosition] was a tie (renders "T-3"). Requires a position.
  BoolColumn get tied => boolean().withDefault(const Constant(false))();

  /// Player missed the cut. Mutually exclusive with [finishPosition] / [tied].
  BoolColumn get missedCut => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {name, season},
      ];
}
