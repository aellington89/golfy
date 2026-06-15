import 'package:golfy_import_tool/converter.dart';
import 'package:test/test.dart';

/// Column order matching the real "Per Hole Tracker" sheet.
const _header = <Object?>[
  'Date',
  'Course',
  'Round',
  'Hole',
  'Par',
  'Score',
  'Fairway Hit?',
  'GIR?',
  'Putts',
  'Up & Down Attempt?',
  'Up & Down Success?',
  'Penalty Stroke?',
  'Notes',
];

/// Builds one data row in header order; defaults form a valid par-4.
List<Object?> row({
  Object? date,
  String course = 'Greenmont Country Club',
  Object round = 1,
  Object hole = 1,
  Object par = 4,
  Object score = 4,
  Object? fairway = 'Yes',
  Object? gir = 'Yes',
  Object putts = 2,
  Object? udAttempt = 'No',
  Object? udSuccess = 'N/A',
  Object penalty = 0,
  Object? notes,
}) {
  return [
    date ?? DateTime(2026, 5, 6),
    course,
    round,
    hole,
    par,
    score,
    fairway,
    gir,
    putts,
    udAttempt,
    udSuccess,
    penalty,
    notes,
  ];
}

Map<String, Object?> build(List<List<Object?>> data, {String title = 'PGA 2K25'}) {
  return buildImport(
    [_header, ...data],
    gameTitle: title,
    generatedAt: DateTime.utc(2026, 6, 15, 12),
  );
}

Map<String, Object?> firstHole(Map<String, Object?> out) {
  final rounds = out['rounds'] as List;
  final holes = (rounds.first as Map)['holes'] as List;
  return (holes.first as Map).cast<String, Object?>();
}

void main() {
  group('buildImport — structure & mapping', () {
    test('maps a single hole into the JSON contract', () {
      final out = build([
        row(notes: 'good drive'),
      ]);

      expect(out['gameTitle'], 'PGA 2K25');
      expect(out['generatedAt'], '2026-06-15T12:00:00.000Z');
      final rounds = out['rounds'] as List;
      expect(rounds, hasLength(1));
      final round = rounds.first as Map;
      expect(round['date'], '2026-05-06');
      expect(round['course'], 'Greenmont Country Club');
      expect(round['roundNumber'], 1);

      expect(firstHole(out), {
        'holeNumber': 1,
        'par': 4,
        'score': 4,
        'fairwayHit': true,
        'gir': true,
        'putts': 2,
        'upDownAttempt': false,
        'upDownSuccess': false,
        'penaltyStrokes': 0,
        'notes': 'good drive',
      });
    });

    test('Yes/No/N/A map to true/false/null for fairway', () {
      expect(firstHole(build([row(fairway: 'Yes')]))['fairwayHit'], true);
      expect(firstHole(build([row(fairway: 'No')]))['fairwayHit'], false);
      expect(firstHole(build([row(fairway: 'N/A')]))['fairwayHit'], isNull);
    });

    test('par 3 forces fairwayHit null even when the cell says Yes', () {
      final out = build([row(par: 3, score: 3, fairway: 'Yes')]);
      expect(firstHole(out)['fairwayHit'], isNull);
    });

    test('up & down success N/A maps to false; Yes (with attempt) to true', () {
      expect(
        firstHole(build([row(udAttempt: 'No', udSuccess: 'N/A')]))[
            'upDownSuccess'],
        false,
      );
      expect(
        firstHole(build([row(udAttempt: 'Yes', udSuccess: 'Yes')]))[
            'upDownSuccess'],
        true,
      );
    });

    test('blank notes become null', () {
      expect(firstHole(build([row(notes: '   ')]))['notes'], isNull);
      expect(firstHole(build([row(notes: null)]))['notes'], isNull);
    });

    test('dates are emitted zero-padded ISO yyyy-MM-dd', () {
      final out = build([row(date: DateTime(2026, 1, 2))]);
      expect((out['rounds'] as List).first, containsPair('date', '2026-01-02'));
    });

    test('numeric cells may arrive as doubles', () {
      final out = build([row(par: 4.0, score: 5.0, putts: 2.0, penalty: 1.0)]);
      final h = firstHole(out);
      expect(h['par'], 4);
      expect(h['score'], 5);
      expect(h['penaltyStrokes'], 1);
    });
  });

  group('buildImport — grouping', () {
    test('groups by (date, course, round); two rounds same day/course', () {
      final out = build([
        row(round: 1, hole: 1),
        row(round: 1, hole: 2),
        row(round: 2, hole: 1),
      ]);
      final rounds = out['rounds'] as List;
      expect(rounds, hasLength(2));
      expect((rounds[0] as Map)['roundNumber'], 1);
      expect(((rounds[0] as Map)['holes'] as List), hasLength(2));
      expect((rounds[1] as Map)['roundNumber'], 2);
      expect(((rounds[1] as Map)['holes'] as List), hasLength(1));
    });

    test('same date, different courses stay separate', () {
      final out = build([
        row(course: 'Greenmont Country Club', hole: 1),
        row(course: 'TPC Boston', hole: 1),
      ]);
      expect((out['rounds'] as List), hasLength(2));
    });

    test('holes within a round are sorted by hole number', () {
      final out = build([
        row(hole: 3),
        row(hole: 1),
        row(hole: 2),
      ]);
      final holes = ((out['rounds'] as List).first as Map)['holes'] as List;
      expect(holes.map((h) => (h as Map)['holeNumber']), [1, 2, 3]);
    });
  });

  group('buildImport — strict validation', () {
    test('unrecognized Yes/No/N/A token throws with row context', () {
      expect(
        () => build([row(udSuccess: 'Yues', udAttempt: 'Yes')]),
        throwsA(isA<ImportException>().having(
            (e) => e.message, 'message', contains('Yues'))),
      );
    });

    test('non-integer score throws', () {
      expect(() => build([row(score: 'four')]),
          throwsA(isA<ImportException>()));
    });

    test('up & down success without an attempt throws', () {
      expect(
        () => build([row(udAttempt: 'No', udSuccess: 'Yes')]),
        throwsA(isA<ImportException>().having((e) => e.message, 'message',
            contains('without an attempt'))),
      );
    });

    test('duplicate hole within a round throws', () {
      expect(
        () => build([row(hole: 5), row(hole: 5)]),
        throwsA(isA<ImportException>().having(
            (e) => e.message, 'message', contains('duplicate hole 5'))),
      );
    });

    test('hole / par out of range throw', () {
      expect(() => build([row(hole: 19)]), throwsA(isA<ImportException>()));
      expect(() => build([row(par: 6, score: 6)]),
          throwsA(isA<ImportException>()));
    });

    test('missing required column throws', () {
      const badHeader = <Object?>['Date', 'Course', 'Par', 'Score'];
      expect(
        () => buildImport([
          badHeader,
          [DateTime(2026, 5, 6), 'X', 4, 4],
        ], gameTitle: 'PGA 2K25'),
        throwsA(isA<ImportException>().having(
            (e) => e.message, 'message', contains('missing required column'))),
      );
    });

    test('empty gameTitle throws', () {
      expect(() => build([row()], title: '  '),
          throwsA(isA<ImportException>()));
    });

    test('no data rows beneath the header throws', () {
      expect(() => build([]), throwsA(isA<ImportException>()));
    });
  });
}
