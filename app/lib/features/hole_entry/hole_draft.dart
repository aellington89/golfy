import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show listEquals;

import '../../data/database.dart';
import '../../data/models/hole_shot_input.dart';

// Shot values the form reads or writes on its own account, rather than ones a
// player only ever picks from a list: every tee shot is played from the tee,
// every putt is a putter from the green, and the last stroke of a hole is the
// one that was holed.
const String teeLie = 'Tee';
const String greenLie = 'Green';
const String putterClub = 'Putter';
const String holedResult = 'Holed';
const String penaltyResult = 'Penalty';

/// One shot's editable fields in the Hole Entry form (#22). Value type; its
/// `shotNumber` is assigned from position in [HoleDraft.shotInputs] on save.
class ShotDraft {
  const ShotDraft({
    this.club,
    this.distanceYards,
    this.lie,
    this.result,
    this.distanceFeet,
  });

  /// A putt: a putter from the green, measured in feet to the hole.
  const ShotDraft.putt({this.distanceFeet})
      : club = putterClub,
        distanceYards = null,
        lie = greenLie,
        result = null;

  /// A hole's tee shot before anything about it is entered. It is the only shot
  /// whose distance is known in advance: the whole hole is in front of it.
  factory ShotDraft.tee(int holeYards) => ShotDraft(
        lie: teeLie,
        distanceYards: holeYards > 0 ? holeYards : null,
      );

  final String? club;
  final int? distanceYards;
  final String? lie;
  final String? result;

  /// A putt's distance to the hole, in feet. Null for every other shot, whose
  /// distance is [distanceYards].
  final int? distanceFeet;

  factory ShotDraft.fromHoleShot(HoleShot s) => ShotDraft(
        club: s.club,
        distanceYards: s.distanceYards,
        lie: s.lie,
        result: s.result,
        distanceFeet: s.distanceFeet,
      );

  HoleShotInput toInput() => HoleShotInput(
        club: club,
        distanceYards: distanceYards,
        lie: lie,
        result: result,
        distanceFeet: distanceFeet,
      );

  /// Nothing about this shot has been entered yet. Such a row is a placeholder
  /// the form laid out — an "Add shot" tap, or a suggestion the hole's own
  /// fields couldn't fill in — rather than a shot the player recorded.
  bool get isBlank =>
      club == null &&
      distanceYards == null &&
      lie == null &&
      result == null &&
      distanceFeet == null;

  bool get isPenalty => result == penaltyResult;

  /// Whether a row of a saved shot list is a putt. A [HoleDraft] keeps its
  /// putts apart from the shots before them ([HoleDraft.puttShots]), so this is
  /// how a saved list is split on load.
  bool get isPutt => club == putterClub || lie == greenLie;

