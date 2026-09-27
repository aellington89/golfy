// The release-versioning rules, as pure functions from text to values. There
// are deliberately no imports at all — no `dart:io`, no packages — so every
// rule can be exercised offline from `test/tool/release_rules_test.dart` on
// sample CHANGELOG / pubspec / schema input. The I/O half (git, file reads,
// argument parsing, printing) lives next door in `next_version.dart`.
//
// The rules themselves, and the reasoning behind them, are documented in
// ../../RELEASING.md — keep the two in step.

/// How much of the version a release moves, ordered so `Bump.values.indexOf`
/// gives the precedence used to fold several reasons into one answer.
enum Bump {
  none,
  patch,
  minor,
  major;

  /// `MAJOR` / `MINOR` / `PATCH` / `NONE`, as printed.
  String get label => name.toUpperCase();

  /// The greater of two bumps — the fold used across all the reasons found.
  static Bump max(Bump a, Bump b) => a.index >= b.index ? a : b;
}

/// A `X.Y.Z+N` version: the three semver parts plus Flutter's build number,
/// which becomes Android's `versionCode` and must never decrease.
class SemverVersion implements Comparable<SemverVersion> {
  const SemverVersion(this.major, this.minor, this.patch, [this.build = 0]);

  final int major;
  final int minor;
  final int patch;
  final int build;

  static final RegExp _pattern =
      RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?$');

  /// Parses `X.Y.Z` or `X.Y.Z+N`. A missing `+N` becomes build 0; callers that
  /// require one (the pubspec) use [parsePubspecVersion] instead.
  static SemverVersion parse(String text) {
    final match = _pattern.firstMatch(text.trim());
    if (match == null) {
      throw FormatException('not an X.Y.Z(+N) version: "$text"');
    }
    return SemverVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4) ?? '0'),
    );
  }

  /// Just the semver triple, without the build number: `0.3.1`.
  String get release => '$major.$minor.$patch';

  /// The `v`-prefixed git tag this version would be released under.
  String get tag => 'v$release';

  /// True while the project is still pre-1.0, where the MAJOR rule is clamped.
  bool get isPreOneZero => major == 0;

  /// Applies [bump] to the triple and pins the build number to [build].
  SemverVersion applyBump(Bump bump, {required int build}) => switch (bump) {
        Bump.major => SemverVersion(major + 1, 0, 0, build),
        Bump.minor => SemverVersion(major, minor + 1, 0, build),
        Bump.patch => SemverVersion(major, minor, patch + 1, build),
        Bump.none => SemverVersion(major, minor, patch, build),
      };

  /// Compares the semver triple only, ignoring the build number.
  int compareRelease(SemverVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  @override
  int compareTo(SemverVersion other) {
    final byRelease = compareRelease(other);
    return byRelease != 0 ? byRelease : build.compareTo(other.build);
  }

  @override
  bool operator ==(Object other) =>
      other is SemverVersion &&
      other.major == major &&
      other.minor == minor &&
      other.patch == patch &&
      other.build == build;

  @override
  int get hashCode => Object.hash(major, minor, patch, build);

  @override
  String toString() => '$release+$build';
}

/// Which part of the version separates two releases — used to check that a
/// schema bump actually arrived as at least a MINOR.
Bump bumpBetween(SemverVersion from, SemverVersion to) {
  if (from.major != to.major) return Bump.major;
  if (from.minor != to.minor) return Bump.minor;
  if (from.patch != to.patch) return Bump.patch;
  return Bump.none;
}

/// The `###` sections a CHANGELOG entry may use, and what each one implies.
///
/// `Added` / `Changed` / `Deprecated` / `Removed` / `Fixed` / `Security` are
/// Keep a Changelog's own vocabulary. `Internal` and `Deferred` are local
/// extensions: `Internal` covers work no app user can see (CI, tooling, tests,
/// docs, behaviour-neutral refactors) and so implies no bump at all, and
/// `Deferred` predates this file (CHANGELOG.md, under 0.0.2).
const Map<String, Bump> changelogSectionBumps = {
  'Added': Bump.minor,
  'Changed': Bump.minor,
  'Deprecated': Bump.minor,
  'Removed': Bump.major,
  'Fixed': Bump.patch,
  'Security': Bump.patch,
  'Internal': Bump.none,
  'Deferred': Bump.none,
};

