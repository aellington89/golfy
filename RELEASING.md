# Releasing Golfy

How a release is cut, and how its version number is decided.

The short version: **the version is not chosen up front, it is derived from
what merged.** `dart run tool/next_version.dart` reads the `## [Unreleased]`
section of [`CHANGELOG.md`](CHANGELOG.md) and the drift `schemaVersion`, and
tells you what to cut and why. CI then refuses a tag that disagrees with the
repo.

---

## When to cut

There is no schedule and no fixed scope. Cut when there is something a user
would want on their phone — a fix they hit, or a feature they asked for — and
the golden path still works on-device.

Milestones group issues thematically; they are **not** release containers, and
the order issues get implemented in will not line up with them. Nothing plans a
version in advance, which is the point: v0.3.0 was planned as the
export/import release and shipped the course editor instead. The record of what
actually shipped in a version is its `CHANGELOG.md` entry, with the `[#NN]`
references it carries, and the GitHub Release built from that tag.

Run the calculator first — if it says `NONE`, nothing user-facing has landed
since the last tag and there may be nothing to release.

## How the version is decided

Everything merged since the last `v*.*.*` tag should already be described in
`## [Unreleased]`. The section headings there are the input; each implies a
bump, and the largest one wins.

| In `[Unreleased]` | Pre-1.0 (`0.y.z`) | Post-1.0 (`1.y.z` and up) |
|---|---|---|
| `### Fixed` and/or `### Security` only | PATCH | PATCH |
| `### Added`, `### Changed` or `### Deprecated` | MINOR | MINOR |
| `### Removed` | MINOR, with a migration note | **MAJOR** |
| an entry opening `**BREAKING:**` | MINOR, with a migration note | **MAJOR** |
| drift `schemaVersion` rose since the last tag | at least MINOR | at least MINOR |
| `### Internal` / `### Deferred` only, or empty | NONE | NONE |

The build number (`+N`) always goes up by one. It is Android's `versionCode`,
and Play rejects an upload whose version code does not increase.

Two rules deserve their own paragraph:

**A schema bump is a floor, not a category.** A new
`app/drift_schemas/drift_schema_vN.json` means a migration runs on every
device that installs the update. That is never a patch, whatever else is in the
release, so the calculator raises the answer to at least MINOR and says so.

