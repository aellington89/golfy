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
}