/// The order sections are written in, and the order reasons are reported in.
const List<String> changelogSectionOrder = [
  'Added',
  'Changed',
  'Deprecated',
  'Removed',
  'Fixed',
  'Security',
  'Internal',
  'Deferred',
];

/// What one `##` entry of the CHANGELOG contains, as far as the rules care.
class ChangelogEntry {
  const ChangelogEntry({
    required this.sections,
    required this.hasBreakingEntry,
  });

  /// The `###` section names present, in canonical order.
  final List<String> sections;

  /// Whether any bullet opens with `**BREAKING:**`. This is the escape hatch
  /// for a change that is breaking without being a removal — typically a data
  /// format that cannot be upgraded in place, which naturally files under
  /// `### Changed`. It is the one place the rules look inside a bullet, and
  /// only at a fixed marker at the very start of it.
  final bool hasBreakingEntry;

  bool get isEmpty => sections.isEmpty;
}

/// Reads the `version:` line out of a `pubspec.yaml`.
///
/// The `+N` build number is required: it is Android's `versionCode`, and a
/// pubspec without one would silently reset it. The pattern is anchored to the
/// start of a line so it cannot match the `like 1.2.43` in the explanatory
/// comment block that sits directly above the real field.
SemverVersion parsePubspecVersion(String pubspec) {
  final match = RegExp(r'^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$',
          multiLine: true)
      .firstMatch(pubspec);
  if (match == null) {
    final loose =
        RegExp(r'^version:\s*(\S+)\s*$', multiLine: true).firstMatch(pubspec);
    throw FormatException(loose == null
        ? 'pubspec.yaml has no `version:` line'
        : 'pubspec.yaml version "${loose.group(1)}" is not X.Y.Z+N '
            '(the +N build number is required — it is Android versionCode)');
  }
  return SemverVersion(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
    int.parse(match.group(4)!),
  );
}

/// Reads `int get schemaVersion => N;` out of `lib/data/database.dart`.
int parseSchemaVersion(String databaseDart) {
  final match = RegExp(r'int\s+get\s+schemaVersion\s*=>\s*(\d+)\s*;')
      .firstMatch(databaseDart);
  if (match == null) {
    throw const FormatException(
        'database.dart has no `int get schemaVersion => N;`');
  }
  return int.parse(match.group(1)!);
}

/// The drift schema snapshots found in `drift_schemas/`.
class SnapshotSet {
  SnapshotSet(Iterable<int> versions)
      : versions = versions.toSet().toList()..sort();

  final List<int> versions;

  /// The newest snapshot on disk, or 0 when there are none.
  int get highest => versions.isEmpty ? 0 : versions.last;

  /// Every version from 1 to [highest] that has no snapshot file.
  List<int> get missing => [
        for (var v = 1; v <= highest; v++)
          if (!versions.contains(v)) v,
      ];

  /// True when the snapshots run 1..[highest] with no gaps.
  bool get isContiguous => missing.isEmpty;
}

/// Parses snapshot versions out of `drift_schema_vN.json` file names.
///
/// The number comes from the **file name**, never the JSON: the `_meta.version`
/// inside each snapshot is drift's own serialization-format version, not the
/// app's schema version. Names that do not match are ignored, so passing a
/// whole directory listing is fine.
SnapshotSet parseSnapshotVersions(Iterable<String> fileNames) {
  final pattern = RegExp(r'(?:^|[/\\])drift_schema_v(\d+)\.json$');
  return SnapshotSet([
    for (final name in fileNames)
      if (pattern.firstMatch(name.trim()) case final m?) int.parse(m.group(1)!),
  ]);
}

/// A `## [X.Y.Z] - YYYY-MM-DD` heading, as found in the file.
class ReleaseHeading {
  const ReleaseHeading(this.version, this.date, this.line);

  final SemverVersion version;
  final String date;

