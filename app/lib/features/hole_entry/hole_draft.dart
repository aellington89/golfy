import 'package:drift/drift.dart' show Value;

import '../../data/database.dart';

/// Mutable in-memory state for a single hole's entry form. Lives in the
/// parent [HoleEntryScreen]'s state map so the user can swipe between holes
/// in the PageView without losing un-saved edits.
///
/// Holds the fields surfaced in #10's spec, the `bunkerVisited` / `sandSave`
/// pair, and `yards` — the hole's length, auto-filled from the course template
/// when one exists and editable per round (#36). The three remaining
/// `hole_results` columns (`driveDistanceYards`, `approachDistanceYards`,
/// `teeClub`) are still written with placeholder defaults until the per-round
/// shot-tracking inputs ship (tracked in issue #22).
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
    required this.notes,
  });

  /// Default values for a hole the user hasn't touched yet. Score mirrors
  /// par so a hurried "save" still records an even-par score — visually
  /// distinct on the dashboard if it wasn't intentional. Putts default to 1,
  /// the common case for a routine one-putt / regulation hole, so the typical
  /// entry needs fewer taps.
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
      notes: '',
    );
  }

  /// Seed a draft from a previously-saved row. Reads the fields the form
  /// exposes (now including `yards`); the three shot columns still deferred to
  /// #22 are ignored on load and re-written with their placeholder defaults on
  /// the next upsert.
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
      notes: notes ?? this.notes,
    );
  }

  /// Builds the drift companion for an upsert. `yards` now carries the real
  /// value (auto-filled from the course template, editable per round — #36).
  /// The three shot columns (`driveDistanceYards`, `approachDistanceYards`,
  /// `teeClub`) are still stamped with placeholder defaults until issue #22
  /// adds their inputs.
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
      driveDistanceYards: 0,
      notes: trimmedNotes.isEmpty ? const Value.absent() : Value(trimmedNotes),
    );
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
          putts == other.putts &&
          upDownAttempt == other.upDownAttempt &&
          upDownSuccess == other.upDownSuccess &&
          bunkerVisited == other.bunkerVisited &&
          sandSave == other.sandSave &&
          penaltyStrokes == other.penaltyStrokes &&
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
        notes,
      );
}

const Object _sentinel = Object();
