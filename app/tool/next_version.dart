// The I/O half of the release calculator: git, file reads, argument parsing
// and printing. Every actual rule lives in `release_rules.dart`, which imports
// nothing and is unit-tested in `test/tool/release_rules_test.dart`.
//
//   dart run tool/next_version.dart                      # what to cut next
//   dart run tool/next_version.dart --verify-release v0.3.1
//
// See ../../RELEASING.md for the procedure these support.

import 'dart:convert';
import 'dart:io';

import 'release_rules.dart';

const String _usage = '''
next_version.dart — derive Golfy's next release version from what merged.

Usage:
  dart run tool/next_version.dart [--bump <level>] [--json]
  dart run tool/next_version.dart --verify-release <tag> [--json]

Options:
  --bump <major|minor|patch>   Override the computed bump; the computed answer
                               is still reported. This is how the 1.0.0 cut
                               (#79) is declared, since that is a judgement
                               call the rules cannot make.
  --verify-release <tag>       Check a tagged commit for agreement between the
                               tag, app/pubspec.yaml, CHANGELOG.md and the
                               drift schema snapshots. Everything is read from
                               git at that tag, so any historical tag can be
                               checked from any checkout.
  --json                       Machine-readable output.
  -h, --help                   This text.

Exit codes: 0 ok, 1 verification failed, 2 bad input or usage.

The rules are documented in RELEASING.md.''';

void main(List<String> args) {
  try {
    exitCode = _run(args);
  } on _CliException catch (e) {
    stderr.writeln('error: ${e.message}');
    exitCode = e.code;
  } on FormatException catch (e) {
    stderr.writeln('error: ${e.message}');
    exitCode = 2;
  }
}

int _run(List<String> args) {
  String? verifyTag;
  Bump? forcedBump;
  var asJson = false;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    final split = arg.indexOf('=');
    final name = split < 0 ? arg : arg.substring(0, split);
    String value() {
      if (split >= 0) return arg.substring(split + 1);
      if (i + 1 >= args.length) throw _CliException('$name needs a value', 2);
      return args[++i];
    }

    switch (name) {
      case '-h':
      case '--help':
        stdout.writeln(_usage);
        return 0;
      case '--json':
        asJson = true;
      case '--verify-release':
        verifyTag = value();
      case '--bump':
        forcedBump = _parseBump(value());
      default:
        throw _CliException('unknown option "$arg"\n\n$_usage', 2);
    }
  }

  if (verifyTag != null && forcedBump != null) {
    throw _CliException(
        '--bump has no meaning with --verify-release, which checks a tag that '
        'already exists',
        2);
  }

  final repo = _Repo(_gitOutput(['rev-parse', '--show-toplevel']).trim());
  return verifyTag == null
      ? _reportNextVersion(repo, forcedBump: forcedBump, asJson: asJson)
      : _reportVerification(repo, verifyTag, asJson: asJson);
}

Bump _parseBump(String value) => switch (value.toLowerCase()) {
      'major' => Bump.major,
      'minor' => Bump.minor,
      'patch' => Bump.patch,
      _ => throw _CliException(
          '--bump takes major, minor or patch (got "$value")', 2),
    };

// --- the default mode: what to cut next ------------------------------------