**Pre-1.0 never auto-produces a MAJOR.** The MAJOR rules above run in full and
fold in like any other, but while the project is on `0.y.z` the result is
clamped down to MINOR — `0.y.z` → `1.0.0` is a deliberate declaration of
stability ([#79](https://github.com/aellington89/golfy/issues/79)), not
something a rule should decide on your behalf. The clamp is reported rather
than hidden:

```
bump  MINOR
  - major: [Unreleased] has ### Removed — a removal breaks callers and stored data
  - minor: pre-1.0: MAJOR suppressed to MINOR — 0.y.z → 1.0.0 is a deliberate call (#79). The release needs a migration note
```

When that happens the release **needs a migration note** in its CHANGELOG
preamble: say plainly what a user loses or has to redo.

### Declaring a breaking change

`### Removed` covers a feature that is gone. The other kind — a data format
that cannot be upgraded in place — naturally files under `### Changed`, where
nothing about the heading says it is breaking. Mark the entry instead:

```markdown
### Changed

- **BREAKING:** the backup file format changed and 0.3.x backups cannot be
  restored. Export again after upgrading.
```

The marker has to open the bullet (`- **BREAKING:**`) — it is the one place the
tooling looks inside an entry rather than at its heading, and only at a fixed
position. It outranks whichever section it sits in.

That example is not hypothetical: the backup file format is a real contract
with files already on people's drives, and
[`BACKUP_FORMAT.md`](BACKUP_FORMAT.md#when-the-schema-changes) says when a
schema change forces this marker rather than an in-place upgrade. A guard test
fails until that call is made.

### `### Internal`, and the section order

Keep a Changelog's vocabulary assumes every entry is worth a user's attention.
Most of this repo's infrastructure work is not, and filing it under `### Added`
would bump the minor version of a release that changes nothing about the app —
which is exactly what happened with the Dependabot config before this section
existed.

The test is one question: **would someone running the installed APK notice?**
If no, it goes under `### Internal` — CI, tooling, tests, docs, dependency
bumps, behaviour-neutral refactors. If yes, it goes in a real section; a
performance fix that is actually felt belongs under `### Fixed`.

`### Internal` and `### Deferred` are local extensions and contribute no bump.
Sections are written in this order, and anything outside the set is an error
rather than something the calculator quietly skips:

> Added · Changed · Deprecated · Removed · Fixed · Security · Internal ·
> Deferred

## Running the calculator

From `app/`. It needs nothing but the repo — no network, no `gh`, no token.

```bash
cd app && dart run tool/next_version.dart
```

```
current        0.3.1+36              app/pubspec.yaml
last release   v0.3.1  0.3.1+34
schema         7  (unchanged since v0.3.1)   snapshots v1..v7 consistent
merged since   v0.3.1: #102

[Unreleased]   ### Internal

bump  NONE
  - none: [Unreleased] has only ### Internal — nothing a user of the app sees

next  (no release needed)
      if you cut one anyway it is a PATCH: 0.3.2+37
```

The `merged since` line is there to be read against the `[Unreleased]` line
below it. It comes from the merge commits' subjects, so a squash merge will not
appear; it is a prompt to notice "four pull requests, one section — did
something forget its changelog entry?", not an input to the decision.

`--json` prints the same information for a script. `--help` lists the options.

### Overriding the computed bump

```bash
cd app && dart run tool/next_version.dart --bump major
```

The rules cannot decide that the data format and core behaviour are now stable
— that is what `v1.0.0` means here, and it is
[#79](https://github.com/aellington89/golfy/issues/79)'s job. `--bump` forces
the answer while still printing what the rules computed, and warns if you pick
something *lower* than they did.

## Cutting the release

Four files change, and they have changed together for every release since
v0.2.0. Do them on a `release/vX.Y.Z` branch and open a pull request, so the
cut goes through CI like anything else.

1. **Merge `deps/patch` up first** if there are dependency bumps waiting on it
   — see [Dependency updates](app/README.md#dependency-updates). A patch
   release is the batching point for those.
2. **Run the calculator** and note the version it gives you.
3. **Promote `[Unreleased]` in [`CHANGELOG.md`](CHANGELOG.md).** Insert a
   `## [X.Y.Z] - YYYY-MM-DD` heading below the `## [Unreleased]` heading,
   leaving `[Unreleased]` in place and empty. Write the release preamble above
   the sections: a few paragraphs on what changed and why anyone should care,
   in the register of the entries above it. Say explicitly whether the schema
   moved, and include a migration note if the bump was clamped from a MAJOR.
4. **Update the link references** at the foot of the file: point
   `[Unreleased]` at `compare/vX.Y.Z...HEAD`, and add
   `[X.Y.Z]: .../compare/v<previous>...vX.Y.Z`. Add an issue reference for
   anything newly cited.
5. **Bump `version:` in [`app/pubspec.yaml`](app/pubspec.yaml)** to the
   `X.Y.Z+N` the calculator printed.
6. **Refresh the status section in [`README.md`](README.md)**: the
   `## Status — vX.Y.Z` heading and the narrative under it, demoting the
   previous release to the paragraph below.
7. **Refresh the test counts**, which are quoted in both
   [`README.md`](README.md) and [`app/README.md`](app/README.md). Run
   `flutter test` and use the number it reports.
8. **Merge the pull request**, then tag `master` and push the tag:

   ```bash
   git switch master && git pull && git tag vX.Y.Z && git push origin vX.Y.Z
   ```

The tag is what triggers the release build. Nothing else does.

## What CI enforces

A `v*.*.*` tag push runs
[`.github/workflows/release.yml`](.github/workflows/release.yml), which checks
the tag against the repo **before** it builds anything:

```bash
cd app && dart run tool/next_version.dart --verify-release v0.3.1
```

Everything is read from git at the tag rather than from the working tree, so
any historical tag can be checked from any checkout — which is also how the
guards themselves are tested. Ten things are checked, and all the failures are
reported at once:

1. The tag is `vX.Y.Z`.
2. It matches `app/pubspec.yaml` at that commit.
3. `CHANGELOG.md` has a `## [X.Y.Z] - YYYY-MM-DD` heading with a plausible date.
4. That heading has at least one `###` section under it.
5. There is a `[X.Y.Z]:` link reference.
6. `[Unreleased]:` compares from `vX.Y.Z...HEAD`.
7. The build number is higher than the previous release's.
8. The version is higher than the previous release's.
9. The newest `drift_schemas/` snapshot matches `schemaVersion`, with no gaps.
10. If `schemaVersion` rose since the previous release, the version moved by at
    least a MINOR.

Check 2 is not hypothetical. `v0.0.3` was tagged on a commit whose pubspec
still read `0.0.2+4`, and it went unnoticed for eight releases:

```
$ cd app && dart run tool/next_version.dart --verify-release v0.0.3
v0.0.3 has 5 problems:

  - tag v0.0.3 does not match app/pubspec.yaml (0.0.2+4) at that commit
  - CHANGELOG.md has no `## [0.0.3] - YYYY-MM-DD` heading — was [Unreleased] promoted?
  - CHANGELOG.md has no `[0.0.3]:` link reference
  - ...
```

A `workflow_dispatch` run of the same workflow is the dry run: it builds and
verifies the APK without creating a Release, and prints the calculator's
preview instead of the tag check.

> The rules live in [`app/tool/release_rules.dart`](app/tool/release_rules.dart),
> which imports nothing, and are unit-tested in
> [`app/test/tool/release_rules_test.dart`](app/test/tool/release_rules_test.dart).
> That file also parses the repo's own CHANGELOG, pubspec and schema, so a
> format change fails a test rather than a release. It touches no sqlite, so it
> is safe to run on its own on Windows:
> `flutter test test/tool/release_rules_test.dart`.

## After the release

1. **Validate on-device from the draft Release's APK**, installing *over* the
   previous version. In-place upgrade is the entire reason the release keystore
   is guarded — see [Release signing](app/README.md#release-signing).
2. **Publish the draft GitHub Release.** CI creates it as a draft on purpose.
3. **Fast-forward `deps/patch` back onto `master`** so it does not accumulate
   conflicts:
   `git switch deps/patch && git merge --ff-only master && git push`.
4. **Confirm `[Unreleased]` is empty** and its compare link points at the new
   tag — `--verify-release vX.Y.Z` covers both.
5. **Confirm the READMEs match what shipped**: the `## Status` heading and the
   test counts.
6. **Reconcile the roadmap** in
   [#80](https://github.com/aellington89/golfy/issues/80) with what actually
   shipped. Milestones are not closed per release.

## Why labels are not an input

Issues carry a `## Semver` note and, from #86 onward, a `semver:*` label at
triage. Neither feeds the calculator, deliberately:

- **Coverage.** Roughly half of merged pull requests carry no labels at all. A
  cross-check that silently sees nothing half the time is worse than no
  cross-check, because it teaches you to trust it.
- **Offline.** Reading labels means the network, a `gh` token and rate limits,
  in a tool whose whole value is that it runs from a bare checkout, in CI, with
  nothing configured.
- **One truth.** The issue note, the label and the CHANGELOG section would be
  three claimants to the same decision, and two of them would drift.

The labels exist as planning annotations, and to build up the data a future
cross-check would need —
[#103](https://github.com/aellington89/golfy/issues/103) is that check, waiting
on enough labelled history to be worth running. The calculator folds every
reason through one list, so a label source would be another producer of reasons
rather than a reshape.
