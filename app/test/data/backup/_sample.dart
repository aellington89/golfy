import 'dart:convert';

import 'package:golfy_app/data/backup/backup_codec.dart';
import 'package:golfy_app/data/backup/backup_manifest.dart';
import 'package:golfy_app/data/backup/backup_payload.dart';
import 'package:golfy_app/data/database.dart';

/// A tiny hand-built payload: one row per table, parent ids lined up, with
/// both a set and an unset value for several nullable columns.
///
/// Hand-built rather than exported from a database so the codec suites are
/// pure — they test the format, not drift.
BackupPayload samplePayload() {
  return BackupPayload(
    courses: const [
      Course(id: 1, name: 'Pebble Beach', gameTitle: 'PGA Tour 2K25'),
    ],
    courseHoles: const [
      CourseHole(id: 1, courseId: 1, holeNumber: 1, par: 4, strokeIndex: 7),
      // strokeIndex left null.
      CourseHole(id: 2, courseId: 1, holeNumber: 2, par: 3),
    ],
    courseSets: const [
      CourseSet(id: 1, courseId: 1, name: 'Blue tees'),
    ],
    courseSetYards: const [
      CourseSetYard(id: 1, courseSetId: 1, holeNumber: 1, yards: 412),
    ],
    events: const [
      Event(
        id: 1,
        name: 'Club Championship',
        season: 1,
        finishPosition: 3,
        tied: true,
        missedCut: false,
      ),
    ],
    rounds: const [
      Round(
        id: 1,
        date: '2026-05-19',
        courseId: 1,
        roundNumber: 1,
        courseSetId: 1,
        eventId: 1,
        notes: 'Said "nice shot" — then this:\nthree-putt. ⛳',
      ),
    ],
    holeResults: const [
      HoleResult(
        id: 1,
        roundId: 1,
        holeNumber: 1,
        par: 4,
        score: 5,
        yards: 412,
        fairwayHit: false,
        gir: false,
        putts: 2,
        upDownAttempt: true,
        upDownSuccess: false,
        penaltyStrokes: 0,
        bunkerVisited: true,
        sandSave: false,
      ),
    ],
    holeShots: const [
      HoleShot(
        id: 1,
        holeResultId: 1,
        shotNumber: 1,
        club: 'Driver',
        distanceYards: 412,
        lie: 'Tee',
      ),
    ],
  );
}

/// A manifest whose counts match [payload], fixed in time so encodings are
/// reproducible.
BackupManifest sampleManifest(BackupPayload payload) {
  return BackupManifest(
    formatVersion: BackupManifest.currentFormatVersion,
    schemaVersion: BackupCodec.supportedSchemaVersion,
    appVersion: '0.4.0+38',
    exportedAt: DateTime.utc(2026, 10, 3, 14, 32, 7),
    platform: 'android',
    rowCounts: payload.rowCounts,
  );
}

String encodeSample([BackupPayload? payload]) {
  final data = payload ?? samplePayload();
  return BackupCodec.encode(sampleManifest(data), data);
}

/// The sample file as a mutable JSON tree, for tests that damage one thing and
/// assert on the complaint.
Map<String, Object?> sampleTree() =>
    jsonDecode(encodeSample()) as Map<String, Object?>;

String reencode(Map<String, Object?> tree) => jsonEncode(tree);

Map<String, Object?> manifestOf(Map<String, Object?> tree) =>
    tree[BackupManifest.jsonKey]! as Map<String, Object?>;

Map<String, Object?> dataOf(Map<String, Object?> tree) =>
    tree['data']! as Map<String, Object?>;

List<Object?> tableOf(Map<String, Object?> tree, String table) =>
    dataOf(tree)[table]! as List<Object?>;

Map<String, Object?> rowOf(
  Map<String, Object?> tree,
  String table, [
  int index = 0,
]) =>
    tableOf(tree, table)[index]! as Map<String, Object?>;
