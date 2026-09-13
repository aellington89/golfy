import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/features/hole_entry/hole_draft.dart';
import 'package:golfy_app/features/hole_entry/shot_inference.dart';

void main() {
  // A par 4 with a real yardage, so remaining-distance chaining has something to
  // work with. Tests override only the fields they probe.
  HoleDraft par4({
    int yards = 420,
    int score = 4,
    int putts = 1,
    bool? fairwayHit,
    bool gir = false,
    bool bunkerVisited = false,
    int penaltyStrokes = 0,
    List<ShotDraft> shots = const [],
  }) =>
      HoleDraft.initial(par: 4, yards: yards).copyWith(
        score: score,
        putts: putts,
        fairwayHit: fairwayHit,
        gir: gir,
        bunkerVisited: bunkerVisited,
        penaltyStrokes: penaltyStrokes,
        shots: shots,
      );

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

  group('physicalShots / fullSwingCount', () {
    test('a penalty is not its own row, so it comes off the shot count', () {
      expect(physicalShots(par4(score: 6, penaltyStrokes: 1)), 5);
      expect(physicalShots(par4(score: 4)), 4);
    });

    test('full swings are the physical shots that are not putts', () {
      expect(fullSwingCount(par4(score: 5, putts: 2)), 3);
    });

    test('clamps to one tee shot when the arithmetic goes negative', () {
      // score 4, 2 putts, 3 penalties -> physical 1, raw swings -1.
      final nonsense = par4(score: 4, putts: 2, penaltyStrokes: 3);
      expect(physicalShots(nonsense), 1);
      expect(fullSwingCount(nonsense), 1);
    });
  });

  group('suggestNextShot — the tee shot', () {
    test('is played from the tee, with the hole in front of it', () {
      final shot = suggestNextShot(par4(yards: 420));
      expect(shot.lie, 'Tee');
      expect(shot.distanceYards, 420);
      expect(shot.club, 'Driver');
      expect(shot.result, isNull);
    });

    test('leaves distance and club blank when the hole has no yardage', () {
      final shot = suggestNextShot(par4(yards: 0));
      expect(shot.lie, 'Tee');
      expect(shot.distanceYards, isNull);
      expect(shot.club, isNull);
    });

    test('a hole in one is holed on the tee shot', () {
      final shot = suggestNextShot(par4(score: 1, putts: 0));
      expect(shot.lie, 'Tee');
      expect(shot.result, 'Holed');
    });
  });

  group('suggestNextShot — lie chaining', () {
    ShotDraft second({bool? fairwayHit, int par = 4, bool gir = false}) {
      final draft = HoleDraft.initial(par: par, yards: 420).copyWith(
        score: 4,
        putts: 1,
        fairwayHit: par == 3 ? null : fairwayHit,
        gir: gir,
        shots: const [ShotDraft(club: 'Driver', distanceYards: 420, lie: 'Tee')],
      );
      return suggestNextShot(draft);
    }

    test('a hit fairway puts the next shot on the fairway', () {
      expect(second(fairwayHit: true).lie, 'Fairway');
    });

    test('a missed fairway puts the next shot in the rough', () {
      expect(second(fairwayHit: false).lie, 'Light Rough');
    });

    test('an unrecorded fairway leaves the lie for the user', () {
      expect(second(fairwayHit: null).lie, isNull);
    });

    test('a par 3 chains off GIR instead of the fairway', () {
      expect(second(par: 3, gir: true).lie, 'Green');
      expect(second(par: 3, gir: false).lie, isNull);
    });

    test('bunkerVisited and gir never invent a lie on a par 4', () {
      // The hole knows a bunker was involved, but not on which shot — so the
      // suggestion stays blank and shotWarnings does the reconciling.
      final draft = par4(
        fairwayHit: true,
        bunkerVisited: true,
        gir: true,
        score: 5,
        putts: 1,
        shots: const [
          ShotDraft(club: 'Driver', distanceYards: 420, lie: 'Tee'),
          ShotDraft(club: '5 Iron', distanceYards: 170, lie: 'Fairway'),
        ],
      );
      expect(suggestNextShot(draft).lie, isNull);
    });

    test('does not chain past a penalty', () {
      final draft = par4(
        fairwayHit: true,
        score: 6,
        penaltyStrokes: 1,
        shots: const [
          ShotDraft(club: 'Driver', distanceYards: 420, result: 'Penalty'),
        ],
      );
      final shot = suggestNextShot(draft);
      expect(shot.lie, isNull);
      expect(shot.club, isNull);
      expect(shot.distanceYards, isNull);
    });
  });

  group('suggestNextShot — remaining distance', () {
    test('steps down by the previous club\'s carry', () {
      final draft = par4(
        yards: 420,
        fairwayHit: true,
        shots: const [ShotDraft(club: 'Driver', distanceYards: 420, lie: 'Tee')],
      );
      final shot = suggestNextShot(draft);
      expect(shot.distanceYards, 170); // 420 - 250
      expect(shot.club, '5 Iron'); // carries exactly 170
    });

    test('goes blank rather than negative once the ball is at the pin', () {
      final draft = par4(
        yards: 260,
        score: 5,
        putts: 1,
        fairwayHit: true,
        shots: const [
          ShotDraft(club: 'Driver', distanceYards: 260, lie: 'Tee'),
          ShotDraft(club: 'Driver', distanceYards: 10, lie: 'Fairway'),
        ],
      );
      expect(suggestNextShot(draft).distanceYards, isNull);
    });

    test('goes blank when a previous shot has no club to step down by', () {
      final draft = par4(
        fairwayHit: true,
        shots: const [ShotDraft(lie: 'Tee', distanceYards: 420)],
      );
      expect(suggestNextShot(draft).distanceYards, isNull);
    });
  });

  group('suggestNextShot — putts', () {
    test('switches to the putter once the full swings are used up', () {
      // score 4, 1 putt -> 3 full swings, so shot 4 (index 3) is the putt.
      final draft = par4(
        score: 4,
        putts: 1,
        fairwayHit: true,
        shots: const [
          ShotDraft(club: 'Driver', lie: 'Tee'),
          ShotDraft(club: '5 Iron', lie: 'Fairway'),
          ShotDraft(club: 'Sand Wedge'),
        ],
      );
      final shot = suggestNextShot(draft);
      expect(shot.club, 'Putter');
      expect(shot.lie, 'Green');
      expect(shot.distanceYards, isNull, reason: 'putts are measured in feet');
      expect(shot.result, 'Holed');
    });

    test('holes only the row that completes the score', () {
      // score 4, 2 putts -> 2 full swings; index 2 is the first putt, not last.
      final draft = par4(
        score: 4,
        putts: 2,
        fairwayHit: true,
        shots: const [
          ShotDraft(club: 'Driver', lie: 'Tee'),
          ShotDraft(club: '5 Iron', lie: 'Fairway'),
        ],
      );
      expect(suggestNextShot(draft).result, isNull);
    });
  });

  group('scaffoldShotsFromScore', () {
    test('builds the full swings then the putts, holing the last', () {
      final shots = scaffoldShotsFromScore(
        par4(score: 4, putts: 2, fairwayHit: true),
      );
      expect(shots, hasLength(4));
      expect(shots[0].lie, 'Tee');
      expect(shots[1].lie, 'Fairway');
      expect(shots[2].club, 'Putter');
      expect(shots[3].club, 'Putter');
      expect(shots.last.result, 'Holed');
      expect(
        shots.take(3).every((s) => s.result == null),
        isTrue,
        reason: 'only the final row is holed',
      );
    });

    test('a hole in one is a single holed tee shot', () {
      final shots = scaffoldShotsFromScore(par4(score: 1, putts: 0));
      expect(shots, hasLength(1));
      expect(shots.single.lie, 'Tee');
      expect(shots.single.result, 'Holed');
    });

    test('a putt-less hole is all full swings', () {
      final shots =
          scaffoldShotsFromScore(par4(score: 3, putts: 0, fairwayHit: true));
      expect(shots, hasLength(3));
      expect(shots.every((s) => s.club != 'Putter'), isTrue);
    });

    test('penalties come out of the row count', () {
      final shots = scaffoldShotsFromScore(
        par4(score: 6, putts: 2, penaltyStrokes: 1, fairwayHit: false),
      );
      expect(shots, hasLength(5));
    });

    test('never returns an empty list, even on impossible numbers', () {
      final shots = scaffoldShotsFromScore(
        par4(score: 4, putts: 2, penaltyStrokes: 3),
      );
      expect(shots, hasLength(1));
      expect(shots.single.lie, 'Tee');
    });

    test('a par 3 starts on the tee and putts out', () {
      final shots =
          scaffoldShotsFromScore(par4(score: 3, putts: 2, yards: 165)
              .copyWith(par: 3, gir: true));
      expect(shots, hasLength(3));
      expect(shots[0].lie, 'Tee');
      expect(shots[1].club, 'Putter');
      expect(shots[2].result, 'Holed');
    });
  });

  group('shotWarnings', () {
    test('says nothing when there are no shots', () {
      expect(shotWarnings(par4()), isEmpty);
    });

    test('says nothing about a scaffolded hole — the common case', () {
      final draft = par4(score: 4, putts: 2, fairwayHit: true);
      final built = draft.copyWith(shots: scaffoldShotsFromScore(draft));
      expect(shotWarnings(built), isEmpty);
    });

    test('does not nag about a partially entered list', () {
      // Shots are optional and need not sum to the score, so stopping early is
      // a legitimate way to use the feature.
      final draft = par4(
        score: 5,
        putts: 2,
        fairwayHit: true,
        shots: const [ShotDraft(club: 'Driver', lie: 'Tee')],
      );
      expect(shotWarnings(draft), isEmpty);
    });

    test('flags more shots than the score allows', () {
      final draft = par4(
        score: 3,
        putts: 1,
        shots: const [
          ShotDraft(club: 'Driver', lie: 'Tee'),
          ShotDraft(club: '9 Iron'),
          ShotDraft(club: 'Putter'),
          ShotDraft(club: 'Putter'),
        ],
      );
      expect(shotWarnings(draft), contains(contains('More shots recorded')));
    });

    test('flags a putts count the putter shots disagree with', () {
      final draft = par4(
        score: 4,
        putts: 1,
        fairwayHit: true,
        shots: const [
          ShotDraft(club: 'Driver', lie: 'Tee'),
          ShotDraft(club: '5 Iron', lie: 'Fairway'),
          ShotDraft(club: 'Putter', lie: 'Green'),
          ShotDraft(club: 'Putter', lie: 'Green', result: 'Holed'),
        ],
      );
      expect(shotWarnings(draft), contains(contains('Putts is 1')));
    });

    test('flags a bunker lie when the hole says no bunker', () {
      final draft = par4(
        shots: const [
          ShotDraft(club: 'Driver', lie: 'Tee'),
          ShotDraft(club: 'Sand Wedge', lie: 'Bunker'),
        ],
      );
      expect(shotWarnings(draft), contains(contains('bunker')));
    });

    test('stays quiet when the bunker is declared', () {
      final draft = par4(
        bunkerVisited: true,
        shots: const [
          ShotDraft(club: 'Driver', lie: 'Tee'),
          ShotDraft(club: 'Sand Wedge', lie: 'Bunker'),
        ],
      );
      expect(shotWarnings(draft), isEmpty);
    });

    test('flags fairwayHit disagreeing with shot 2, in both directions', () {
      final claimedHit = par4(
        fairwayHit: true,
        shots: const [
          ShotDraft(club: 'Driver', lie: 'Tee'),
          ShotDraft(club: '5 Iron', lie: 'Deep Rough'),
        ],
      );
      expect(shotWarnings(claimedHit),
          contains(contains('"Fairway hit" is on')));

      final claimedMiss = par4(
        fairwayHit: false,
        shots: const [
          ShotDraft(club: 'Driver', lie: 'Tee'),
          ShotDraft(club: '5 Iron', lie: 'Fairway'),
        ],
      );
      expect(shotWarnings(claimedMiss),
          contains(contains('"Fairway hit" is off')));
    });

    test('ignores the fairway rule when shot 2 has no lie yet', () {
      final draft = par4(
        fairwayHit: true,
        shots: const [
          ShotDraft(club: 'Driver', lie: 'Tee'),
          ShotDraft(club: '5 Iron'),
        ],
      );
      expect(shotWarnings(draft), isEmpty);
    });

    test('flags a holed shot that is not the last', () {
      final draft = par4(
        shots: const [
          ShotDraft(club: 'Driver', lie: 'Tee', result: 'Holed'),
          ShotDraft(club: '5 Iron'),
        ],
      );
      expect(shotWarnings(draft), contains(contains('marked holed')));
    });

    test('flags GIR that the shot count contradicts', () {
      // A par 4 GIR means on the green in 2; this took 3 before putting.
      final draft = par4(
        score: 5,
        putts: 2,
        gir: true,
        fairwayHit: true,
        shots: const [
          ShotDraft(club: 'Driver', lie: 'Tee'),
          ShotDraft(club: '5 Iron', lie: 'Fairway'),
          ShotDraft(club: 'Sand Wedge', lie: 'Light Rough'),
          ShotDraft(club: 'Putter', lie: 'Green'),
          ShotDraft(club: 'Putter', lie: 'Green', result: 'Holed'),
        ],
      );
      expect(shotWarnings(draft), contains(contains('GIR is on')));
    });
  });
}
