// Unit tests for the release-versioning rules (#86).
//
// `tool/release_rules.dart` imports nothing, so every rule is exercised here on
// sample input with no git, no network and no sqlite — which also means this
// file runs on Windows without tripping the locked-sqlite3.dll crash a full
// `flutter test` can hit:
//
//   flutter test test/tool/release_rules_test.dart
//
// The last group is different: it parses the repo's own real CHANGELOG,
// pubspec and schema, so a change to any of those formats fails here rather
// than at the moment a release is cut.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/release_rules.dart';

// U+2192 RIGHTWARDS ARROW, spelled as an escape so the assertions do not
// depend on this file's encoding surviving a round trip.
const String arrow = '→';

void main() {
  group('parsePubspecVersion', () {
    test('reads X.Y.Z+N', () {
      final version = parsePubspecVersion(buildPubspec('0.3.1+35'));
      expect(version.major, 0);
      expect(version.minor, 3);
      expect(version.patch, 1);
      expect(version.build, 35);
      expect(version.toString(), '0.3.1+35');
    });

    test('ignores the "like 1.2.43" in the comment above the real field', () {
      // The real pubspec carries Flutter's explanatory comment block directly
      // above `version:`; an unanchored pattern would match inside it.
      expect(parsePubspecVersion(realPubspecHeader).toString(), '0.3.1+35');
    });

    test('a missing +N build number is an error, not a default', () {
      expect(
        () => parsePubspecVersion(buildPubspec('0.3.1')),
        throwsA(isA<FormatException>().having(
            (e) => e.message, 'message', contains('versionCode'))),
      );
    });

    test('no version: line at all is an error', () {
      expect(
        () => parsePubspecVersion('name: golfy_app\n'),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('no `version:`'))),
      );
    });
  });

  group('parseSchemaVersion', () {
    test('reads the getter out of database.dart', () {
      expect(parseSchemaVersion(buildDatabase(7)), 7);
    });

    test('an absent getter is an error', () {
      expect(() => parseSchemaVersion('class GolfyDatabase {}'),
          throwsA(isA<FormatException>()));
    });
  });

  group('parseSnapshotVersions', () {
    test('v1..v7 is contiguous with highest 7', () {
      final snapshots = parseSnapshotVersions(snapshotNames(7));
      expect(snapshots.highest, 7);
      expect(snapshots.isContiguous, isTrue);
      expect(snapshots.missing, isEmpty);
    });

    test('a gap is reported rather than hidden by the max', () {
      final snapshots = parseSnapshotVersions([
        'drift_schema_v1.json',
        'drift_schema_v2.json',
        'drift_schema_v4.json',
      ]);
      expect(snapshots.highest, 4);
      expect(snapshots.isContiguous, isFalse);
      expect(snapshots.missing, [3]);
    });

    test('unrelated file names are ignored', () {
      final snapshots = parseSnapshotVersions([
        'drift_schema_v1.json',
        'README.md',
        'schema_versions.dart',
        'drift_schema_v2.json.bak',
      ]);
      expect(snapshots.versions, [1]);
    });

    test('an empty directory has highest 0', () {
      expect(parseSnapshotVersions(const []).highest, 0);
    });
  });

  group('parseUnreleasedSections', () {
    test('reads the sections of an entry in canonical order', () {
      final entry = parseUnreleasedSections(buildChangelog(
        version: '0.3.1',
        unreleasedSections: ['Changed', 'Added'],
      ));
      expect(entry.sections, ['Added', 'Changed']);
      expect(entry.hasBreakingEntry, isFalse);
    });

    test('an empty [Unreleased] reads as empty', () {
      // The post-cut shape: the heading stays, immediately followed by the
      // release heading below it.
      final entry = parseUnreleasedSections(buildChangelog(version: '0.3.1'));
      expect(entry.sections, isEmpty);
      expect(entry.isEmpty, isTrue);
    });

    test('### Internal is a section like any other', () {
      final entry = parseUnreleasedSections(buildChangelog(
        version: '0.3.1',
        unreleasedSections: ['Internal'],
      ));
      expect(entry.sections, ['Internal']);
    });

    test('an unrecognised section is an error naming it', () {
      final changelog = buildChangelog(version: '0.3.1')
          .replaceFirst('## [Unreleased]\n', '## [Unreleased]\n\n### Housekeeping\n\n- x.\n');
      expect(
        () => parseUnreleasedSections(changelog),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('Housekeeping'))),
      );
    });

    test('sections of the release below are not counted', () {
      final entry = parseUnreleasedSections(buildChangelog(
        version: '0.3.1',
        sections: ['Fixed'],
      ));
      expect(entry.sections, isEmpty);
    });

    test('a ### inside a fenced code block is not a section', () {
      final changelog = buildChangelog(version: '0.3.1').replaceFirst(
        '## [Unreleased]\n',
        '## [Unreleased]\n\n### Fixed\n\n- Heading example:\n\n  ```markdown\n'
            '  ### Added\n  ```\n',
      );
      expect(parseUnreleasedSections(changelog).sections, ['Fixed']);
    });

    test('a **BREAKING:** bullet is detected wherever it is filed', () {
      final changelog = buildChangelog(version: '0.3.1').replaceFirst(
        '## [Unreleased]\n',
        '## [Unreleased]\n\n### Changed\n\n'
            '- **BREAKING:** the backup format is not readable by 0.3.x.\n',
      );
      final entry = parseUnreleasedSections(changelog);
      expect(entry.sections, ['Changed']);
      expect(entry.hasBreakingEntry, isTrue);
    });

    test('a **BREAKING:** inside a code fence does not count', () {
      final changelog = buildChangelog(version: '0.3.1').replaceFirst(
        '## [Unreleased]\n',
        '## [Unreleased]\n\n### Changed\n\n- Example:\n\n  ```markdown\n'
            '  - **BREAKING:** not a real entry\n  ```\n',
      );
      expect(parseUnreleasedSections(changelog).hasBreakingEntry, isFalse);
    });

    test('a missing [Unreleased] heading is an error', () {
      expect(() => parseUnreleasedSections('# Changelog\n'),
          throwsA(isA<FormatException>()));
    });
  });

  group('parseReleaseHeadings / parseLinkRefs', () {
    test('release headings are read in file order, Unreleased excluded', () {
      final headings = parseReleaseHeadings(
          buildChangelog(version: '0.3.1', previousVersion: '0.3.0'));
      expect(headings.map((h) => h.version.release), ['0.3.1', '0.3.0']);
      expect(headings.first.date, '2026-09-27');
    });

    test('link references are read as label -> url', () {
      final refs = parseLinkRefs(buildChangelog(version: '0.3.1'));
      expect(refs['Unreleased'], endsWith('v0.3.1...HEAD'));
      expect(refs['0.3.1'], endsWith('v0.3.0...v0.3.1'));
    });
  });

  group('decideBump', () {
    test('### Fixed alone is a PATCH, in both eras', () {
      expect(decide(pubspec: '0.3.1+35', sections: ['Fixed']).effective,
          Bump.patch);
      expect(
          decide(
                  pubspec: '1.4.2+80',
                  lastRelease: '1.4.2+79',
                  sections: ['Fixed'])
              .effective,
          Bump.patch);
    });

    test('### Security alone is a PATCH', () {
      expect(decide(pubspec: '0.3.1+35', sections: ['Security']).effective,
          Bump.patch);
    });

    test('### Added is a MINOR', () {
      final decision = decide(pubspec: '0.3.1+35', sections: ['Added']);
      expect(decision.effective, Bump.minor);
      expect(decision.nextVersion.toString(), '0.4.0+36');
    });

    test('### Changed is a MINOR', () {
      expect(decide(pubspec: '0.3.1+35', sections: ['Changed']).effective,
          Bump.minor);
    });

    test('### Internal alone is NONE, with the cut-anyway PATCH offered', () {
      final decision = decide(pubspec: '0.3.1+35', sections: ['Internal']);
      expect(decision.effective, Bump.none);
      expect(decision.nextVersion, isNull);
      expect(decision.cutAnywayVersion.toString(), '0.3.2+36');
      expect(decision.reasons.single.detail, contains('### Internal'));
    });

    test('an empty [Unreleased] is NONE', () {
      final decision = decide(pubspec: '0.3.1+35');
      expect(decision.effective, Bump.none);
      expect(decision.reasons.single.detail, contains('empty'));
    });

    test('### Deferred alone is NONE', () {
      expect(decide(pubspec: '0.3.1+35', sections: ['Deferred']).effective,
          Bump.none);
    });

    test('### Internal does not suppress a real change beside it', () {
      expect(
          decide(pubspec: '0.3.1+35', sections: ['Fixed', 'Internal'])
              .effective,
          Bump.patch);
    });

    test('a schema bump floors an otherwise-PATCH release at MINOR', () {
      final decision = decide(
        pubspec: '0.3.1+35',
        sections: ['Fixed'],
        schema: 8,
      );
      expect(decision.effective, Bump.minor);
      expect(
        decision.reasons.map((r) => r.detail).join('\n'),
        contains('schemaVersion 7 $arrow 8'),
      );
    });

    test('a schema bump alongside ### Added is not double-counted', () {
      final decision =
          decide(pubspec: '0.3.1+35', sections: ['Added'], schema: 8);
      expect(decision.effective, Bump.minor);
      expect(decision.reasons.where((r) => r.detail.contains('schemaVersion')),
          hasLength(1));
    });

    test('an unchanged schema contributes no reason', () {
      final decision = decide(pubspec: '0.3.1+35', sections: ['Fixed']);
      expect(decision.reasons.where((r) => r.detail.contains('schemaVersion')),
          isEmpty);
    });

    test('post-1.0 MINOR moves the minor part', () {
      final decision = decide(
        pubspec: '1.2.3+60',
        lastRelease: '1.2.3+59',
        sections: ['Added'],
      );
      expect(decision.nextVersion.toString(), '1.3.0+61');
    });

    test('the build number is one past the highest of pubspec and tag', () {
      expect(
        decide(pubspec: '0.3.1+35', lastRelease: '0.3.1+34', sections: ['Fixed'])
            .nextBuild,
        36,
      );
      // A botched revert can leave the working tree behind the last release.
      expect(
        decide(pubspec: '0.3.1+34', lastRelease: '0.3.1+35', sections: ['Fixed'])
            .nextBuild,
        36,
      );
    });

    test('a pubspec that drifted from the last release bumps from the tag', () {
      final decision = decide(
        pubspec: '0.4.0+35',
        lastRelease: '0.3.1+34',
        sections: ['Fixed'],
      );
      expect(decision.base.release, '0.3.1');
      expect(decision.nextVersion.toString(), '0.3.2+36');
      expect(decision.notes.join('\n'), contains('last release'));
    });

    test('with no tags at all it bumps from the pubspec', () {
      final decision =
          decide(pubspec: '0.0.1+1', lastRelease: null, sections: ['Added']);
      expect(decision.nextVersion.toString(), '0.1.0+2');
      expect(decision.notes.join('\n'), contains('no v*.*.* tag'));
    });
  });

  group('decideBump — the MAJOR path, both eras side by side', () {
    test('### Removed: clamped to MINOR pre-1.0, MAJOR post-1.0', () {
      final pre = decide(pubspec: '0.3.1+35', sections: ['Removed']);
      expect(pre.effective, Bump.minor);
      expect(pre.clamped, isTrue);
      expect(pre.nextVersion.toString(), '0.4.0+36');
      final reasons = pre.reasons.map((r) => r.detail).join('\n');
      expect(reasons, contains('migration note'));
      expect(reasons, contains('#79'));

      final post = decide(
        pubspec: '1.4.2+80',
        lastRelease: '1.4.2+79',
        sections: ['Removed'],
      );
      expect(post.effective, Bump.major);
      expect(post.clamped, isFalse);
      expect(post.nextVersion.toString(), '2.0.0+81');
    });

    test('a **BREAKING:** entry under ### Changed behaves the same way', () {
      final pre = decide(
        pubspec: '0.3.1+35',
        sections: ['Changed'],
        breaking: true,
      );
      expect(pre.effective, Bump.minor);
      expect(pre.clamped, isTrue);

      final post = decide(
        pubspec: '1.4.2+80',
        lastRelease: '1.4.2+79',
        sections: ['Changed'],
        breaking: true,
      );
      expect(post.effective, Bump.major);
      expect(post.nextVersion.toString(), '2.0.0+81');
    });

    test('the **BREAKING:** marker outranks the section it sits in', () {
      final post = decide(
        pubspec: '1.4.2+80',
        lastRelease: '1.4.2+79',
        sections: ['Fixed'],
        breaking: true,
      );
      expect(post.effective, Bump.major);
    });

    test('### Removed alongside ### Added folds to the same answer', () {
      final post = decide(
        pubspec: '1.4.2+80',
        lastRelease: '1.4.2+79',
        sections: ['Added', 'Removed'],
      );
      expect(post.effective, Bump.major);
      expect(post.nextVersion.toString(), '2.0.0+81');
    });

    test('1.0.0 is post-1.0: the clamp does not fire', () {
      final decision = decide(
        pubspec: '1.0.0+40',
        lastRelease: '1.0.0+39',
        sections: ['Removed'],
      );
      expect(decision.clamped, isFalse);
      expect(decision.nextVersion.toString(), '2.0.0+41');
    });

    test('0.9.9 is still pre-1.0: MAJOR becomes 0.10.0', () {
      final decision = decide(
        pubspec: '0.9.9+50',
        lastRelease: '0.9.9+49',
        sections: ['Removed'],
      );
      expect(decision.clamped, isTrue);
      expect(decision.nextVersion.toString(), '0.10.0+51');
    });

    test('--bump major declares 1.0.0 while still reporting the computed '
        'answer', () {
      final decision = decide(
        pubspec: '0.3.1+35',
        sections: ['Internal'],
        forced: Bump.major,
      );
      expect(decision.computed, Bump.none);
      expect(decision.effective, Bump.major);
      expect(decision.isOverridden, isTrue);
      expect(decision.nextVersion.toString(), '1.0.0+36');
    });

    test('an override below the computed bump is reported as a downgrade', () {
      final decision = decide(
        pubspec: '0.3.1+35',
        sections: ['Added'],
        forced: Bump.patch,
      );
      expect(decision.computed, Bump.minor);
      expect(decision.effective, Bump.patch);
      expect(decision.notes.join('\n'), contains('lower'));
    });
  });

  group('verifyRelease', () {
    test('a consistent tag has no problems', () {
      expect(verify(), isEmpty);
    });

    test('the v0.0.3 anomaly: tag ahead of the pubspec it shipped', () {
      // A real regression in this repo's history — v0.0.3 was tagged on a
      // commit whose pubspec still read 0.0.2+4. This is the check that would
      // have caught it.
      final problems = verify(
        tag: 'v0.0.3',
        version: '0.0.3',
        pubspecVersion: '0.0.2+4',
        previousVersion: '0.0.2',
        previousPubspecVersion: '0.0.2+3',
      );
      expect(problems, hasLength(1));
      expect(problems.single, contains('does not match app/pubspec.yaml'));
    });

    test('a tag that is not vX.Y.Z is rejected outright', () {
      final problems = verify(tag: 'release-0.3.2');
      expect(problems.single, contains('is not vX.Y.Z'));
    });

    test('a missing release heading is caught', () {
      final problems = verify(changelogVersion: '0.3.5');
      expect(problems.join('\n'), contains('no `## [0.3.2]'));
    });

    test('an empty promotion is caught', () {
      final problems = verify(sections: const []);
      expect(problems.join('\n'), contains('no ### sections'));
    });

    test('a missing version link reference is caught', () {
      final problems = verify(includeVersionLinkRef: false);
      expect(problems.join('\n'), contains('[0.3.2]:'));
    });

    test('an [Unreleased] compare link left on the old tag is caught', () {
      final problems = verify(unreleasedCompareTag: 'v0.3.1');
      expect(problems.join('\n'), contains('v0.3.2...HEAD'));
    });

    test('a build number equal to the previous release is caught', () {
      final problems =
          verify(pubspecVersion: '0.3.2+35', previousPubspecVersion: '0.3.1+35');
      expect(problems.join('\n'), contains('not higher'));
    });

    test('a build number lower than the previous release is caught', () {
      final problems =
          verify(pubspecVersion: '0.3.2+34', previousPubspecVersion: '0.3.1+35');
      expect(problems.join('\n'), contains('versionCode'));
    });

    test('a version that goes backwards is caught', () {
      final problems = verify(
        tag: 'v0.3.0',
        version: '0.3.0',
        pubspecVersion: '0.3.0+36',
        previousVersion: '0.3.1',
        previousPubspecVersion: '0.3.1+35',
      );
      expect(problems.join('\n'), contains('is not higher than'));
    });

    test('a schema dumped without a snapshot is caught', () {
      final problems = verify(schema: 8, snapshotCount: 7);
      expect(problems.join('\n'), contains('drift_schema_v7.json'));
    });

    test('a schema with no snapshots at all reads clearly', () {
      final problems = verify(snapshotNamesOverride: const []);
      expect(problems.join('\n'), contains('no snapshots at all'));
    });

    test('a gap in the snapshots is caught', () {
      final problems = verify(snapshotNamesOverride: const [
        'drift_schema_v1.json',
        'drift_schema_v3.json',
        'drift_schema_v7.json',
      ]);
      expect(problems.join('\n'), contains('missing snapshots'));
    });

    test('a schema bump released as a PATCH is caught', () {
      final problems = verify(schema: 8, snapshotCount: 8, previousSchema: 7);
      expect(problems.join('\n'), contains('at least a MINOR'));
    });

    test('a schema bump released as a MINOR is fine', () {
      final problems = verify(
        tag: 'v0.4.0',
        version: '0.4.0',
        pubspecVersion: '0.4.0+36',
        schema: 8,
        snapshotCount: 8,
        previousSchema: 7,
      );
      expect(problems, isEmpty);
    });

    test('the first release has nothing to compare against', () {
      final problems = verify(
        tag: 'v0.0.1',
        version: '0.0.1',
        pubspecVersion: '0.0.1+1',
        previousTag: null,
      );
      expect(problems, isEmpty);
    });
  });

  group('the repo itself', () {
    late String changelog;
    late String pubspec;
    late String databaseDart;
    late List<String> snapshots;

    setUpAll(() {
      final root = findRepoRoot();
      changelog = File('${root.path}/CHANGELOG.md').readAsStringSync();
      pubspec = File('${root.path}/app/pubspec.yaml').readAsStringSync();
      databaseDart =
          File('${root.path}/app/lib/data/database.dart').readAsStringSync();
      snapshots = Directory('${root.path}/app/drift_schemas')
          .listSync()
          .map((e) => e.path)
          .toList();
    });

    test('CHANGELOG.md parses, with well-formed descending headings', () {
      final headings = parseReleaseHeadings(changelog);
      expect(headings, isNotEmpty);
      for (var i = 1; i < headings.length; i++) {
        expect(
          headings[i - 1].version.compareRelease(headings[i].version),
          greaterThan(0),
          reason: 'heading on line ${headings[i].line} is not below the one '
              'above it',
        );
      }
    });

    test('every released version has a link reference', () {
      final refs = parseLinkRefs(changelog);
      for (final heading in parseReleaseHeadings(changelog)) {
        expect(refs, contains(heading.version.release));
      }
    });

    test('[Unreleased] uses only recognised sections', () {
      expect(parseUnreleasedSections(changelog), isNotNull);
    });

    test('pubspec parses and matches the newest CHANGELOG heading', () {
      final version = parsePubspecVersion(pubspec);
      expect(version.release, parseReleaseHeadings(changelog).first.release);
    });

    test('schemaVersion matches the newest drift snapshot', () {
      expect(parseSnapshotVersions(snapshots).highest,
          parseSchemaVersion(databaseDart));
    });
  });
}

