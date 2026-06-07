import 'package:drift/drift.dart' show Value;

import '../../data/database.dart';

/// Mutable in-memory state for a single hole's entry form. Lives in the
/// parent [HoleEntryScreen]'s state map so the user can swipe between holes
/// in the PageView without losing un-saved edits.
///
/// Holds only the 10 fields surfaced in #10's spec plus the
/// `bunkerVisited` / `sandSave` pair (parallel to up/down, per the field-
/// scope decision in the plan). The four remaining `hole_results` columns
/// (`yards`, `driveDistanceYards`, `approachDistanceYards`, `teeClub`) are
/// written with placeholder defaults until the course-yardage feature ships
/// (tracked in issue #22).
class HoleDraft {
  const HoleDraft({
    required this.par,
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
  /// distinct on the dashboard if it wasn't intentional.
  factory HoleDraft.initial({int par = 4}) {
    return HoleDraft(
      par: par,
      score: par,
      fairwayHit: null,
      gir: false,
      putts: 2,
      upDownAttempt: false,
      upDownSuccess: false,
      bunkerVisited: false,
      sandSave: false,
      penaltyStrokes: 0,
      notes: '',
    );
  }

  /// Seed a draft from a previously-saved row. Reads only the fields the
  /// form exposes — the deferred columns are ignored on load and re-written
  /// with their placeholder defaults on the next upsert.
  factory HoleDraft.fromHoleResult(HoleResult h) {
    return HoleDraft(
      par: h.par,
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

  /// Builds the drift companion for an upsert. The four deferred columns
  /// (`yards`, `driveDistanceYards`, `approachDistanceYards`, `teeClub`)
  /// are stamped with placeholder defaults — they'll be replaced by real
  /// inputs when issue #22 ships.
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
      yards: 0,
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
