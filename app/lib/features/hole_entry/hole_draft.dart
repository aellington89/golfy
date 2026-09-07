import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show listEquals;

import '../../data/database.dart';
import '../../data/models/hole_shot_input.dart';

/// One shot's editable fields in the Hole Entry form (#22). Value type; its
/// `shotNumber` is assigned from position in [HoleDraft.shots] on save.
class ShotDraft {
  const ShotDraft({this.club, this.distanceYards, this.lie, this.result});

  final String? club;
  final int? distanceYards;
  final String? lie;
  final String? result;

  factory ShotDraft.fromHoleShot(HoleShot s) => ShotDraft(
        club: s.club,
        distanceYards: s.distanceYards,
        lie: s.lie,
        result: s.result,
      );

  HoleShotInput toInput() => HoleShotInput(
        club: club,
        distanceYards: distanceYards,
        lie: lie,
        result: result,
      );

  ShotDraft copyWith({
    Object? club = _sentinel,
    Object? distanceYards = _sentinel,
    Object? lie = _sentinel,
    Object? result = _sentinel,
  }) {
    return ShotDraft(
      club: identical(club, _sentinel) ? this.club : club as String?,
      distanceYards: identical(distanceYards, _sentinel)
          ? this.distanceYards
          : distanceYards as int?,
      lie: identical(lie, _sentinel) ? this.lie : lie as String?,
      result: identical(result, _sentinel) ? this.result : result as String?,
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
          result == other.result;

  @override
  int get hashCode => Object.hash(club, distanceYards, lie, result);
}

/// Mutable in-memory state for a single hole's entry form. Lives in the
/// parent [HoleEntryScreen]'s state map so the user can swipe between holes
/// in the PageView without losing un-saved edits.
///
/// Holds the hole-level fields, `yards` (auto-filled from the round's yardage
/// set, editable per round — #36), and an ordered [shots] list capturing the
/// club / distance / lie / result of each shot (#22). `score` / `putts` stay
/// the authoritative scoring fields; shots are optional and need not sum to the
/// score. Shots persist to the separate `hole_shots` table via
/// [GolfyRepository.saveHole].
class HoleDraft {
  const HoleDraft({
    required this.par,
    required this.yards,
    required this.score,
    required this.fairwayHit,
    required this.gir,
    required this.putts,
    required this.upDownAttempt,
    required this.upDownSuccess,
    required this.bunkerVisited,
    required this.sandSave,
    required this.penaltyStrokes,
    required this.shots,
    required this.notes,
  });

  /// Default values for a hole the user hasn't touched yet. Score mirrors
  /// par so a hurried "save" still records an even-par score. Putts default to
  /// 1, the common one-putt case, so the typical entry needs fewer taps. No
  /// shots are pre-populated.
  factory HoleDraft.initial({int par = 4, int yards = 0}) {
    return HoleDraft(
      par: par,
      yards: yards,
      score: par,
      fairwayHit: null,
      gir: false,
      putts: 1,
      upDownAttempt: false,
      upDownSuccess: false,
      bunkerVisited: false,
      sandSave: false,
      penaltyStrokes: 0,
      shots: const [],
      notes: '',
    );
  }

  /// Seed a draft from a previously-saved hole_results row. The [shots] are
  /// stored separately (`hole_shots`) and attached by the caller via
  /// `copyWith(shots: …)`, so they default to empty here.
  factory HoleDraft.fromHoleResult(HoleResult h) {
    return HoleDraft(
      par: h.par,
      yards: h.yards,
      score: h.score,
      fairwayHit: h.fairwayHit,
      gir: h.gir,
      putts: h.putts,
      upDownAttempt: h.upDownAttempt,
      upDownSuccess: h.upDownSuccess,
      bunkerVisited: h.bunkerVisited,
      sandSave: h.sandSave,
      penaltyStrokes: h.penaltyStrokes,
      shots: const [],
      notes: h.notes ?? '',
    );
  }

  final int par;
  final int yards;
  final int score;
  final bool? fairwayHit;
  final bool gir;
  final int putts;
  final bool upDownAttempt;
  final bool upDownSuccess;
  final bool bunkerVisited;
  final bool sandSave;
  final int penaltyStrokes;

  /// The hole's ordered shot list (#22); may be empty.
  final List<ShotDraft> shots;

  final String notes;

  HoleDraft copyWith({
    int? par,
    int? yards,
    int? score,
    Object? fairwayHit = _sentinel,
    bool? gir,
    int? putts,
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
      gir: gir ?? this.gir,
      putts: putts ?? this.putts,
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
      gir: gir,
      putts: putts,
      upDownAttempt: upDownAttempt,
      upDownSuccess: upDownSuccess,
      penaltyStrokes: penaltyStrokes,
      bunkerVisited: bunkerVisited,
      sandSave: sandSave,
      notes: trimmedNotes.isEmpty ? const Value.absent() : Value(trimmedNotes),
    );
  }

  /// The shot list as repository inputs (order preserved → shot numbers), for
  /// [GolfyRepository.saveHole]. Empty shots (no club / distance / lie / result)
  /// are dropped so an untouched trailing row isn't persisted.
  List<HoleShotInput> shotInputs() => [
        for (final s in shots)
          if (s.club != null ||
              s.distanceYards != null ||
              s.lie != null ||
              s.result != null)
            s.toInput(),
      ];

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
          putts == other.putts &&
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
        putts,
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
