import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/database.dart';
import 'package:golfy_app/data/models/round_with_course.dart';
import 'package:golfy_app/features/events/event_stats.dart';

void main() {
  Event makeEvent(int id, {String name = 'Event', int season = 1}) =>
      Event(id: id, name: name, season: season, tied: false, missedCut: false);

  RoundWithCourse makeRound({
    required int id,
    Event? event,
    String courseName = 'Pebble',
    String date = '2026-05-25',
    int holesEntered = 18,
    int totalScore = 72,
    int totalPar = 72,
  }) {
    return RoundWithCourse(
      round: Round(
        id: id,
        date: date,
        courseId: 1,
        roundNumber: 1,
        eventId: event?.id,
      ),
      courseName: courseName,
      event: event,
      holesEntered: holesEntered,
      totalScore: totalScore,
      totalPar: totalPar,
    );
  }

  group('roundsForEvent', () {
    test('selects only rounds for the given event id, preserving order', () {
      final e1 = makeEvent(1);
      final e2 = makeEvent(2);
      final rounds = [
        makeRound(id: 10, event: e1),
        makeRound(id: 11, event: e2),
        makeRound(id: 12, event: e1),
        makeRound(id: 13), // casual — no event
      ];
      expect(roundsForEvent(rounds, 1).map((r) => r.round.id), [10, 12]);
    });

    test('returns empty when no rounds match', () {
      expect(roundsForEvent([makeRound(id: 1)], 99), isEmpty);
    });
  });

  group('computeEventScoringSummary', () {
    test('no rounds -> no data', () {
      final s = computeEventScoringSummary(const []);
      expect(s.hasData, isFalse);
      expect(s.scoredRounds, 0);
      expect(s.avgScoreVsPar, isNull);
      expect(s.bestRound, isNull);
    });

    test('rounds with no entered holes are excluded', () {
      final s = computeEventScoringSummary([
        makeRound(id: 1, holesEntered: 0, totalScore: 0, totalPar: 0),
      ]);
      expect(s.hasData, isFalse);
      expect(s.scoredRounds, 0);
    });

    test('single scored round: avg equals it and it is the best', () {
      final s = computeEventScoringSummary([
        makeRound(id: 1, totalScore: 75, totalPar: 72), // +3
      ]);
      expect(s.scoredRounds, 1);
      expect(s.avgScoreVsPar, 3.0);
      expect(s.bestRound!.round.id, 1);
    });

    test('multiple rounds: averages vs par and picks the lowest as best', () {
      final s = computeEventScoringSummary([
        makeRound(id: 1, totalScore: 75, totalPar: 72), // +3
        makeRound(id: 2, totalScore: 70, totalPar: 72), // -2
        makeRound(id: 3, totalScore: 74, totalPar: 72), // +2
      ]);
      expect(s.scoredRounds, 3);
      expect(s.avgScoreVsPar, 1.0); // (3 + -2 + 2) / 3
      expect(s.bestRound!.round.id, 2);
    });

    test('partial rounds are scored on their entered holes only', () {
      final s = computeEventScoringSummary([
        makeRound(id: 1, holesEntered: 9, totalScore: 40, totalPar: 36), // +4
      ]);
      expect(s.scoredRounds, 1);
      expect(s.avgScoreVsPar, 4.0);
    });

    test('a tie for best resolves to the first (most recent) round', () {
      final s = computeEventScoringSummary([
        makeRound(id: 1, totalScore: 70, totalPar: 72), // -2 (newest first)
        makeRound(id: 2, totalScore: 70, totalPar: 72), // -2
      ]);
      expect(s.bestRound!.round.id, 1);
    });
  });
}