  /// 1-based line number, for error messages.
  final int line;
}

/// Every released `## [X.Y.Z] - YYYY-MM-DD` heading, in file order.
///
/// `## [Unreleased]` is deliberately not included — it has no date and is not a
/// release.
List<ReleaseHeading> parseReleaseHeadings(String changelog) {
  final pattern =
      RegExp(r'^##\s+\[(\d+\.\d+\.\d+)\]\s+-\s+(\d{4}-\d{2}-\d{2})\s*$');
  final headings = <ReleaseHeading>[];
  final lines = changelog.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final match = pattern.firstMatch(lines[i].trimRight());
    if (match != null) {
      headings.add(ReleaseHeading(
        SemverVersion.parse(match.group(1)!),
        match.group(2)!,
        i + 1,
      ));
    }
  }
  return headings;
}

/// The `[label]: url` link-reference block at the foot of the CHANGELOG.
Map<String, String> parseLinkRefs(String changelog) {
  final pattern = RegExp(r'^\[([^\]]+)\]:\s*(\S+)\s*$', multiLine: true);
  return {
    for (final match in pattern.allMatches(changelog))
      match.group(1)!: match.group(2)!,
  };
}

/// Reads the `###` sections under one `## [label]` entry of the CHANGELOG.
///
/// Scans from the `## [label]` heading to the next `##` heading (or the end of
/// the file), skipping fenced code blocks so a `###` inside an example is not
/// mistaken for a section. An unrecognised section name is a [FormatException]
/// rather than something to ignore: quietly skipping one is exactly how a tool
/// like this under-bumps a release.
ChangelogEntry parseChangelogEntry(String changelog, String label) {
  final lines = changelog.split('\n');
  final headingPattern = RegExp('^##\\s+\\[${RegExp.escape(label)}\\]');
  var start = -1;
  for (var i = 0; i < lines.length; i++) {
    if (headingPattern.hasMatch(lines[i].trimRight())) {
      start = i + 1;
      break;
    }
  }
  if (start < 0) {
    throw FormatException('CHANGELOG.md has no `## [$label]` heading');
  }

  final sectionPattern = RegExp(r'^###\s+(.+?)\s*$');
  final breakingPattern = RegExp(r'^\s*[-*]\s+\*\*BREAKING:\*\*');
  final fencePattern = RegExp(r'^\s*(?:```|~~~)');

  final found = <String>{};
  var hasBreaking = false;
  var inFence = false;

  for (var i = start; i < lines.length; i++) {
    final line = lines[i];
    if (fencePattern.hasMatch(line)) {
      inFence = !inFence;
      continue;
    }
    if (inFence) continue;
    if (line.trimRight().startsWith('## ')) break;

    final section = sectionPattern.firstMatch(line.trimRight());
    if (section != null) {
      final name = section.group(1)!;
      if (!changelogSectionBumps.containsKey(name)) {
        throw FormatException(
            'CHANGELOG.md [$label] has an unrecognised section "### $name" — '
            'expected one of ${changelogSectionOrder.join(', ')}');
      }
      found.add(name);
      continue;
    }
    if (breakingPattern.hasMatch(line)) hasBreaking = true;
  }

  return ChangelogEntry(
    sections: [
      for (final name in changelogSectionOrder)
        if (found.contains(name)) name,
    ],
    hasBreakingEntry: hasBreaking,
  );
}

/// Convenience wrapper for the `## [Unreleased]` entry, the input the next
/// version is derived from.
ChangelogEntry parseUnreleasedSections(String changelog) =>
    parseChangelogEntry(changelog, 'Unreleased');

/// One thing that pushed the bump up, and by how much.
class BumpReason {
  const BumpReason(this.bump, this.detail);

  final Bump bump;
  final String detail;

  @override
  String toString() => '${bump.name}: $detail';
}

/// Everything the rules need. All of it is already-parsed values, so
/// [decideBump] touches no files.
class ReleaseInputs {
  const ReleaseInputs({
    required this.pubspecVersion,
    required this.unreleased,
    required this.schemaVersion,
    this.lastReleaseVersion,
    this.previousSchemaVersion,
    this.forcedBump,
  });

