import 'hole_draft.dart';
import 'shot_inference.dart';

/// How a hole's fields follow from one another as the Hole Entry form is filled
/// in, and what has to be true before it can be saved.
///
/// Pure Dart on purpose — no Flutter import — so every rule is covered by fast
/// unit tests instead of widget pumps. `hole_card.dart` routes each edit
/// through one of the functions below and renders [holeIssues]; it decides
/// nothing itself.
///
/// Two kinds of rule live here:
///
///  * **Derived fields** ([applyEdit]). A field that follows from others —
///    score from the strokes, GIR from the strokes it took to reach the green,
///    up & down success from the putts, bunker visited from the lies — is
///    re-derived whenever one of *its* inputs changes, and only then. So a value
///    the player overrides sticks until something it depends on moves.
///    Combinations that can't happen (a success with no attempt, a GIR after
///    three shots to a par 4) are forced, which also keeps every draft inside
///    the invariants `HoleResultDao` enforces.
///  * **Issues** ([holeIssues]). A blocking issue stops the save — the tee
///    shot's result is missing, or the score disagrees with the strokes
///    recorded. A warning is worth a look but never blocks.

const String _fairwayLie = 'Fairway';
const String _lightRoughLie = 'Light Rough';
const String _bunkerLie = 'Bunker';

/// Whether the tee shot's result has been recorded: "Fairway hit?" on a par 4
/// or 5, and "Green hit?" — which is GIR — on a par 3.
bool teeShotAnswered(HoleDraft d) =>
    d.par == 3 ? d.gir != null : d.fairwayHit != null;

/// Strokes it took to reach the green: everything before the first putt,
/// penalty strokes included.
int strokesToGreen(HoleDraft d) => d.strokesBeforePutting + d.penaltyStrokes;

/// Whether the strokes recorded leave room for a green in regulation — on the
/// green in par − 2. A ball holed from off the green in that many counts too.
bool girPossible(HoleDraft d) => strokesToGreen(d) <= d.par - 2;

/// Shots that ended in a penalty (OB, water, lost ball).
int penaltyShotCount(HoleDraft d) => d.shots.where((s) => s.isPenalty).length;

bool _playedFromBunker(HoleDraft d) => d.shots.any((s) => s.lie == _bunkerLie);

String? _lastLie(HoleDraft d) => d.shots.isEmpty ? null : d.shots.last.lie;

/// [d] with its tee shot laid out, if its list is empty.
HoleDraft withTeeShot(HoleDraft d) =>
    d.shots.isNotEmpty ? d : d.copyWith(shots: [ShotDraft.tee(d.yards)]);

// ---------------------------------------------------------------------------
// Edits
// ---------------------------------------------------------------------------

/// [after] — an edit of [before] — with every field derived from what the edit
/// changed brought back into line.
///
/// The plain fields (penalties, the switches, score) are edited with
/// `copyWith` and passed through here; edits with side effects of their own —
/// shots and putts among them — have functions below, which end here too.
HoleDraft applyEdit(HoleDraft before, HoleDraft after) {
  var d = after;

  // Bunker visited is a fact about the lies: on while any shot is played from
  // a bunker, and off again when the last such lie goes.
  final bunker = _playedFromBunker(d);
  if (bunker && !d.bunkerVisited) {
    d = d.copyWith(bunkerVisited: true);
  } else if (!bunker && _playedFromBunker(before) && d.bunkerVisited) {
    d = d.copyWith(bunkerVisited: false);
  }

  // The score keeps itself in step with the strokes for as long as it agreed
  // with them. Once it doesn't — the player set it by hand, or the hole was
  // saved before shots were counted — it stays where it is, and holeIssues
  // says how far apart the two are.
  if (d.countedScore != before.countedScore &&
      before.score == before.countedScore) {
    d = d.copyWith(score: d.countedScore);
  }

  // GIR follows the strokes it took to reach the green, once the tee shot's
  // result is in. On a par 3 that result *is* GIR, so answering it is not
  // re-derived — but a shot or penalty added after it is.
  if (teeShotAnswered(d)) {
    final structureChanged =
        d.strokesBeforePutting != before.strokesBeforePutting ||
            d.penaltyStrokes != before.penaltyStrokes ||
            d.par != before.par;
    final justAnswered = !teeShotAnswered(before) && d.par != 3;
    if (structureChanged || justAnswered) {
      d = d.copyWith(gir: girPossible(d));
    }
  }
  // More strokes than par − 2 to reach the green can't be a GIR. A par 3's
  // answer is the player's word, so a clash there is an issue, not a rewrite.
  if (d.par != 3 && d.gir == true && !girPossible(d)) {
    d = d.copyWith(gir: false);
  }

  // An up & down is getting in from off the green in two: an attempt that
  // needed one putt or none succeeded, and one that needed more didn't.
  if (!d.upDownAttempt || d.putts > 1) {
    if (d.upDownSuccess) d = d.copyWith(upDownSuccess: false);
  } else if (d.upDownAttempt != before.upDownAttempt ||
      d.putts != before.putts) {
    d = d.copyWith(upDownSuccess: true);
  }

  // A sand save is an up & down from a greenside bunker. When the lies say
  // where the shot before putting came from, that decides it; when they don't,
  // the switch is the player's.
  if (!d.bunkerVisited || d.putts > 1) {
    if (d.sandSave) d = d.copyWith(sandSave: false);
  } else {
    final lastLie = _lastLie(d);
    final inputsChanged = d.putts != before.putts ||
        d.bunkerVisited != before.bunkerVisited ||
        d.shots.length != before.shots.length ||
        lastLie != _lastLie(before);
    if (inputsChanged && lastLie != null) {
      d = d.copyWith(sandSave: lastLie == _bunkerLie);
    }
  }

  return d;
}