// --- helpers ---------------------------------------------------------------

extension on ReleaseHeading {
  String get release => version.release;
}

/// Walks up from the test's working directory (`app/` under `flutter test`)
/// until the repo root — the directory holding CHANGELOG.md — is found.
Directory findRepoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 4; i++) {
    if (File('${dir.path}/CHANGELOG.md').existsSync()) return dir;
    dir = dir.parent;
  }
  throw StateError('could not find the repo root above ${Directory.current}');
}

BumpDecision decide({
  required String pubspec,
  String? lastRelease = '',
  List<String> sections = const [],
  bool breaking = false,
  int schema = 7,
  int? previousSchema = 7,
  Bump? forced,
}) {
  final current = SemverVersion.parse(pubspec);
  // The default stands for "released at the same version, one build back",
  // which is where the repo sits between cuts.
  final last = lastRelease == ''
      ? SemverVersion(current.major, current.minor, current.patch,
          current.build > 0 ? current.build - 1 : 0)
      : (lastRelease == null ? null : SemverVersion.parse(lastRelease));
  return decideBump(ReleaseInputs(
    pubspecVersion: current,
    lastReleaseVersion: last,
    unreleased:
        ChangelogEntry(sections: sections, hasBreakingEntry: breaking),
    schemaVersion: schema,
    previousSchemaVersion: last == null ? null : previousSchema,
    forcedBump: forced,
  ));
}

