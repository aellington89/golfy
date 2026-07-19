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
}
