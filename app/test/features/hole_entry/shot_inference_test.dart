import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/features/hole_entry/hole_draft.dart';
import 'package:golfy_app/features/hole_entry/shot_inference.dart';

void main() {
  group('suggestClub', () {
    test('picks the club whose carry matches the distance exactly', () {
      expect(suggestClub(250), 'Driver');
      expect(suggestClub(150), '7 Iron');
      expect(suggestClub(65), 'Lob Wedge');
    });

    test('picks the nearest club when nothing matches exactly', () {
      expect(suggestClub(148), '7 Iron'); // 150 is 2 away, 140 is 8
      expect(suggestClub(122), 'Pitching Wedge'); // 115 vs 130
    });

    test('resolves ties to the earlier (longer) club in the bag', () {
      // 3 Hybrid and 2 Iron both carry 200; 3 Hybrid comes first in shotClubs.
      expect(suggestClub(200), '3 Hybrid');
      // 4 Hybrid / 3 Iron at 190, 5 Hybrid / 4 Iron at 180.
      expect(suggestClub(190), '4 Hybrid');
      expect(suggestClub(180), '5 Hybrid');
    });

    test('clamps beyond either end of the bag', () {
      expect(suggestClub(600), 'Driver');
      expect(suggestClub(1), 'Lob Wedge');
    });

    test('returns null for an unknown distance', () {
      expect(suggestClub(0), isNull);
      expect(suggestClub(-40), isNull);
    });

    test('never suggests the putter', () {
      for (var d = 1; d <= 600; d++) {
        expect(suggestClub(d), isNot('Putter'));
      }
    });

    test('honours a caller-supplied bag', () {
      const shortBag = {'Driver': 180, '9 Iron': 90};
      expect(suggestClub(175, bag: shortBag), 'Driver');
      expect(suggestClub(95, bag: shortBag), '9 Iron');
    });
  });

  group('suggestNextShot', () {
    ShotDraft second({bool? fairwayHit, int par = 4, bool teePenalty = false}) {
      final draft = HoleDraft.initial(par: par, yards: 420).copyWith(
        fairwayHit: par == 3 ? null : fairwayHit,
        shots: [
          ShotDraft(
            lie: 'Tee',
            distanceYards: 420,
            result: teePenalty ? 'Penalty' : null,
          ),
        ],
      );
      return suggestNextShot(draft);
    }

    test('a hit fairway puts shot 2 on the fairway', () {
      expect(second(fairwayHit: true).lie, 'Fairway');
    });

    test('a missed fairway puts shot 2 in the rough', () {
      expect(second(fairwayHit: false).lie, 'Light Rough');
    });

    test('an unanswered fairway leaves the lie for the player', () {
      expect(second(fairwayHit: null).lie, isNull);
    });

    test('a par 3 that needs a shot 2 missed the green — somewhere', () {
      expect(second(par: 3).isBlank, isTrue);
    });

    test('does not chain past a penalty off the tee', () {
      expect(second(fairwayHit: false, teePenalty: true).isBlank, isTrue);
    });

    test('never suggests a club or a distance', () {
      for (final hit in [true, false, null]) {
        final shot = second(fairwayHit: hit);
        expect(shot.club, isNull);
        expect(shot.distanceYards, isNull);
      }
    });

    test('shots after shot 2 start blank', () {
      final draft = HoleDraft.initial(par: 5, yards: 540).copyWith(
        fairwayHit: true,
        shots: const [
          ShotDraft(lie: 'Tee', distanceYards: 540),
          ShotDraft(lie: 'Fairway'),
        ],
      );
      expect(suggestNextShot(draft).isBlank, isTrue);
    });

    test('lays out the tee shot, with the yardage, when there is none', () {
      final draft = HoleDraft.initial(yards: 410).copyWith(shots: const []);
      final shot = suggestNextShot(draft);
      expect(shot.lie, 'Tee');
      expect(shot.distanceYards, 410);
      expect(shot.club, isNull);
    });
  });
}
