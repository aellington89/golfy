import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/database.dart';
import 'package:golfy_app/features/events/event_result_format.dart';

Event _event({
  int season = 1,
  int? finishPosition,
  bool tied = false,
  bool missedCut = false,
}) {
  return Event(
    id: 1,
    name: 'Test Event',
    season: season,
    finishPosition: finishPosition,
    tied: tied,
    missedCut: missedCut,
  );
}

void main() {
  group('formatEventTitle', () {
    test('appends the season, always (even Season 1) (#47)', () {
      expect(formatEventTitle(_event()), 'Test Event (Season 1)');
    });

    test('reflects the occurrence number for later seasons', () {
      expect(formatEventTitle(_event(season: 2)), 'Test Event (Season 2)');
      expect(formatEventTitle(_event(season: 10)), 'Test Event (Season 10)');
    });
  });

  group('ordinal', () {
    test('basic 1-4 suffixes', () {
      expect(ordinal(1), '1st');
      expect(ordinal(2), '2nd');
      expect(ordinal(3), '3rd');
      expect(ordinal(4), '4th');
    });

    test('the 11/12/13 exceptions', () {
      expect(ordinal(11), '11th');
      expect(ordinal(12), '12th');
      expect(ordinal(13), '13th');
    });

    test('21/22/23 take st/nd/rd again', () {
      expect(ordinal(21), '21st');
      expect(ordinal(22), '22nd');
      expect(ordinal(23), '23rd');
    });

    test('the hundreds keep the teens exception', () {
      expect(ordinal(101), '101st');
      expect(ordinal(111), '111th');
      expect(ordinal(112), '112th');
      expect(ordinal(113), '113th');
    });
  });

  group('formatEventResult', () {
    test('not recorded -> em dash', () {
      expect(formatEventResult(_event()), '—');
    });

    test('a win renders as 1st', () {
      expect(formatEventResult(_event(finishPosition: 1)), '1st');
    });

    test('a plain position renders with its ordinal', () {
      expect(formatEventResult(_event(finishPosition: 2)), '2nd');
    });

    test('a tied position renders as T-n', () {
      expect(formatEventResult(_event(finishPosition: 3, tied: true)), 'T-3');
    });

    test('a missed cut renders as Cut', () {
      expect(formatEventResult(_event(missedCut: true)), 'Cut');
    });
  });

  group('hasRecordedResult', () {
    test('false when nothing is recorded', () {
      expect(hasRecordedResult(_event()), isFalse);
    });

    test('true for a position', () {
      expect(hasRecordedResult(_event(finishPosition: 5)), isTrue);
    });

    test('true for a missed cut', () {
      expect(hasRecordedResult(_event(missedCut: true)), isTrue);
    });
  });
}