  /// The `version:` currently in `app/pubspec.yaml`.
  final SemverVersion pubspecVersion;

  /// The `## [Unreleased]` entry the bump is derived from.
  final ChangelogEntry unreleased;

  /// `schemaVersion` on HEAD.
  final int schemaVersion;

  /// The version at the most recent `v*.*.*` tag, or null before the first
  /// release.
  final SemverVersion? lastReleaseVersion;

  /// `schemaVersion` at that tag, or null before the first release.
  final int? previousSchemaVersion;

  /// An explicit `--bump` override. The computed answer is still reported.
  final Bump? forcedBump;
}

/// The computed bump, why, and what to cut.
class BumpDecision {
  const BumpDecision({
    required this.computed,
    required this.effective,
    required this.reasons,
    required this.notes,
    required this.clamped,
    required this.base,
    required this.nextBuild,
  });

  /// What the rules folded to, after the pre-1.0 clamp.
  final Bump computed;

  /// What to actually apply — [computed], unless `--bump` overrode it.
  final Bump effective;

  final List<BumpReason> reasons;

  /// Advisory lines that are not bump reasons (version drift, and so on).
  final List<String> notes;

  /// True when a MAJOR was folded but suppressed because the project is
  /// pre-1.0. The suppressed reason is still listed in [reasons].
  final bool clamped;

  /// The version the bump is applied to: the last release, or the pubspec
  /// version before the first release.
  final SemverVersion base;

  final int nextBuild;

  bool get isOverridden => effective != computed;

  /// The version to cut, or null when nothing warrants a release.
  SemverVersion? get nextVersion => effective == Bump.none
      ? null
      : base.applyBump(effective, build: nextBuild);

  /// What a release would be if cut anyway despite [Bump.none] — sometimes you
  /// just want a build out.
  SemverVersion get cutAnywayVersion =>
      base.applyBump(Bump.patch, build: nextBuild);
}

/// Derives the next version from what merged: the `## [Unreleased]` sections
/// plus the drift schema version.
///
/// Every reason — including MAJOR ones — is folded with [Bump.max]
/// unconditionally. The pre-1.0 rule is then applied as a single clamp *after*
/// the fold: `0.y.z` never auto-produces a MAJOR, because `0.y.z -> 1.0.0` is a
/// deliberate call (#79), so the answer drops to MINOR while the suppressed
/// MAJOR reason stays visible in [BumpDecision.reasons]. The day the project
/// reaches 1.0.0 the clamp simply stops firing.
BumpDecision decideBump(ReleaseInputs inputs) {
  final reasons = <BumpReason>[];
  final notes = <String>[];

  final base = inputs.lastReleaseVersion ?? inputs.pubspecVersion;
  if (inputs.lastReleaseVersion == null) {
    notes.add('no v*.*.* tag found — bumping from the pubspec version');
  } else if (inputs.lastReleaseVersion!.release !=
      inputs.pubspecVersion.release) {
    notes.add('pubspec is ${inputs.pubspecVersion.release} but the last '
        'release was ${inputs.lastReleaseVersion!.release} — bumping from the '
        'released version');
  }

  for (final section in inputs.unreleased.sections) {
    final bump = changelogSectionBumps[section]!;
    if (bump == Bump.none) continue;
    reasons.add(BumpReason(
      bump,
      section == 'Removed'
          ? '[Unreleased] has ### Removed — a removal breaks callers and '
              'stored data'
          : '[Unreleased] has ### $section',
    ));
  }

  if (inputs.unreleased.hasBreakingEntry) {
    reasons.add(const BumpReason(
      Bump.major,
      '[Unreleased] has a **BREAKING:** entry — a change that cannot be '
          'upgraded in place',
    ));
  }

  final previousSchema = inputs.previousSchemaVersion;
  if (previousSchema != null && inputs.schemaVersion > previousSchema) {
    reasons.add(BumpReason(
      Bump.minor,
      'schemaVersion $previousSchema → ${inputs.schemaVersion} '
          '(floor: a migration runs on every device)',
    ));
  }

  var folded = Bump.none;
  for (final reason in reasons) {
    folded = Bump.max(folded, reason.bump);
  }

  final clamped = folded == Bump.major && base.isPreOneZero;
  if (clamped) {
    folded = Bump.minor;
    reasons.add(const BumpReason(
      Bump.minor,
      'pre-1.0: MAJOR suppressed to MINOR — 0.y.z → 1.0.0 is a deliberate '
          'call (#79). The release needs a migration note',
    ));
  }

  if (folded == Bump.none) {
    reasons.add(BumpReason(
      Bump.none,
      inputs.unreleased.isEmpty
          ? '[Unreleased] is empty'
          : '[Unreleased] has only ${inputs.unreleased.sections.map((s) => '### $s').join(', ')}'
              ' — nothing a user of the app sees',
    ));
  }

  // The build number only ever goes up. Taking the max of the working tree and
  // the last release survives a botched revert of the pubspec.
  final releasedBuild = inputs.lastReleaseVersion?.build ?? 0;
  final highestBuild = inputs.pubspecVersion.build > releasedBuild
      ? inputs.pubspecVersion.build
      : releasedBuild;
  final nextBuild = highestBuild + 1;

  final effective = inputs.forcedBump ?? folded;
  if (inputs.forcedBump != null && inputs.forcedBump!.index < folded.index) {
    notes.add('--bump ${inputs.forcedBump!.label} is *lower* than the '
        'computed ${folded.label} — the reasons above say otherwise');
  }

  return BumpDecision(
    computed: folded,
    effective: effective,
    reasons: reasons,
    notes: notes,
    clamped: clamped,
    base: base,
    nextBuild: nextBuild,
  );
}

