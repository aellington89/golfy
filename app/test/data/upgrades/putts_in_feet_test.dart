// The v7 -> v8 putt conversion's rule (schema v8): which saved shots are putts
// recorded in yards. The migration and the backup upgrader both apply it, so
// it is tested once here and the two are tested for applying it.
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/upgrades/putts_in_feet.dart';

V7Shot shot(
  int id, {
  int hole = 1,
  int? number,
  String? club,
  String? lie,
  int? yards,
}) =>
    (
      id: id,
      holeResultId: hole,
      shotNumber: number ?? id,
      club: club,
      lie: lie,
      distanceYards: yards,
    );

V7Shot putt(int id, {int hole = 1, int? number, int? yards}) =>
    shot(id, hole: hole, number: number, club: 'Putter', lie: 'Green',
        yards: yards);

void main() {
  test('a yard is three feet', () {
    expect(feetPerYard, 3);
  });

  test('picks out the putts a hole ends on that have a distance', () {
    final ids = puttsSavedInYards([
      shot(1, club: 'Driver', lie: 'Tee', yards: 412),
      shot(2, club: '8 Iron', lie: 'Fairway', yards: 150),
      putt(3, yards: 4),
      putt(4, yards: 1),
    ], {1: 2});

    expect(ids, {3, 4});
  });

  test('leaves a putt with no distance alone', () {
    final ids = puttsSavedInYards([
      shot(1, lie: 'Tee', yards: 412),
      putt(2, yards: 6),
      putt(3),
    ], {1: 2});

    expect(ids, {2});
  });

  test('takes no more putts than the hole counted', () {
    // An older form could save more putter rows than putts; the count is what
    // the form goes by, and the earlier rows stay shots, in yards.
    final ids = puttsSavedInYards([
      shot(1, lie: 'Tee', yards: 412),
      putt(2, yards: 9),
      putt(3, yards: 2),
    ], {1: 1});

    expect(ids, {3});
  });

  test('takes nothing from a hole finished off the green', () {
    final ids = puttsSavedInYards([
      shot(1, lie: 'Tee', yards: 380),
      shot(2, club: 'Lob Wedge', lie: 'Green', yards: 3),
    ], {1: 0});

    expect(ids, isEmpty);
  });

  test('never takes the tee shot, whatever it holds', () {
    expect(puttsSavedInYards([putt(1, yards: 120)], {1: 1}), isEmpty);
  });

  test('stops at the first shot back that is not a putt', () {
    final ids = puttsSavedInYards([
      shot(1, lie: 'Tee', yards: 412),
      putt(2, yards: 10),
      shot(3, club: 'Sand Wedge', lie: 'Bunker', yards: 5),
      putt(4, yards: 2),
    ], {1: 3});

    expect(ids, {4});
  });

  test('a shot from the green is a putt, and so is a putter off it', () {
    final ids = puttsSavedInYards([
      shot(1, lie: 'Tee', yards: 412),
      shot(2, club: 'Putter', lie: 'Light Rough', yards: 12),
      shot(3, club: 'Lob Wedge', lie: 'Green', yards: 2),
    ], {1: 2});

    expect(ids, {2, 3});
  });

  test('goes by shot number, not the order the rows arrive in', () {
    final ids = puttsSavedInYards([
      putt(7, number: 3, yards: 1),
      shot(5, number: 1, lie: 'Tee', yards: 400),
      shot(6, number: 2, lie: 'Fairway', yards: 140),
    ], {1: 1});

    expect(ids, {7});
  });

  test('reads each hole by its own putts count', () {
    final ids = puttsSavedInYards([
      shot(1, hole: 1, number: 1, lie: 'Tee', yards: 400),
      putt(2, hole: 1, number: 2, yards: 3),
      shot(3, hole: 2, number: 1, lie: 'Tee', yards: 380),
      putt(4, hole: 2, number: 2, yards: 5),
      shot(5, hole: 3, number: 1, lie: 'Tee', yards: 360),
      putt(6, hole: 3, number: 2, yards: 7),
    ], {1: 1, 2: 0});

    // Hole 3 has no hole_results row to say how many putts it took.
    expect(ids, {2});
  });
}