/// Changes par. Moving to or from a par 3 changes what the tee shot's result
/// even is (fairway vs. green), so the answer is cleared to be given again —
/// and a par 3 has no fairway, which `HoleResultDao` insists on.
HoleDraft changePar(HoleDraft d, int par) {
  if (par == d.par) return d;
  final resetTee = par == 3 || d.par == 3;
  return applyEdit(
    d,
    d.copyWith(
      par: par,
      fairwayHit: resetTee ? null : d.fairwayHit,
      gir: resetTee ? null : d.gir,
    ),
  );
}

/// Changes the hole's yardage, carrying the tee shot's distance along unless
/// the player has typed one of their own.
HoleDraft changeYards(HoleDraft d, int yards) {
  var shots = d.shots;
  if (shots.isNotEmpty) {
    final tee = shots.first;
    if (tee.distanceYards == null || tee.distanceYards == d.yards) {
      shots = [
        tee.copyWith(distanceYards: yards > 0 ? yards : null),
        ...shots.skip(1),
      ];
    }
  }
  return applyEdit(d, d.copyWith(yards: yards, shots: shots));
}

/// Records the tee shot's result: whether it found the fairway on a par 4 or
/// 5, or the green on a par 3.
///
/// On a par 4 or 5, shot 2 is played from wherever the tee shot finished, so it
/// is laid out with that lie the first time the question is answered, and its
/// lie follows a changed answer afterwards. On a par 3 a miss lays out shot 2
/// for the player to say where it went, and a hit clears approach rows nothing
/// was entered in — after a green hit, what comes next is putting.
HoleDraft answerTeeShot(HoleDraft d, bool hit) {
  d = withTeeShot(d);
  final firstAnswer = !teeShotAnswered(d);
  final shots = [...d.shots];
  if (d.par == 3) {
    if (hit) {
      while (shots.length > 1 && shots.last.isBlank) {
        shots.removeLast();
      }
    } else if (firstAnswer && shots.length == 1) {
      shots.add(const ShotDraft());
    }
    return applyEdit(d, d.copyWith(gir: hit, shots: shots));
  }

  // After a penalty off the tee the ball is dropped somewhere the answer
  // doesn't describe, so it sets no lie.
  final teePenalty = shots.first.isPenalty;
  if (shots.length == 1) {
    if (firstAnswer) {
      shots.add(ShotDraft(lie: teePenalty ? null : lieAfterTeeShot(hit)));
    }
  } else {
    final second = shots[1];
    if (hit) {
      shots[1] = second.copyWith(lie: _fairwayLie);
    } else if (second.lie == null || second.lie == _fairwayLie) {
      shots[1] = second.copyWith(lie: teePenalty ? null : _lightRoughLie);
    }
  }
  return applyEdit(d, d.copyWith(fairwayHit: hit, shots: shots));
}

/// Appends the next shot before putting — see [suggestNextShot].
HoleDraft addShot(HoleDraft d) =>
    applyEdit(d, d.copyWith(shots: [...d.shots, suggestNextShot(d)]));