/// Everything `--verify-release` inspects, all read from git at the tag rather
/// than from the working tree.
class VerifyInputs {
  const VerifyInputs({
    required this.tag,
    required this.changelog,
    required this.pubspec,
    required this.databaseDart,
    required this.snapshotFileNames,
    this.previousTag,
    this.previousPubspec,
    this.previousDatabaseDart,
  });

  /// The pushed tag, e.g. `v0.3.1`.
  final String tag;

  /// `CHANGELOG.md`, `app/pubspec.yaml`, `app/lib/data/database.dart` and the
  /// `app/drift_schemas/` listing, all as of [tag].
  final String changelog;
  final String pubspec;
  final String databaseDart;
  final List<String> snapshotFileNames;

  /// The release before [tag], or null when this is the first one.
  final String? previousTag;
  final String? previousPubspec;
  final String? previousDatabaseDart;
}

/// Checks a tagged commit against the repo, returning **every** problem found
/// rather than stopping at the first — a release is cut rarely enough that one
/// round trip should report all of it.
///
/// An empty list means the tag is consistent with the pubspec, the CHANGELOG
/// and the schema snapshots, and may be built.
List<String> verifyRelease(VerifyInputs inputs) {
  final problems = <String>[];

  // 1. The tag itself.
  if (!RegExp(r'^v\d+\.\d+\.\d+$').hasMatch(inputs.tag)) {
    problems.add('tag "${inputs.tag}" is not vX.Y.Z');
    return problems; // Nothing below can be checked against a nonsense tag.
  }
  final tagged = SemverVersion.parse(inputs.tag.substring(1));

  // 2. Tag vs pubspec, the check that would have caught v0.0.3 shipping a
  //    pubspec that still read 0.0.2+4.
  SemverVersion? pubspecVersion;
  try {
    pubspecVersion = parsePubspecVersion(inputs.pubspec);
    if (pubspecVersion.release != tagged.release) {
      problems.add('tag ${inputs.tag} does not match app/pubspec.yaml '
          '($pubspecVersion) at that commit');
    }
  } on FormatException catch (e) {
    problems.add('app/pubspec.yaml: ${e.message}');
  }

  // 3-4. The CHANGELOG entry for this version.
  final headings = parseReleaseHeadings(inputs.changelog);
  ReleaseHeading? heading;
  for (final candidate in headings) {
    if (candidate.version.release == tagged.release) {
      heading = candidate;
      break;
    }
  }
  if (heading == null) {
    problems.add('CHANGELOG.md has no `## [${tagged.release}] - YYYY-MM-DD` '
        'heading — was [Unreleased] promoted?');
  } else {
    if (!_isPlausibleIsoDate(heading.date)) {
      problems.add('CHANGELOG.md [${tagged.release}] has an implausible date '
          '"${heading.date}"');
    }
    try {
      final entry = parseChangelogEntry(inputs.changelog, tagged.release);
      if (entry.isEmpty) {
        problems.add('CHANGELOG.md [${tagged.release}] has no ### sections — '
            'an empty promotion');
      }
    } on FormatException catch (e) {
      problems.add(e.message);
    }
  }

  // 5-6. The link-reference block, rewritten by every cut.
  final linkRefs = parseLinkRefs(inputs.changelog);
  if (!linkRefs.containsKey(tagged.release)) {
    problems.add('CHANGELOG.md has no `[${tagged.release}]:` link reference');
  }
  final unreleasedRef = linkRefs['Unreleased'];
  if (unreleasedRef == null) {
    problems.add('CHANGELOG.md has no `[Unreleased]:` link reference');
  } else if (!unreleasedRef.endsWith('${inputs.tag}...HEAD')) {
    problems.add('CHANGELOG.md [Unreleased] compares from $unreleasedRef — '
        'expected it to end ${inputs.tag}...HEAD');
  }

  // 9. Snapshots vs schemaVersion, on the tagged commit.
  int? schemaVersion;
  try {
    schemaVersion = parseSchemaVersion(inputs.databaseDart);
    final snapshots = parseSnapshotVersions(inputs.snapshotFileNames);
    if (snapshots.highest != schemaVersion) {
      problems.add(snapshots.versions.isEmpty
          ? 'schemaVersion is $schemaVersion but app/drift_schemas/ holds no '
              'snapshots at all'
          : 'schemaVersion is $schemaVersion but the newest snapshot is '
              'drift_schema_v${snapshots.highest}.json — the schema dump step '
              'was skipped');
    }
    if (!snapshots.isContiguous) {
      problems.add('drift_schemas/ is missing snapshots for '
          'v${snapshots.missing.join(', v')}');
    }
  } on FormatException catch (e) {
    problems.add('app/lib/data/database.dart: ${e.message}');
  }

  // 7-8, 10. Everything that needs the previous release to compare against.
  final previousPubspec = inputs.previousPubspec;
  if (previousPubspec == null) {
    return problems; // First release — nothing to compare against.
  }

  SemverVersion? previous;
  try {
    previous = parsePubspecVersion(previousPubspec);
  } on FormatException catch (e) {
    problems.add('${inputs.previousTag} app/pubspec.yaml: ${e.message}');
  }
  if (previous == null || pubspecVersion == null) return problems;

  if (pubspecVersion.build <= previous.build) {
    problems.add('build number ${pubspecVersion.build} is not higher than '
        '${inputs.previousTag}\'s ${previous.build} — Android rejects a '
        'versionCode that does not increase');
  }
  if (tagged.compareRelease(previous) <= 0) {
    problems.add('version ${tagged.release} is not higher than '
        '${inputs.previousTag}\'s ${previous.release}');
  }

  final previousDatabaseDart = inputs.previousDatabaseDart;
  if (previousDatabaseDart != null && schemaVersion != null) {
    try {
      final previousSchema = parseSchemaVersion(previousDatabaseDart);
      if (schemaVersion > previousSchema &&
          bumpBetween(previous, tagged).index < Bump.minor.index) {
        problems.add('schemaVersion rose $previousSchema → $schemaVersion '
            'since ${inputs.previousTag}, so this needs at least a MINOR — '
            '${previous.release} → ${tagged.release} is only a PATCH');
      }
    } on FormatException {
      // The previous release predates the check; not this release's problem.
    }
  }

  return problems;
}

bool _isPlausibleIsoDate(String date) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(date);
  if (match == null) return false;
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  return month >= 1 && month <= 12 && day >= 1 && day <= 31;
}
