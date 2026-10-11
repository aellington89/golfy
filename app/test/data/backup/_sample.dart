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
    teeSets: const [
      TeeSet(id: 1, courseId: 1, name: 'Blue tees'),
    ],
    courseYards: const [
      CourseYard(id: 1, teeSetId: 1, holeNumber: 1, yards: 412),
    ],
    pinSets: const [
      PinSet(id: 1, courseId: 1, name: 'Sunday pins'),
    ],
    teeToPinYards: const [
      TeeToPinYard(id: 1, teeSetId: 1, pinSetId: 1, holeNumber: 1, yards: 398),
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
        teeSetId: 1,
        pinSetId: 1,
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

/// [samplePayload] as [preV9SampleTree] reads once upgraded: its one yardage
/// set, "Blue tees - Sunday pins", back to that tee set, pin set and their
/// tee-to-pin yards. Course yards don't come back: v8 never had them.
BackupPayload upgradedV8SamplePayload() =>
    samplePayload().copyWith(courseYards: const []);

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

/// The sample file as Golfy wrote it before schema v9, claiming
/// [schemaVersion]: its one yardage set a `course_sets` row named "Blue tees -
/// Sunday pins" — the tee set and pin set it was — holding their tee-to-pin
/// yards in `course_set_yards`, no course yards (v8 had none), and rounds
/// carrying `course_set_id` and the legacy `tee_set` label. Everything else —
/// `distance_feet` included — is left as today's, for the test to shape
/// further.
Map<String, Object?> preV9SampleTree(int schemaVersion) {
  final tree = sampleTree();
  final manifest = manifestOf(tree);
  manifest['schemaVersion'] = schemaVersion;
  final counts = manifest['rowCounts']! as Map<String, Object?>;
  final data = dataOf(tree);

  final tee = rowOf(tree, 'tee_sets');
  final pin = rowOf(tree, 'pin_sets');
  data['course_sets'] = [
    {
      'id': 1,
      'course_id': tee['course_id'],
      'name': '${tee['name']} - ${pin['name']}',
    },
  ];
  data['course_set_yards'] = [
    for (final row
        in tableOf(tree, 'tee_to_pin_yards').cast<Map<String, Object?>>())
      {
        'id': row['id'],
        'course_set_id': 1,
        'hole_number': row['hole_number'],
        'yards': row['yards'],
      },
  ];
  for (final table in const [
    'tee_sets',
    'course_yards',
    'pin_sets',
    'tee_to_pin_yards',
  ]) {
    data.remove(table);
    counts.remove(table);
  }
  counts['course_sets'] = 1;
  counts['course_set_yards'] = tableOf(tree, 'course_set_yards').length;
  for (final row in tableOf(tree, 'rounds')) {
    final round = row! as Map<String, Object?>;
    round['tee_set'] = null;
    round['course_set_id'] = round['tee_set_id'] == null ? null : 1;
    round.remove('tee_set_id');
    round.remove('pin_set_id');
  }
  return tree;
}

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
