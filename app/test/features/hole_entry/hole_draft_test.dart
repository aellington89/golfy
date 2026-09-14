import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/features/hole_entry/hole_draft.dart';

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

    test('score mirrors par, so the score > putts invariant still holds', () {
      final draft = HoleDraft.initial();
      expect(draft.score, draft.par);
      expect(draft.score, greaterThan(draft.putts));
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
    test('initial has no shots', () {
      expect(HoleDraft.initial().shots, isEmpty);
    });

    test('shotInputs maps shots in order', () {
      final draft = HoleDraft.initial().copyWith(shots: const [
        ShotDraft(club: 'Driver', distanceYards: 268, lie: 'Tee'),
        ShotDraft(club: '7 Iron', distanceYards: 150, result: 'Holed'),
      ]);
      final inputs = draft.shotInputs();
      expect(inputs, hasLength(2));
      expect(inputs.first.club, 'Driver');
      expect(inputs.first.distanceYards, 268);
      expect(inputs[1].club, '7 Iron');
      expect(inputs[1].result, 'Holed');
    });

    test('shotInputs drops blank rows left at the end of the list', () {
      final draft = HoleDraft.initial().copyWith(shots: const [
        ShotDraft(club: 'Driver', distanceYards: 268, lie: 'Tee'),
        ShotDraft(),
        ShotDraft(),
      ]);
      expect(draft.shotInputs(), hasLength(1));
    });

    test('shotInputs keeps a blank row between two entered shots', () {
      // Shot numbers are the hole's chronology: dropping the middle row would
      // renumber the putt to shot 2 and delete a row still being filled in —
      // which is exactly the row a par-3 tee shot that misses the green leaves
      // behind, since no hole-level field says where it finished.
      final draft = HoleDraft.initial(par: 3).copyWith(shots: const [
        ShotDraft(club: '5 Iron', distanceYards: 165, lie: 'Tee'),
        ShotDraft(),
        ShotDraft(club: 'Putter', lie: 'Green', result: 'Holed'),
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

    test('ShotDraft.copyWith can clear a field to null', () {
      const s = ShotDraft(club: 'Driver', lie: 'Tee');
      expect(s.copyWith(club: null).club, isNull);
      expect(s.copyWith(club: null).lie, 'Tee');
    });
  });
}