List<String> verify({
  String tag = 'v0.3.2',
  String version = '0.3.2',
  String? changelogVersion,
  String? pubspecVersion,
  List<String> sections = const ['Fixed'],
  bool includeVersionLinkRef = true,
  String? unreleasedCompareTag,
  String previousVersion = '0.3.1',
  String? previousTag = 'v0.3.1',
  String? previousPubspecVersion = '0.3.1+35',
  int schema = 7,
  int previousSchema = 7,
  int snapshotCount = 7,
  List<String>? snapshotNamesOverride,
}) =>
    verifyRelease(VerifyInputs(
      tag: tag,
      changelog: buildChangelog(
        version: changelogVersion ?? version,
        sections: sections,
        includeVersionLinkRef: includeVersionLinkRef,
        unreleasedCompareTag: unreleasedCompareTag ?? 'v$version',
        previousVersion: previousVersion,
      ),
      pubspec: buildPubspec(pubspecVersion ?? '$version+36'),
      databaseDart: buildDatabase(schema),
      snapshotFileNames: snapshotNamesOverride ?? snapshotNames(snapshotCount),
      previousTag: previousTag,
      previousPubspec: previousTag == null
          ? null
          : buildPubspec(previousPubspecVersion ?? '$previousVersion+35'),
      previousDatabaseDart:
          previousTag == null ? null : buildDatabase(previousSchema),
    ));

