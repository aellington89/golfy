import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/features/hole_entry/hole_draft.dart';
import 'package:golfy_app/features/hole_entry/hole_rules.dart';

void main() {
  // A fresh par 4 at 420 yards — the tee shot laid out, one putt, unanswered.
  HoleDraft par4() => HoleDraft.initial(par: 4, yards: 420);
  HoleDraft par3() => HoleDraft.initial(par: 3, yards: 165);
  HoleDraft par5() => HoleDraft.initial(par: 5, yards: 540);

  List<HoleIssueKind> kinds(HoleDraft d) =>
      [for (final i in holeIssues(d)) i.kind];

  HoleIssue issue(HoleDraft d, HoleIssueKind kind) =>
      holeIssues(d).firstWhere((i) => i.kind == kind);

  group('the tee shot result', () {
    test('a fresh hole cannot be saved until it is answered', () {
      final d = par4();
      expect(teeShotAnswered(d), isFalse);
      expect(canSave(d), isFalse);
      expect(kinds(d), [HoleIssueKind.teeShotResult]);
      expect(issue(d, HoleIssueKind.teeShotResult).blocking, isTrue);
    });

    test('answering it is all a regulation hole needs', () {
      final d = answerTeeShot(par4(), true);
      expect(teeShotAnswered(d), isTrue);
      expect(canSave(d), isTrue);
    });

    test('a par 3 asks about the green, and the answer is GIR', () {
      expect(issue(par3(), HoleIssueKind.teeShotResult).message,
          contains('green'));
      expect(issue(par4(), HoleIssueKind.teeShotResult).message,
          contains('fairway'));

      expect(answerTeeShot(par3(), true).gir, isTrue);
      expect(answerTeeShot(par3(), false).gir, isFalse);
      expect(answerTeeShot(par3(), true).fairwayHit, isNull);
    });
  });

  group('Fairway hit? lays out shot 2', () {
    test('Yes plays shot 2 from the fairway', () {
      final d = answerTeeShot(par4(), true);
      expect(d.fairwayHit, isTrue);
      expect(d.shots, hasLength(2));
      expect(d.shots[1].lie, 'Fairway');
    });

    test('No plays shot 2 from the rough', () {
      final d = answerTeeShot(par4(), false);
      expect(d.shots[1].lie, 'Light Rough');
    });

    test('shot 2 arrives with no club and no distance', () {
      final shot = answerTeeShot(par4(), true).shots[1];
      expect(shot.club, isNull);
      expect(shot.distanceYards, isNull);
    });

    test('changing the answer moves shot 2 with it, not a second row', () {
      final hit = answerTeeShot(par4(), true);
      final missed = answerTeeShot(hit, false);
      expect(missed.shots, hasLength(2));
      expect(missed.shots[1].lie, 'Light Rough');
      expect(answerTeeShot(missed, true).shots[1].lie, 'Fairway');
    });

    test('a miss keeps a lie the player chose for shot 2', () {
      var d = answerTeeShot(par4(), true);
      d = updateShot(d, 1, d.shots[1].copyWith(lie: 'Bunker'));
      expect(answerTeeShot(d, false).shots[1].lie, 'Bunker');
    });

    test('a shot 2 the player deleted is not put back by a re-answer', () {
      // Driving the green on a short par 4: the next stroke is a putt.
      var d = answerTeeShot(par4(), false);
      d = removeShot(d, 1);
      expect(answerTeeShot(d, true).shots, hasLength(1));
    });

    test('picking shot 2 lie answers the question the other way round', () {
      var d = addShot(par4());
      expect(d.fairwayHit, isNull);
      d = updateShot(d, 1, d.shots[1].copyWith(lie: 'Fairway'));
      expect(d.fairwayHit, isTrue);
      d = updateShot(d, 1, d.shots[1].copyWith(lie: 'Deep Rough'));
      expect(d.fairwayHit, isFalse);
    });

    test('a par 3 miss lays out shot 2 blank — nothing says where it went',
        () {
      final d = answerTeeShot(par3(), false);
      expect(d.shots, hasLength(2));
      expect(d.shots[1].isBlank, isTrue);
    });

    test('a par 3 green hit clears a blank shot 2 but keeps a filled one', () {
      final missed = answerTeeShot(par3(), false);
      expect(answerTeeShot(missed, true).shots, hasLength(1));

      final chipped = updateShot(
          missed, 1, missed.shots[1].copyWith(lie: 'Light Rough'));
      expect(answerTeeShot(chipped, true).shots, hasLength(2));
    });
  });

  group('the score counts itself', () {
    test('a fresh hole scores its tee shot and putt', () {
      final d = par4();
      expect(d.countedScore, 2);
      expect(d.score, 2);
    });

    test('follows every stroke added or taken away', () {
      var d = answerTeeShot(par4(), true); // tee, fairway, 1 putt
      expect(d.score, 3);
      d = applyEdit(d, d.copyWith(putts: 2));
      expect(d.score, 4);
      d = addShot(d);
      expect(d.score, 5);
      d = applyEdit(d, d.copyWith(penaltyStrokes: 1));
      expect(d.score, 6);
      d = removeShot(d, 2);
      expect(d.score, 5);
    });

    test('a score set by hand stays put, and the gap blocks the save', () {
      var d = answerTeeShot(par4(), true);
      d = applyEdit(d, d.copyWith(score: 5));
      expect(d.score, 5);
      expect(kinds(d), [HoleIssueKind.scoreMismatch]);
      expect(canSave(d), isFalse);

      // Recording the missing strokes closes the gap without moving the score.
      d = addShot(d);
      expect(d.score, 5);
      d = applyEdit(d, d.copyWith(putts: 2));
      expect(d.score, 5);
      expect(canSave(d), isTrue);
    });

    test('names the gap and offers both ways to close it', () {
      final d = applyEdit(
        answerTeeShot(par4(), true),
        answerTeeShot(par4(), true).copyWith(score: 5),
      );
      final mismatch = issue(d, HoleIssueKind.scoreMismatch);
      expect(mismatch.message, contains('Score is 5'));
      expect(mismatch.message, contains('add up to 3'));
      expect(mismatch.message, contains('2 shots + 1 putt'));
      expect([for (final f in mismatch.fixes) f.id], ['add_shots', 'match_score']);

      final filled = mismatch.fixes.first.apply(d);
      expect(filled.shots, hasLength(4));
      expect(filled.score, 5);
      expect(canSave(filled), isTrue);

      final matched = mismatch.fixes.last.apply(d);
      expect(matched.score, 3);
      expect(canSave(matched), isTrue);
    });

    test('a score below the strokes can only be matched, not filled', () {
      var d = answerTeeShot(par4(), true);
      d = applyEdit(d, d.copyWith(putts: 2));
      d = applyEdit(d, d.copyWith(score: 3));
      final fixes = issue(d, HoleIssueKind.scoreMismatch).fixes;
      expect([for (final f in fixes) f.id], ['match_score']);
    });
  });

  group('GIR follows the strokes to the green', () {
    test('stays unset until the tee shot is answered', () {
      expect(par4().gir, isNull);
    });

    test('fairway then one approach is on in regulation on a par 4', () {
      expect(answerTeeShot(par4(), true).gir, isTrue);
    });

    test('a third shot before putting takes it away, removing it gives it back',
        () {
      var d = addShot(answerTeeShot(par4(), true));
      expect(d.gir, isFalse);
      d = removeShot(d, 2);
      expect(d.gir, isTrue);
    });

    test('counts penalty strokes towards the green', () {
      final d = answerTeeShot(par4(), true);
      expect(applyEdit(d, d.copyWith(penaltyStrokes: 1)).gir, isFalse);
    });

    test('a par 5 allows three', () {
      var d = answerTeeShot(par5(), true);
      d = addShot(d);
      expect(d.gir, isTrue);
      d = addShot(d);
      expect(d.gir, isFalse);
    });

    test('can be turned off by hand, but not on when it is impossible', () {
      var d = answerTeeShot(par4(), true);
      d = applyEdit(d, d.copyWith(gir: false));
      expect(d.gir, isFalse, reason: 'a fringe putt the player counted');

      d = addShot(d);
      d = applyEdit(d, d.copyWith(gir: true));
      expect(d.gir, isFalse, reason: 'three strokes to reach a par-4 green');
    });

    test('on a par 3 a shot after a green hit flips it to a miss', () {
      var d = answerTeeShot(par3(), true);
      d = addShot(d);
      expect(d.gir, isFalse);
    });

    test('a par 3 green hit with filled shots after it blocks the save', () {
      var d = answerTeeShot(par3(), false);
      d = updateShot(d, 1, d.shots[1].copyWith(lie: 'Light Rough'));
      d = answerTeeShot(d, true);
      expect(d.gir, isTrue, reason: 'the answer is the player\'s word');
      expect(kinds(d), contains(HoleIssueKind.greenHitWithShots));
      expect(canSave(d), isFalse);
    });
  });

  group('up & down success follows the putts', () {
    HoleDraft attempted({int putts = 1}) {
      final d = answerTeeShot(par4(), false);
      final withPutts = applyEdit(d, d.copyWith(putts: putts));
      return applyEdit(withPutts, withPutts.copyWith(upDownAttempt: true));
    }

    test('an attempt with one putt is a success', () {
      expect(attempted(putts: 1).upDownSuccess, isTrue);
    });

    test('a chip-in is a success', () {
      expect(attempted(putts: 0).upDownSuccess, isTrue);
    });

    test('an attempt with two putts is not', () {
      expect(attempted(putts: 2).upDownSuccess, isFalse);
    });

    test('dropping to one putt after the attempt selects it', () {
      var d = attempted(putts: 2);
      d = applyEdit(d, d.copyWith(putts: 1));
      expect(d.upDownSuccess, isTrue);
    });

    test('a second putt clears it', () {
      var d = attempted(putts: 1);
      d = applyEdit(d, d.copyWith(putts: 2));
      expect(d.upDownSuccess, isFalse);
    });

    test('turning the attempt off clears it', () {
      var d = attempted();
      d = applyEdit(d, d.copyWith(upDownAttempt: false));
      expect(d.upDownSuccess, isFalse);
    });

    test('a success with no attempt is impossible', () {
      final d = answerTeeShot(par4(), true);
      expect(applyEdit(d, d.copyWith(upDownSuccess: true)).upDownSuccess,
          isFalse);
    });

    test('an override sticks until the putts or the attempt change', () {
      // Two chips and a putt: an attempt, one putt, and no up & down.
      var d = attempted(putts: 1);
      d = applyEdit(d, d.copyWith(upDownSuccess: false));
      d = addShot(d);
      expect(d.upDownSuccess, isFalse);
    });

    test('warns when GIR says the green was already reached', () {
      var d = answerTeeShot(par4(), true);
      d = applyEdit(d, d.copyWith(upDownAttempt: true));
      final warning = issue(d, HoleIssueKind.upDownWithGir);
      expect(warning.blocking, isFalse);
      expect(canSave(d), isTrue);
    });
  });

  group('bunkers', () {
    HoleDraft inBunker({int putts = 1}) {
      var d = answerTeeShot(par4(), false);
      d = updateShot(d, 1, d.shots[1].copyWith(lie: 'Bunker'));
      return applyEdit(d, d.copyWith(putts: putts));
    }

    test('a bunker lie turns bunker visited on, and removing it turns it off',
        () {
      var d = inBunker();
      expect(d.bunkerVisited, isTrue);
      d = updateShot(d, 1, d.shots[1].copyWith(lie: 'Light Rough'));
      expect(d.bunkerVisited, isFalse);
    });

    test('bunker visited cannot be turned off while a bunker lie remains', () {
      final d = inBunker();
      expect(applyEdit(d, d.copyWith(bunkerVisited: false)).bunkerVisited,
          isTrue);
    });

    test('getting up and down from the bunker is a sand save', () {
      expect(inBunker(putts: 1).sandSave, isTrue);
      expect(inBunker(putts: 2).sandSave, isFalse);
    });

    test('a fairway bunker followed by another shot is not', () {
      final d = addShot(inBunker());
      final chipped = updateShot(d, 2, d.shots[2].copyWith(lie: 'Fairway'));
      expect(chipped.bunkerVisited, isTrue);
      expect(chipped.sandSave, isFalse);
    });

    test('with no lies to go on, sand save is the player\'s call', () {
      var d = answerTeeShot(par4(), true);
      d = updateShot(d, 1, d.shots[1].copyWith(lie: null));
      d = applyEdit(d, d.copyWith(bunkerVisited: true));
      d = applyEdit(d, d.copyWith(sandSave: true));
      expect(d.sandSave, isTrue);
      d = applyEdit(d, d.copyWith(putts: 2));
      expect(d.sandSave, isFalse, reason: 'two putts is never a save');
    });
  });

  group('penalties', () {
    test('marking a shot as a penalty counts the stroke, unmarking uncounts',
        () {
      var d = answerTeeShot(par4(), false);
      d = updateShot(d, 1, d.shots[1].copyWith(result: penaltyResult));
      expect(d.penaltyStrokes, 1);
      expect(d.score, d.countedScore);
      d = updateShot(d, 1, d.shots[1].copyWith(result: null));
      expect(d.penaltyStrokes, 0);
    });

    test('removing a penalty shot takes its stroke with it', () {
      var d = addShot(answerTeeShot(par4(), false));
      d = updateShot(d, 2, d.shots[2].copyWith(result: penaltyResult));
      d = removeShot(d, 2);
      expect(d.penaltyStrokes, 0);
    });

    test('a penalty off the tee answers the tee shot as a miss', () {
      var d = par4();
      d = updateShot(d, 0, d.shots[0].copyWith(result: penaltyResult));
      expect(d.fairwayHit, isFalse);
      expect(d.penaltyStrokes, 1);
      // Shot 2 is played from a drop the answer doesn't describe.
      expect(d.shots, hasLength(2));
      expect(d.shots[1].lie, isNull);
      expect(canSave(d), isTrue);
    });

    test('flags fewer penalty strokes than penalty shots, with a fix', () {
      var d = answerTeeShot(par4(), false);
      d = updateShot(d, 1, d.shots[1].copyWith(result: penaltyResult));
      d = applyEdit(d, d.copyWith(penaltyStrokes: 0));
      final under = issue(d, HoleIssueKind.penaltyShots);
      expect(under.blocking, isTrue);
      expect(canSave(under.fixes.single.apply(d)), isTrue);
    });

    test('with no putts the last shot cannot be a penalty', () {
      var d = answerTeeShot(par4(), false);
      d = applyEdit(d, d.copyWith(putts: 0));
      d = updateShot(d, 1, d.shots[1].copyWith(result: penaltyResult));
      expect(kinds(d), contains(HoleIssueKind.unholedFinish));
    });
  });

  group('a shot from the green is a putt', () {
    test('warns, and the fix moves it to putts without moving the score', () {
      var d = addShot(answerTeeShot(par4(), true));
      d = updateShot(d, 2, d.shots[2].copyWith(lie: 'Green'));
      final warning = issue(d, HoleIssueKind.shotFromGreen);
      expect(warning.blocking, isFalse);

      final fixed = warning.fixes.single.apply(d);
      expect(fixed.shots, hasLength(2));
      expect(fixed.putts, 2);
      expect(fixed.score, d.score);
      expect(kinds(fixed), isEmpty);
    });
  });

  group('par and yards', () {
    test('switching to or from a par 3 asks for the tee result again', () {
      final answered = answerTeeShot(par4(), true);
      final toThree = changePar(answered, 3);
      expect(toThree.fairwayHit, isNull);
      expect(toThree.gir, isNull);
      expect(teeShotAnswered(toThree), isFalse);

      final backToFour = changePar(answerTeeShot(toThree, true), 4);
      expect(teeShotAnswered(backToFour), isFalse);
    });

    test('par 4 to 5 keeps the answer and re-derives GIR', () {
      final d = addShot(answerTeeShot(par4(), true));
      expect(d.gir, isFalse);
      final five = changePar(d, 5);
      expect(five.fairwayHit, isTrue);
      expect(five.gir, isTrue);
    });

    test('the tee shot distance follows the yardage until it is typed over',
        () {
      var d = changeYards(par4(), 431);
      expect(d.shots.first.distanceYards, 431);

      d = updateShot(d, 0, d.shots.first.copyWith(distanceYards: 400));
      d = changeYards(d, 445);
      expect(d.shots.first.distanceYards, 400);
    });
  });

  group('strokeTally', () {
    test('lists shots, putts and any penalties', () {
      var d = answerTeeShot(par4(), true);
      expect(strokeTally(d), '2 shots + 1 putt');
      d = applyEdit(d, d.copyWith(putts: 2, penaltyStrokes: 1));
      expect(strokeTally(d), '2 shots + 2 putts + 1 penalty');
    });
  });
}