/// Replaces the shot at [index] with [shot].
///
/// A shot marked as a penalty adds its penalty stroke, and unmarking it takes
/// the stroke back off. Shot 2's lie on a par 4 or 5 is where the tee shot
/// finished, so it answers "Fairway hit?". A tee shot that cost a penalty
/// found neither the fairway nor the green.
HoleDraft updateShot(HoleDraft d, int index, ShotDraft shot) {
  d = withTeeShot(d);
  final old = d.shots[index];
  var next = d.copyWith(shots: [...d.shots]..[index] = shot);

  if (shot.isPenalty != old.isPenalty) {
    final strokes = d.penaltyStrokes + (shot.isPenalty ? 1 : -1);
    next = next.copyWith(penaltyStrokes: strokes < 0 ? 0 : strokes);
  }

  if (index == 1 && d.par != 3 && shot.lie != old.lie) {
    final hit = switch (shot.lie) {
      null || teeLie => null,
      _fairwayLie => true,
      _ => false,
    };
    if (hit != null) next = next.copyWith(fairwayHit: hit);
  }

  next = applyEdit(d, next);

  if (index == 0 && shot.isPenalty && !old.isPenalty) {
    final answer = next.par == 3 ? next.gir : next.fairwayHit;
    if (answer != false) next = answerTeeShot(next, false);
  }
  return next;
}

/// Removes the shot at [index]. The tee shot is always there, so index 0 is a
/// no-op.
HoleDraft removeShot(HoleDraft d, int index) {
  if (index <= 0 || index >= d.shots.length) return d;
  final removed = d.shots[index];
  var next = d.copyWith(shots: [...d.shots]..removeAt(index));
  if (removed.isPenalty && d.penaltyStrokes > 0) {
    next = next.copyWith(penaltyStrokes: d.penaltyStrokes - 1);
  }
  return applyEdit(d, next);
}

/// Appends a putt. Nothing is known about it until its distance is entered.
HoleDraft addPutt(HoleDraft d) => applyEdit(
      d,
      d.copyWith(puttShots: [...d.puttShots, const ShotDraft.putt()]),
    );

/// Replaces the putt at [index] with [putt].
HoleDraft updatePutt(HoleDraft d, int index, ShotDraft putt) => applyEdit(
      d,
      d.copyWith(puttShots: [...d.puttShots]..[index] = putt),
    );

/// Removes the putt at [index]. Removing the only one leaves a hole finished
/// from off the green.
HoleDraft removePutt(HoleDraft d, int index) {
  if (index < 0 || index >= d.puttShots.length) return d;
  return applyEdit(
    d,
    d.copyWith(puttShots: [...d.puttShots]..removeAt(index)),
  );
}

/// Fix: lays out as many shots as the score is ahead of the strokes recorded.
/// The fast way to enter a hole from its score alone — and to bring a hole
/// saved before shots were counted into line.
HoleDraft addShotsToMatchScore(HoleDraft d) {
  var next = withTeeShot(d);
  for (var i = next.countedScore; i < d.score; i++) {
    next = next.copyWith(shots: [...next.shots, suggestNextShot(next)]);
  }
  return applyEdit(d, next);
}

/// Fix: sets the score to the strokes recorded.
HoleDraft matchScoreToShots(HoleDraft d) =>
    applyEdit(d, d.copyWith(score: d.countedScore));

/// Fix: counts a penalty stroke for every shot marked as a penalty.
HoleDraft countPenaltyShots(HoleDraft d) =>
    applyEdit(d, d.copyWith(penaltyStrokes: penaltyShotCount(d)));