int _reportNextVersion(
  _Repo repo, {
  required Bump? forcedBump,
  required bool asJson,
}) {
  final pubspecVersion = parsePubspecVersion(repo.read(_pubspecPath));
  final schemaVersion = parseSchemaVersion(repo.read(_databasePath));
  final snapshots = parseSnapshotVersions(repo.snapshotFileNames());
  final unreleased = parseUnreleasedSections(repo.read(_changelogPath));

  final lastTag = repo.lastReleaseTag();
  final lastVersion = lastTag == null
      ? null
      : parsePubspecVersion(repo.readAtTag(lastTag, _pubspecPath));
  final previousSchema = lastTag == null
      ? null
      : parseSchemaVersion(repo.readAtTag(lastTag, _databasePath));
  final mergedPullRequests =
      lastTag == null ? <int>[] : repo.mergedPullRequestsSince(lastTag);

  final decision = decideBump(ReleaseInputs(
    pubspecVersion: pubspecVersion,
    unreleased: unreleased,
    schemaVersion: schemaVersion,
    lastReleaseVersion: lastVersion,
    previousSchemaVersion: previousSchema,
    forcedBump: forcedBump,
  ));

  if (asJson) {
    stdout.writeln(_json({
      'current': pubspecVersion.toString(),
      'lastReleaseTag': lastTag,
      'lastReleaseVersion': lastVersion?.toString(),
      'schemaVersion': schemaVersion,
      'previousSchemaVersion': previousSchema,
      'snapshotsConsistent':
          snapshots.isContiguous && snapshots.highest == schemaVersion,
      'mergedPullRequests': mergedPullRequests,
      'unreleasedSections': unreleased.sections,
      'hasBreakingEntry': unreleased.hasBreakingEntry,
      'computedBump': decision.computed.name,
      'effectiveBump': decision.effective.name,
      'clamped': decision.clamped,
      'overridden': decision.isOverridden,
      'reasons': [
        for (final reason in decision.reasons)
          {'bump': reason.bump.name, 'detail': reason.detail},
      ],
      'notes': decision.notes,
      'nextBuild': decision.nextBuild,
      'nextVersion': decision.nextVersion?.toString(),
      'cutAnywayVersion': decision.cutAnywayVersion.toString(),
    }));
    return 0;
  }

  stdout.writeln('current        $pubspecVersion              $_pubspecPath');
  stdout.writeln(lastTag == null
      ? 'last release   (none — no v*.*.* tag in this clone)'
      : 'last release   $lastTag  $lastVersion');
  stdout.writeln('schema         $schemaVersion  '
      '${_schemaNote(schemaVersion, previousSchema, lastTag)}   '
      '${_snapshotNote(snapshots, schemaVersion)}');
  if (lastTag != null) {
    stdout.writeln('merged since   $lastTag: ${mergedPullRequests.isEmpty ? '(no merge commits)' : mergedPullRequests.map((n) => '#$n').join(', ')}');
  }
  stdout.writeln('');
  stdout.writeln('[Unreleased]   ${unreleased.isEmpty ? '(empty)' : unreleased.sections.map((s) => '### $s').join(', ')}');
  stdout.writeln('');

  stdout.writeln('bump  ${decision.effective.label}'
      '${decision.isOverridden ? '   (--bump override; the rules computed ${decision.computed.label})' : ''}');
  for (final reason in decision.reasons) {
    stdout.writeln('  - ${reason.bump.name}: ${reason.detail}');
  }
  for (final note in decision.notes) {
    stdout.writeln('  ! $note');
  }
  stdout.writeln('');

  final next = decision.nextVersion;
  if (next == null) {
    stdout.writeln('next  (no release needed)');
    stdout.writeln('      if you cut one anyway it is a PATCH: '
        '${decision.cutAnywayVersion}');
  } else {
    stdout.writeln('next  $next');
  }
  return 0;
}

String _schemaNote(int schema, int? previous, String? lastTag) {
  if (previous == null) return '(no previous release to compare)';
  return previous == schema
      ? '(unchanged since $lastTag)'
      : '(was $previous at $lastTag)';
}

String _snapshotNote(SnapshotSet snapshots, int schemaVersion) {
  if (snapshots.highest != schemaVersion) {
    return 'WARNING: newest snapshot is v${snapshots.highest}, '
        'schemaVersion is $schemaVersion';
  }
  if (!snapshots.isContiguous) {
    return 'WARNING: missing snapshots v${snapshots.missing.join(', v')}';
  }
  return 'snapshots v1..v${snapshots.highest} consistent';
}

// --- the CI mode: is this tag safe to build? -------------------------------

int _reportVerification(_Repo repo, String tag, {required bool asJson}) {
  if (!repo.tagExists(tag)) {
    throw _CliException('no such tag "$tag" in this clone — a shallow '
        'checkout has no tags (CI needs fetch-depth: 0)', 2);
  }
  final previousTag = repo.releaseTagBefore(tag);

  final problems = verifyRelease(VerifyInputs(
    tag: tag,
    changelog: repo.readAtTag(tag, _changelogPath),
    pubspec: repo.readAtTag(tag, _pubspecPath),
    databaseDart: repo.readAtTag(tag, _databasePath),
    snapshotFileNames: repo.snapshotFileNamesAtTag(tag),
    previousTag: previousTag,
    previousPubspec: previousTag == null
        ? null
        : repo.readAtTag(previousTag, _pubspecPath),
    previousDatabaseDart: previousTag == null
        ? null
        : repo.readAtTag(previousTag, _databasePath),
  ));

  if (asJson) {
    stdout.writeln(_json({
      'tag': tag,
      'previousTag': previousTag,
      'ok': problems.isEmpty,
      'problems': problems,
    }));
    return problems.isEmpty ? 0 : 1;
  }

  if (problems.isEmpty) {
    stdout.writeln('$tag is consistent with the repo at that commit'
        '${previousTag == null ? ' (first release)' : ' (previous: $previousTag)'}.');
    return 0;
  }

  stderr.writeln('$tag has ${problems.length} '
      'problem${problems.length == 1 ? '' : 's'}:');
  stderr.writeln('');
  for (final problem in problems) {
    stderr.writeln('  - $problem');
  }
  stderr.writeln('');
  stderr.writeln('See RELEASING.md for the cut procedure.');
  return 1;
}

// --- git ------------------------------------------------------------------

const String _pubspecPath = 'app/pubspec.yaml';
const String _changelogPath = 'CHANGELOG.md';
const String _databasePath = 'app/lib/data/database.dart';
const String _snapshotsPath = 'app/drift_schemas';

class _Repo {
  _Repo(this.root);

  final String root;

  String read(String path) => File('$root/$path').readAsStringSync();

  String readAtTag(String tag, String path) =>
      _gitOutput(['show', '$tag:$path'], root: root);

  bool tagExists(String tag) =>
      _gitOutput(['tag', '--list', tag], root: root).trim().isNotEmpty;

  /// Every `vX.Y.Z` tag, newest first. Release tags are matched by shape, not
  /// by ancestry: v0.3.1 was cut from a feature branch, so
  /// `git describe --abbrev=0` is not reliable here.
  List<String> releaseTags() {
    final pattern = RegExp(r'^v\d+\.\d+\.\d+$');
    return [
      for (final line
          in _gitOutput(['tag', '--list', 'v*', '--sort=-v:refname'], root: root)
              .split('\n'))
        if (pattern.hasMatch(line.trim())) line.trim(),
    ];
  }

  String? lastReleaseTag() {
    final tags = releaseTags();
    return tags.isEmpty ? null : tags.first;
  }

  /// The release tag immediately below [tag] in version order.
  String? releaseTagBefore(String tag) {
    final tags = releaseTags();
    final index = tags.indexOf(tag);
    if (index < 0 || index + 1 >= tags.length) return null;
    return tags[index + 1];
  }

  List<String> snapshotFileNames() => Directory('$root/$_snapshotsPath')
      .listSync()
      .map((entity) => entity.path)
      .toList();

  List<String> snapshotFileNamesAtTag(String tag) => _gitOutput(
        ['ls-tree', '--name-only', tag, '$_snapshotsPath/'],
        root: root,
      ).split('\n').where((line) => line.trim().isNotEmpty).toList();

  /// Pull requests merged since [tag], read from the merge commits' subjects.
  ///
  /// Advisory only — it is printed beside the parsed CHANGELOG so a missing
  /// entry is visible at cut time. A squash merge leaves no merge commit, so
  /// this can undercount; the CHANGELOG, not this list, decides the version.
  List<int> mergedPullRequestsSince(String tag) {
    final pattern = RegExp(r'Merge pull request #(\d+)');
    final numbers = <int>{};
    final log = _gitOutput(
      ['log', '--merges', '--pretty=%s', '$tag..HEAD'],
      root: root,
    );
    for (final match in pattern.allMatches(log)) {
      numbers.add(int.parse(match.group(1)!));
    }
    final sorted = numbers.toList()..sort();
    return sorted;
  }
}

String _gitOutput(List<String> args, {String? root}) {
  final result = Process.runSync(
    'git',
    args,
    workingDirectory: root,
    // The CHANGELOG is full of em dashes; the system encoding would mangle
    // them on Windows.
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  if (result.exitCode != 0) {
    throw _CliException(
        'git ${args.join(' ')} failed: ${(result.stderr as String).trim()}', 2);
  }
  return result.stdout as String;
}

String _json(Map<String, Object?> value) =>
    const JsonEncoder.withIndent('  ').convert(value);

class _CliException implements Exception {
  _CliException(this.message, [this.code = 2]);

  final String message;
  final int code;
}