/// The real comment block Flutter puts directly above `version:`, verbatim.
/// It mentions `1.2.43` and talks about version numbers at length, so it is
/// the fixture that keeps [parsePubspecVersion]'s pattern anchored.
const String realPubspecHeader = '''
name: golfy_app
publish_to: 'none'

# The following defines the version and build number for your application.
# A version number is three numbers separated by dots, like 1.2.43
# followed by an optional build number separated by a +.
# Both the version and the builder number may be overridden in flutter
# build by specifying --build-name and --build-number, respectively.
# In Android, build-name is used as versionName while build-number used as versionCode.
version: 0.3.1+35

environment:
  sdk: ^3.12.0
''';

String buildPubspec(String version) => '''
name: golfy_app
description: "Golfy — video game golf stats tracker."
# A version number is three numbers separated by dots, like 1.2.43
# followed by an optional build number separated by a +.
version: $version

environment:
  sdk: ^3.12.0
''';

String buildDatabase(int schemaVersion) => '''
class GolfyDatabase extends _\$GolfyDatabase {
  @override
  int get schemaVersion => $schemaVersion;
}
''';

List<String> snapshotNames(int highest) => [
      for (var i = 1; i <= highest; i++) 'drift_schema_v$i.json',
    ];

String buildChangelog({
  required String version,
  String date = '2026-09-27',
  String previousVersion = '0.3.0',
  List<String> sections = const [],
  List<String> unreleasedSections = const [],
  bool includeVersionLinkRef = true,
  String? unreleasedCompareTag,
}) {
  const base = 'https://github.com/aellington89/golfy/compare';
  final buffer = StringBuffer('# Changelog\n\n## [Unreleased]\n');
  for (final section in unreleasedSections) {
    buffer.write('\n### $section\n\n- Something unreleased.\n');
  }
  buffer.write('\n## [$version] - $date\n');
  for (final section in sections) {
    buffer.write('\n### $section\n\n- Something released.\n');
  }
  buffer.write('\n## [$previousVersion] - 2026-09-13\n\n### Added\n\n'
      '- Earlier work.\n\n');
  buffer.write(
      '[Unreleased]: $base/${unreleasedCompareTag ?? 'v$version'}...HEAD\n');
  if (includeVersionLinkRef) {
    buffer.write('[$version]: $base/v$previousVersion...v$version\n');
  }
  buffer.write('[$previousVersion]: $base/v0.2.0...v$previousVersion\n');
  return buffer.toString();
}