/// Fix: turns a last shot played from the green into the putt it was — the
/// first putt, carrying its distance to the pin over in feet. The score doesn't
/// move: the stroke just changes section.
HoleDraft countLastShotAsPutt(HoleDraft d) {
  if (d.shots.length < 2) return d;
  final yards = d.shots.last.distanceYards;
  return applyEdit(
    d,
    d.copyWith(
      shots: d.shots.sublist(0, d.shots.length - 1),
      puttShots: [
        ShotDraft.putt(distanceFeet: yards == null ? null : yards * 3),
        ...d.puttShots,
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Issues
// ---------------------------------------------------------------------------

/// What an issue is about, so the form can point at the right field and tests
/// can find it without matching on wording.
enum HoleIssueKind {
  teeShotResult,
  greenHitWithShots,
  scoreMismatch,
  penaltyShots,
  unholedFinish,
  shotFromGreen,
  upDownWithGir,
}

/// A one-tap correction offered alongside an issue.
class HoleFix {
  const HoleFix({required this.id, required this.label, required this.apply});

  /// Stable name for the fix, used for its widget key.
  final String id;
  final String label;
  final HoleDraft Function(HoleDraft) apply;
}

class HoleIssue {
  const HoleIssue({
    required this.kind,
    required this.message,
    required this.blocking,
    this.fixes = const [],
  });

  final HoleIssueKind kind;
  final String message;

  /// Whether the hole can't be saved until this is resolved.
  final bool blocking;
  final List<HoleFix> fixes;
}

String _plural(int n, String one, [String? many]) =>
    '$n ${n == 1 ? one : (many ?? '${one}s')}';

/// How [HoleDraft.countedScore] is made up, e.g. "3 shots + 2 putts + 1
/// penalty".
String strokeTally(HoleDraft d) {
  final parts = [
    _plural(d.strokesBeforePutting, 'shot'),
    _plural(d.putts, 'putt'),
    if (d.penaltyStrokes > 0) _plural(d.penaltyStrokes, 'penalty', 'penalties'),
  ];
  return parts.join(' + ');
}

/// Everything about [d] that stops it being saved, then everything merely
/// worth a second look — in the order a hole is played.
List<HoleIssue> holeIssues(HoleDraft d) {
  final issues = <HoleIssue>[];

  if (!teeShotAnswered(d)) {
    issues.add(HoleIssue(
      kind: HoleIssueKind.teeShotResult,
      blocking: true,
      message: d.par == 3
          ? 'Tee shot: say whether it found the green.'
          : 'Tee shot: say whether it found the fairway.',
    ));
  }

  if (d.par == 3 && d.gir == true && !girPossible(d)) {
    final extra = strokesToGreen(d) - 1;
    issues.add(HoleIssue(
      kind: HoleIssueKind.greenHitWithShots,
      blocking: true,
      message: 'The tee shot found the green, so every stroke after it is a '
          'putt — but ${_plural(extra, 'more stroke')} '
          '${extra == 1 ? 'comes' : 'come'} before the first putt.',
    ));
  }

  final penaltyShots = penaltyShotCount(d);
  if (penaltyShots > d.penaltyStrokes) {
    issues.add(HoleIssue(
      kind: HoleIssueKind.penaltyShots,
      blocking: true,
      message: '${_plural(penaltyShots, 'shot')} '
          '${penaltyShots == 1 ? 'ends' : 'end'} in a penalty, but '
          '${_plural(d.penaltyStrokes, 'penalty stroke')} '
          '${d.penaltyStrokes == 1 ? 'is' : 'are'} counted.',
      fixes: [
        HoleFix(
          id: 'count_penalties',
          label: 'Count ${_plural(penaltyShots, 'penalty stroke')}',
          apply: countPenaltyShots,
        ),
      ],
    ));
  }

  if (d.putts == 0 && d.shots.isNotEmpty && d.shots.last.isPenalty) {
    issues.add(HoleIssue(
      kind: HoleIssueKind.unholedFinish,
      blocking: true,
      message: 'With no putts, shot ${d.shots.length} is the one that went in '
          '— but it ends in a penalty.',
    ));
  }

  final counted = d.countedScore;
  if (d.score != counted) {
    final short = d.score - counted;
    issues.add(HoleIssue(
      kind: HoleIssueKind.scoreMismatch,
      blocking: true,
      message: 'Score is ${d.score}, but the strokes recorded add up to '
          '$counted (${strokeTally(d)}).',
      fixes: [
        if (short > 0)
          HoleFix(
            id: 'add_shots',
            label: 'Add ${_plural(short, 'shot')}',
            apply: addShotsToMatchScore,
          ),
        HoleFix(
          id: 'match_score',
          label: 'Make the score $counted',
          apply: matchScoreToShots,
        ),
      ],
    ));
  }

  // A stroke played from the green is a putt, and recording it as a shot
  // under-counts the putts. Chipping off a green does happen, so this asks
  // rather than blocks; the fix is offered when it's the last shot, which is
  // where a putt recorded in the wrong place ends up.
  for (var i = 1; i < d.shots.length; i++) {
    if (d.shots[i].lie != greenLie) continue;
    final last = i == d.shots.length - 1;
    issues.add(HoleIssue(
      kind: HoleIssueKind.shotFromGreen,
      blocking: false,
      message: 'Shot ${i + 1} is played from the green, which makes it a putt.',
      fixes: [
        if (last)
          const HoleFix(
            id: 'count_as_putt',
            label: 'Count it as a putt',
            apply: countLastShotAsPutt,
          ),
      ],
    ));
    break;
  }

  if (d.upDownAttempt && d.gir == true) {
    issues.add(const HoleIssue(
      kind: HoleIssueKind.upDownWithGir,
      blocking: false,
      message: 'An up & down is played from off the green, but GIR says the '
          'green was reached in regulation.',
    ));
  }

  return issues;
}

/// Whether [d] can be saved.
bool canSave(HoleDraft d) => !holeIssues(d).any((i) => i.blocking);
