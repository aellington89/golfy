// The v8 -> v9 yardage split's rule (schema v9): how a v8 yardage set, named
// "Tee Set - Pin Set" and holding that pair's tee-to-pin yards, becomes a tee
// set, a pin set and their yards. The migration and the backup upgrader both
// apply it, so it is tested once here and the two are tested for applying it.
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/upgrades/split_yardage_sets.dart';

V8YardageSet set(int id, String name, {int course = 1}) =>
    (id: id, courseId: course, name: name);

/// A v8 card: [count] holes of [yards] for [setId], ids from [firstId].
List<V8SetYard> card(int setId, int firstId, int yards, {int count = 2}) => [
      for (var h = 1; h <= count; h++)
        (
          id: firstId + h - 1,
          courseSetId: setId,
          holeNumber: h,
          yards: yards + h,
        ),
    ];

void main() {
  group('splitYardageSetName', () {
    test('splits "Tee Set - Pin Set" at the separator, trimmed', () {
      expect(splitYardageSetName('Blue - Sunday pins'),
          (tee: 'Blue', pin: 'Sunday pins'));
      expect(splitYardageSetName('  Blue   -   Sunday  '),
          (tee: 'Blue', pin: 'Sunday'));
    });

    test('takes an en or em dash for the hyphen', () {
      expect(splitYardageSetName('Blue – Sunday'), (tee: 'Blue', pin: 'Sunday'));
      expect(splitYardageSetName('Blue — Sunday'), (tee: 'Blue', pin: 'Sunday'));
    });

    test('splits at the first separator, so a pin set name can hold one', () {
      expect(splitYardageSetName('Blue - Tournament - Day 1'),
          (tee: 'Blue', pin: 'Tournament - Day 1'));
    });

    test('a bare hyphen is part of a name, not a separator', () {
      expect(splitYardageSetName('Blue-White - Sunday'),
          (tee: 'Blue-White', pin: 'Sunday'));
      expect(splitYardageSetName('Blue-White'), (tee: 'Blue-White', pin: null));
    });

    test('a name with nothing to split is a tee set alone', () {
      expect(splitYardageSetName('Blue tees'), (tee: 'Blue tees', pin: null));
      expect(splitYardageSetName('Blue - '), (tee: 'Blue -', pin: null));
      expect(splitYardageSetName(' - Sunday'), (tee: '- Sunday', pin: null));
    });
  });

  group('splitYardageSets', () {
    test('each set\'s yards become its pair\'s tee-to-pin yards', () {
      final split = splitYardageSets(
        [set(1, 'Blue - Sunday')],
        card(1, 1, 400),
      );

      expect(split.teeSets, [(id: 1, courseId: 1, name: 'Blue')]);
      expect(split.pinSets, [(id: 1, courseId: 1, name: 'Sunday')]);
      expect(split.courseYards, isEmpty);
      expect(split.teeToPinYards, [
        (id: 1, teeSetId: 1, pinSetId: 1, holeNumber: 1, yards: 401),
        (id: 2, teeSetId: 1, pinSetId: 1, holeNumber: 2, yards: 402),
      ]);
      expect(split.bySetId, {1: (courseId: 1, teeSetId: 1, pinSetId: 1)});
    });

    test('sets naming the same tee or pin set share it', () {
      final split = splitYardageSets(
        [
          set(1, 'Blue - Sunday'),
          set(2, 'Blue - Monday'),
          set(3, 'White - Sunday'),
        ],
        [...card(1, 1, 400), ...card(2, 3, 390), ...card(3, 5, 360)],
      );

      expect(split.teeSets.map((t) => t.name), ['Blue', 'White']);
      expect(split.pinSets.map((p) => p.name), ['Sunday', 'Monday']);
      expect(split.bySetId, {
        1: (courseId: 1, teeSetId: 1, pinSetId: 1),
        2: (courseId: 1, teeSetId: 1, pinSetId: 2),
        3: (courseId: 1, teeSetId: 2, pinSetId: 1),
      });
      // The same pins are a different distance from each tee set.
      expect(
        split.teeToPinYards
            .where((y) => y.pinSetId == 1 && y.holeNumber == 1)
            .map((y) => (y.teeSetId, y.yards)),
        [(1, 401), (2, 361)],
      );
    });

    test('names match ignoring case, keeping the first spelling', () {
      final split = splitYardageSets(
        [set(1, 'Blue - Sunday'), set(2, 'blue - SUNDAY pins')],
        const [],
      );

      expect(split.teeSets, [(id: 1, courseId: 1, name: 'Blue')]);
      expect(split.pinSets.map((p) => p.name), ['Sunday', 'SUNDAY pins']);
    });

    test('the same names on two courses are two courses\' sets', () {
      final split = splitYardageSets(
        [set(1, 'Blue - Sunday'), set(2, 'Blue - Sunday', course: 2)],
        const [],
      );

      expect(split.teeSets, [
        (id: 1, courseId: 1, name: 'Blue'),
        (id: 2, courseId: 2, name: 'Blue'),
      ]);
      expect(split.bySetId[2], (courseId: 2, teeSetId: 2, pinSetId: 2));
    });

    test('ids count up in the order the sets were created', () {
      final split = splitYardageSets(
        [set(9, 'White - Monday'), set(4, 'Blue - Sunday')],
        const [],
      );

      expect(split.teeSets.map((t) => (t.id, t.name)),
          [(1, 'Blue'), (2, 'White')]);
      expect(split.pinSets.map((p) => (p.id, p.name)),
          [(1, 'Sunday'), (2, 'Monday')]);
    });

    test('a set with no pin set in its name keeps its yards as course yards',
        () {
      final split = splitYardageSets(
        [set(1, 'Gold'), set(2, 'Gold - Sunday')],
        [...card(1, 1, 450), ...card(2, 3, 440)],
      );

      expect(split.teeSets.single.name, 'Gold');
      expect(split.bySetId[1], (courseId: 1, teeSetId: 1, pinSetId: null));
      expect(split.courseYards, [
        (id: 1, teeSetId: 1, holeNumber: 1, yards: 451),
        (id: 2, teeSetId: 1, holeNumber: 2, yards: 452),
      ]);
      expect(split.teeToPinYards.map((y) => y.id), [3, 4]);
    });

    test('two sets landing on one card keep the earlier set\'s yards', () {
      final split = splitYardageSets(
        [set(2, 'blue - sunday'), set(1, 'Blue - Sunday')],
        [
          // Set 2's rows come first by id, but set 1 was created first.
          ...card(2, 1, 300, count: 3),
          ...card(1, 4, 400),
        ],
      );

      expect(
        split.teeToPinYards.map((y) => (y.holeNumber, y.yards)),
        [(3, 303), (1, 401), (2, 402)],
      );
      expect(split.bySetId[2], split.bySetId[1]);
    });

    test('refuses a yard whose set is not among the sets', () {
      expect(
        () => splitYardageSets([set(1, 'Blue - Sunday')], card(7, 1, 400)),
        throwsArgumentError,
      );
    });
  });
}