  ShotDraft copyWith({
    Object? club = _sentinel,
    Object? distanceYards = _sentinel,
    Object? lie = _sentinel,
    Object? result = _sentinel,
    Object? distanceFeet = _sentinel,
  }) {
    return ShotDraft(
      club: identical(club, _sentinel) ? this.club : club as String?,
      distanceYards: identical(distanceYards, _sentinel)
          ? this.distanceYards
          : distanceYards as int?,
      lie: identical(lie, _sentinel) ? this.lie : lie as String?,
      result: identical(result, _sentinel) ? this.result : result as String?,
      distanceFeet: identical(distanceFeet, _sentinel)
          ? this.distanceFeet
          : distanceFeet as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShotDraft &&
          runtimeType == other.runtimeType &&
          club == other.club &&
          distanceYards == other.distanceYards &&
          lie == other.lie &&
          result == other.result &&
          distanceFeet == other.distanceFeet;

  @override
  int get hashCode =>
      Object.hash(club, distanceYards, lie, result, distanceFeet);
}

/// Mutable in-memory state for a single hole's entry form. Lives in the
/// parent [HoleEntryScreen]'s state map so the user can swipe between holes
/// in the PageView without losing un-saved edits.
///
/// Holds the hole-level fields, `yards` (auto-filled from the round's yardage
/// set, editable per round — #36), and every stroke as two ordered lists (#22):
/// [shots], the strokes played before putting — the tee shot first, then every
/// approach and around-the-green shot — and [puttShots], the putts. [putts] is
/// simply how many putt rows there are, so the count and the rows can never
/// disagree. `score` stays the authoritative scoring field; the form keeps it in
/// step with [countedScore] and won't save a hole where they differ (see
/// `hole_rules.dart`). Shots persist to the separate `hole_shots` table via
/// [GolfyRepository.saveHole].
class HoleDraft {
  const HoleDraft({
    required this.par,
    required this.yards,
    required this.score,
    required this.fairwayHit,
    required this.gir,
    required this.puttShots,
    required this.upDownAttempt,
    required this.upDownSuccess,
    required this.bunkerVisited,
    required this.sandSave,
    required this.penaltyStrokes,
    required this.shots,
    required this.notes,
  });

  /// Default values for a hole the user hasn't touched yet: the tee shot laid
  /// out, one putt (the common case, so the typical entry needs fewer taps —
  /// #52), and a score that is simply the count of those strokes. Nothing about
  /// the tee shot's result is assumed — [fairwayHit] and [gir] start unanswered,
  /// and the form won't save until the tee shot's result is recorded.
  factory HoleDraft.initial({int par = 4, int yards = 0}) {
    final shots = [ShotDraft.tee(yards)];
    const puttShots = [ShotDraft.putt()];
    return HoleDraft(
      par: par,
      yards: yards,
      score: shots.length + puttShots.length,
      fairwayHit: null,
      gir: null,
      puttShots: puttShots,
      upDownAttempt: false,
      upDownSuccess: false,
      bunkerVisited: false,
      sandSave: false,
      penaltyStrokes: 0,
      shots: shots,
      notes: '',
    );
  }

  /// Seed a draft from a previously-saved hole_results row and the hole's saved
  /// [shots] (`hole_shots`, stored separately).
  ///
  /// The saved list is split where putting starts and brought into the shape
  /// the form edits. The putts are the putt rows the list ends on — as many as
  /// the row's `putts` count, which is what the stats read — and a hole saved
  /// with fewer putt rows than that (anything entered before #22, or before
  /// putts had rows of their own) gets the rest laid out, blank. A `Holed`
  /// result comes off (it always belongs to the last stroke, so it is
  /// re-derived on save), and a hole saved with no shots at all gets its tee
  /// shot laid out. Both the live draft and the saved snapshot it is compared
  /// against are built here, so a hole that has only been opened still reads
  /// "Saved".
  factory HoleDraft.fromSaved(HoleResult h, [List<ShotDraft> shots = const []]) {
    final rows = [
      for (final s in shots)
        s.result == holedResult ? s.copyWith(result: null) : s,
    ];
    // The first row is the tee shot whatever it holds, so it is never taken
    // for a putt.
    var start = rows.length;
    while (start > 1 &&
        rows.length - start < h.putts &&
        rows[start - 1].isPutt) {
      start--;
    }
    final before = rows.sublist(0, start);
    if (before.isEmpty) {
      before.add(ShotDraft.tee(h.yards));
    } else if (before.first.lie == null) {
      before[0] = before.first.copyWith(lie: teeLie);
    }
    return HoleDraft(
      par: h.par,
      yards: h.yards,
      score: h.score,
      fairwayHit: h.fairwayHit,
      gir: h.gir,
      puttShots: [
        ...rows.sublist(start),
        for (var i = rows.length - start; i < h.putts; i++)
          const ShotDraft.putt(),
      ],
      upDownAttempt: h.upDownAttempt,
      upDownSuccess: h.upDownSuccess,
      bunkerVisited: h.bunkerVisited,
      sandSave: h.sandSave,
      penaltyStrokes: h.penaltyStrokes,
      shots: before,
      notes: h.notes ?? '',
    );
  }

  final int par;
  final int yards;
  final int score;
  final bool? fairwayHit;

  /// Green in regulation. `null` until the tee shot's result is recorded: on a
  /// par 3 this *is* that result ("Green hit?"), and on a par 4 or 5 it is
  /// derived from the strokes it took to reach the green once the tee shot is
  /// in. Saved as `false` if it somehow never was.
  final bool? gir;

  /// The putts, in order: each a putter from the green, with its distance to
  /// the hole in feet. Empty when the hole was finished from off the green.
  final List<ShotDraft> puttShots;

  final bool upDownAttempt;
  final bool upDownSuccess;
  final bool bunkerVisited;
  final bool sandSave;
  final int penaltyStrokes;

  /// The strokes played before putting, in order (#22): the tee shot first,
  /// then the approach and around-the-green shots. Putts are [puttShots].
  final List<ShotDraft> shots;

  final String notes;

  /// How many putts the hole took — the `putts` the stats read.
  int get putts => puttShots.length;

  /// Strokes played before the first putt — at least the tee shot, even for a
  /// draft whose list is empty.
  int get strokesBeforePutting => shots.isEmpty ? 1 : shots.length;

  /// What the score is when every stroke is accounted for: the shots, the
  /// putts, and the penalty strokes that aren't shots at all.
  int get countedScore => strokesBeforePutting + putts + penaltyStrokes;

  HoleDraft copyWith({
    int? par,
    int? yards,
    int? score,
    Object? fairwayHit = _sentinel,
    Object? gir = _sentinel,
    List<ShotDraft>? puttShots,
    bool? upDownAttempt,
    bool? upDownSuccess,
    bool? bunkerVisited,
    bool? sandSave,
    int? penaltyStrokes,
    List<ShotDraft>? shots,
    String? notes,
  }) {
    return HoleDraft(
      par: par ?? this.par,
      yards: yards ?? this.yards,
      score: score ?? this.score,
      fairwayHit: identical(fairwayHit, _sentinel)
          ? this.fairwayHit
          : fairwayHit as bool?,
      gir: identical(gir, _sentinel) ? this.gir : gir as bool?,
      puttShots: puttShots ?? this.puttShots,
      upDownAttempt: upDownAttempt ?? this.upDownAttempt,
      upDownSuccess: upDownSuccess ?? this.upDownSuccess,
      bunkerVisited: bunkerVisited ?? this.bunkerVisited,
      sandSave: sandSave ?? this.sandSave,
      penaltyStrokes: penaltyStrokes ?? this.penaltyStrokes,
      shots: shots ?? this.shots,
      notes: notes ?? this.notes,
    );
  }

  /// Builds the drift companion for the hole_results upsert. Every column the
  /// form captures carries its real value; the flat shot columns are gone (#22)
  /// — shots persist separately via [shotInputs].
  HoleResultsCompanion toCompanion({
    required int roundId,
    required int holeNumber,
  }) {
    final trimmedNotes = notes.trim();
    return HoleResultsCompanion.insert(
      roundId: roundId,
      holeNumber: holeNumber,
      par: par,
      score: score,
      yards: yards,
      fairwayHit: Value(fairwayHit),
      gir: gir ?? false,
      putts: putts,
      upDownAttempt: upDownAttempt,
      upDownSuccess: upDownSuccess,
      penaltyStrokes: penaltyStrokes,
      bunkerVisited: bunkerVisited,
      sandSave: sandSave,
      notes: trimmedNotes.isEmpty ? const Value.absent() : Value(trimmedNotes),
    );
  }

  /// Every stroke of the hole as repository inputs (order preserved → shot
  /// numbers), for [GolfyRepository.saveHole]: [shots], then [puttShots], with
  /// the final stroke holed.
  ///
  /// A blank row is kept wherever it sits. Each row is a stroke the score
  /// counts, and a shot's number is its place in the hole's chronology, so
  /// dropping one would renumber every shot after it and delete a row the
  /// player is part-way through filling in — such as the one a par-3 tee shot
  /// that misses the green leaves behind, since nothing says where it finished
  /// until the lie is picked.
  List<HoleShotInput> shotInputs() {
    final strokes = <ShotDraft>[...shots, ...puttShots];
    // A stroke that cost a penalty wasn't the one that went in, so it is left
    // as it is; the form won't save a hole that ends that way anyway.
    if (strokes.isNotEmpty && strokes.last.result == null) {
      strokes.last = strokes.last.copyWith(result: holedResult);
    }
    return [for (final s in strokes) s.toInput()];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HoleDraft &&
          runtimeType == other.runtimeType &&
          par == other.par &&
          yards == other.yards &&
          score == other.score &&
          fairwayHit == other.fairwayHit &&
          gir == other.gir &&
          listEquals(puttShots, other.puttShots) &&
          upDownAttempt == other.upDownAttempt &&
          upDownSuccess == other.upDownSuccess &&
          bunkerVisited == other.bunkerVisited &&
          sandSave == other.sandSave &&
          penaltyStrokes == other.penaltyStrokes &&
          listEquals(shots, other.shots) &&
          notes == other.notes;

  @override
  int get hashCode => Object.hash(
        par,
        yards,
        score,
        fairwayHit,
        gir,
        Object.hashAll(puttShots),
        upDownAttempt,
        upDownSuccess,
        bunkerVisited,
        sandSave,
        penaltyStrokes,
        Object.hashAll(shots),
        notes,
      );
}

const Object _sentinel = Object();
