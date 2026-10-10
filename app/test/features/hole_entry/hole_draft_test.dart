import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/database.dart';
import 'package:golfy_app/features/hole_entry/hole_draft.dart';

HoleResult _saved({
  int par = 4,
  int score = 4,
  int putts = 2,
  int yards = 420,
  bool? fairwayHit = true,
  bool gir = true,
}) =>
    HoleResult(
      id: 1,
      roundId: 1,
      holeNumber: 1,
      par: par,
      score: score,
      yards: yards,
      fairwayHit: fairwayHit,
      gir: gir,
      putts: putts,
      upDownAttempt: false,
      upDownSuccess: false,
      penaltyStrokes: 0,
      bunkerVisited: false,
      sandSave: false,
    );

void main() {
  group('HoleDraft.initial defaults', () {
    test('a fresh hole defaults to 1 putt (#52)', () {
      expect(HoleDraft.initial().putts, 1);
    });

    test('saving an untouched hole records 1 putt', () {
      // The save path passes putts straight through to the companion.
      final companion =
          HoleDraft.initial().toCompanion(roundId: 1, holeNumber: 1);
      expect(companion.putts, const Value(1));
    });

    test('the score is the count of its strokes, so score > putts holds', () {
      final draft = HoleDraft.initial();
      expect(draft.score, draft.countedScore);
      expect(draft.score, 2, reason: 'the tee shot and one putt');
      expect(draft.score, greaterThan(draft.putts));
    });

    test('the tee shot result starts unanswered', () {
      expect(HoleDraft.initial().fairwayHit, isNull);
      expect(HoleDraft.initial().gir, isNull);
      expect(HoleDraft.initial(par: 3).gir, isNull);
    });

    test('an unanswered GIR would save as false, never null', () {
      final companion =
          HoleDraft.initial().toCompanion(roundId: 1, holeNumber: 1);
      expect(companion.gir, const Value(false));
    });
  });

  group('HoleDraft yards (#36)', () {
    test('initial defaults yards to 0', () {
      expect(HoleDraft.initial().yards, 0);
    });

    test('initial can seed par and yards from a course template', () {
      final draft = HoleDraft.initial(par: 5, yards: 540);
      expect(draft.par, 5);
      expect(draft.yards, 540);
    });

    test('toCompanion writes the real yards (not the old placeholder 0)', () {
      final companion =
          HoleDraft.initial(yards: 420).toCompanion(roundId: 1, holeNumber: 1);
      expect(companion.yards, const Value(420));
    });

    test('copyWith replaces yards; equality and hashCode track it', () {
      final base = HoleDraft.initial(yards: 400);
      final changed = base.copyWith(yards: 410);
      expect(changed.yards, 410);
      expect(changed == base, isFalse);
      // An identical-value copy stays equal (value semantics).
      expect(base.copyWith(yards: 400), base);
      expect(base.copyWith(yards: 400).hashCode, base.hashCode);
    });
  });

  group('HoleDraft shots (#22)', () {
    test('initial lays out the tee shot with the yardage, and no club', () {
      final shots = HoleDraft.initial(yards: 420).shots;
      expect(shots, hasLength(1));
      expect(shots.single.lie, 'Tee');
      expect(shots.single.distanceYards, 420);
      expect(shots.single.club, isNull);
    });

    test('a hole with no yardage lays out a tee shot with no distance', () {
      expect(HoleDraft.initial().shots.single.distanceYards, isNull);
    });

    test('shotInputs writes the shots, then a putter row per putt', () {
      final draft = HoleDraft.initial().copyWith(putts: 2, shots: const [
        ShotDraft(club: 'Driver', distanceYards: 268, lie: 'Tee'),
        ShotDraft(club: '7 Iron', distanceYards: 150, lie: 'Fairway'),
      ]);
      final inputs = draft.shotInputs();
      expect(inputs, hasLength(4));
      expect(inputs.first.club, 'Driver');
      expect(inputs.first.distanceYards, 268);
      expect(inputs[1].club, '7 Iron');
      expect(inputs[1].result, isNull);
      expect(inputs[2].club, 'Putter');
      expect(inputs[2].lie, 'Green');
      expect(inputs[2].distanceYards, isNull);
      expect(inputs[2].result, isNull);
      expect(inputs[3].club, 'Putter');
    });

    test('shotInputs holes the last stroke — a putt, or the shot itself', () {
      final putted = HoleDraft.initial().copyWith(putts: 1, shots: const [
        ShotDraft(lie: 'Tee'),
        ShotDraft(lie: 'Fairway'),
      ]);
      expect(putted.shotInputs().last.result, 'Holed');
      expect(putted.shotInputs()[1].result, isNull);

      final chippedIn = putted.copyWith(putts: 0);
      expect(chippedIn.shotInputs(), hasLength(2));
      expect(chippedIn.shotInputs().last.result, 'Holed');
    });

    test('shotInputs keeps a blank row between two entered shots', () {
      // Shot numbers are the hole's chronology: dropping the middle row would
      // renumber the putt to shot 2 and delete a row still being filled in —
      // which is exactly the row a par-3 tee shot that misses the green leaves
      // behind, since nothing says where it finished.
      final draft = HoleDraft.initial(par: 3).copyWith(putts: 1, shots: const [
        ShotDraft(club: '5 Iron', distanceYards: 165, lie: 'Tee'),
        ShotDraft(),
      ]);
      final inputs = draft.shotInputs();
      expect(inputs, hasLength(3));
      expect(inputs[1].club, isNull);
      expect(inputs[1].lie, isNull);
      expect(inputs[2].club, 'Putter');
    });

    test('ShotDraft.isBlank is true only when every field is unset', () {
      expect(const ShotDraft().isBlank, isTrue);
      expect(const ShotDraft(lie: 'Fairway').isBlank, isFalse);
      expect(const ShotDraft(distanceYards: 0).isBlank, isFalse);
    });

    test('equality and hashCode track the shot list deeply', () {
      final a = HoleDraft.initial()
          .copyWith(shots: const [ShotDraft(club: 'Driver')]);
      final b = HoleDraft.initial()
          .copyWith(shots: const [ShotDraft(club: 'Driver')]);
      final c = HoleDraft.initial()
          .copyWith(shots: const [ShotDraft(club: '3 wood')]);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });

    test('countedScore is shots + putts + penalties', () {
      final draft = HoleDraft.initial().copyWith(
        putts: 2,
        penaltyStrokes: 1,
        shots: const [ShotDraft(lie: 'Tee'), ShotDraft(), ShotDraft()],
      );
      expect(draft.countedScore, 6);
      // A list with nothing in it still has a tee shot to count.
      expect(draft.copyWith(shots: const []).countedScore, 4);
    });

    test('ShotDraft.copyWith can clear a field to null', () {
      const s = ShotDraft(club: 'Driver', lie: 'Tee');
      expect(s.copyWith(club: null).club, isNull);
      expect(s.copyWith(club: null).lie, 'Tee');
    });
  });

  group('HoleDraft.fromSaved', () {
    test('a hole saved before shots were counted gets its tee shot', () {
      final draft = HoleDraft.fromSaved(_saved(yards: 410));
      expect(draft.shots, hasLength(1));
      expect(draft.shots.single.lie, 'Tee');
      expect(draft.shots.single.distanceYards, 410);
    });

    test('takes the putt rows off — putts counts them', () {
      final draft = HoleDraft.fromSaved(_saved(putts: 2), const [
        ShotDraft(club: 'Driver', lie: 'Tee'),
        ShotDraft(club: '8 Iron', lie: 'Fairway'),
        ShotDraft(club: 'Putter', lie: 'Green'),
        ShotDraft(club: 'Putter', lie: 'Green', result: 'Holed'),
      ]);
      expect(draft.shots, hasLength(2));
      expect(draft.shots.last.club, '8 Iron');
      expect(draft.putts, 2);
    });

    test('takes a Holed result off — it is re-derived on save', () {
      final draft = HoleDraft.fromSaved(_saved(score: 2, putts: 0), const [
        ShotDraft(club: 'Driver', lie: 'Tee'),
        ShotDraft(club: 'Sand Wedge', lie: 'Fairway', result: 'Holed'),
      ]);
      expect(draft.shots.last.result, isNull);
      expect(draft.shotInputs().last.result, 'Holed');
    });

    test('keeps a penalty result', () {
      final draft = HoleDraft.fromSaved(_saved(), const [
        ShotDraft(club: 'Driver', lie: 'Tee', result: 'Penalty'),
      ]);
      expect(draft.shots.single.result, 'Penalty');
    });

    test('never takes the tee shot for a putt', () {
      final draft = HoleDraft.fromSaved(_saved(), const [
        ShotDraft(club: 'Putter', lie: 'Tee'),
      ]);
      expect(draft.shots, hasLength(1));
      expect(draft.shots.single.club, 'Putter');
    });

    test('marks an unlabelled first shot as played from the tee', () {
      final draft = HoleDraft.fromSaved(_saved(), const [
        ShotDraft(club: 'Driver'),
      ]);
      expect(draft.shots.single.lie, 'Tee');
    });

    test('reading the same saved hole twice gives equal drafts', () {
      // The live draft and the saved snapshot are both built here, so an
      // opened-but-untouched hole must compare equal to read "Saved".
      const shots = [
        ShotDraft(club: 'Driver', lie: 'Tee'),
        ShotDraft(club: 'Putter', lie: 'Green', result: 'Holed'),
      ];
      expect(
        HoleDraft.fromSaved(_saved(), shots),
        HoleDraft.fromSaved(_saved(), shots),
      );
    });
  });
}
