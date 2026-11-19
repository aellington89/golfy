# Releasing Golfy

How a release is cut, and how its version number is decided.

The short version: **the version is not chosen up front, it is derived from
what merged.** `node scripts/dev-process/release.mjs next`, the shared dev
process's calculator, reads the `## [Unreleased]` section of
[`CHANGELOG.md`](CHANGELOG.md) and whether a new drift schema landed, and tells
you what to cut and why. CI then refuses a tag that disagrees with the repo.

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

Run the calculator first — if it says there's nothing to release, nothing
user-facing has landed since the last tag.

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
| `### Internal` / `### Deferred` only, or empty | no release | no release |

The build number (`+N`) always goes up by one. It is Android's `versionCode`,
and Play rejects an upload whose version code does not increase. The sideload
APK and the Google Play bundle share one application id, so they share that
sequence too: a build number shipped on either is spent on both.

Two rules deserve their own paragraph:

**A schema bump is a floor, not a category.** A new
`app/drift_schemas/drift_schema_vN.json` means a migration runs on every
device that installs the update. That is never a patch, whatever else is in the
release, so the calculator raises the answer to at least MINOR and says so. The
floor is set in [`.github/release.json`](.github/release.json), for any change
under `app/drift_schemas/`.

**Pre-1.0 never auto-produces a MAJOR.** The MAJOR rules above run in full and
fold in like any other, but while the project is on `0.y.z` the result is
clamped down to MINOR — `0.y.z` → `1.0.0` is a deliberate declaration of
stability ([#79](https://github.com/aellington89/golfy/issues/79)), not
something a rule should decide on your behalf. The clamp is reported rather
than hidden:

```
Current: v0.10.0
Next:    v0.11.0 (minor)
  - major: 1 entry under ### Removed
  - minor: before 1.0.0, a major is held to a minor; 1.0.0 is your decision
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

From the repository root. It needs nothing but the repo and its tags — no
network, no `gh`, no token.

```bash
node scripts/dev-process/release.mjs next
```

```
Current: v0.10.0
Next:    nothing to release; Unreleased has no user-facing entries
  - none: 1 entry under ### Internal
```

Each reason names the section, the breaking entry, or the floor behind it.
`--json` prints the same for a script. The calculator is the shared dev
process's ([`aellington89/dev_process`](https://github.com/aellington89/dev_process)),
synced into `scripts/dev-process/` and tested there; Golfy's own part is the
schema floor in `.github/release.json`.

### Overriding the computed bump

```bash
node scripts/dev-process/release.mjs prepare 1.0.0
```

The rules cannot decide that the data format and core behaviour are now stable
— that is what `v1.0.0` means here, and it is
[#79](https://github.com/aellington89/golfy/issues/79)'s job. Passing a version
to `prepare` (or to `/release`) overrides the computed one. CI's check then
warns about a bigger step than the changelog needs, and refuses a smaller one.

## Cutting the release

Do it on a `release/vX.Y.Z` branch and open a pull request titled
`Release: vX.Y.Z`, so the cut goes through CI like anything else. `/release`
does steps 1 to 6 and opens the pull request.

1. **Run the calculator** and note the version it gives you.
2. **Promote `[Unreleased]`:** `node scripts/dev-process/release.mjs prepare`
   (or `prepare X.Y.Z` to override). It inserts the `## [X.Y.Z] - YYYY-MM-DD`
   heading below an empty `## [Unreleased]`, and updates the link references
   at the foot of the file.
3. **Write the release preamble** above the sections: a few paragraphs on what
   changed and why anyone should care, in the register of the entries below
   it. Say explicitly whether the schema moved, and include a migration note
   if the bump was held from a MAJOR.
4. **Bump `version:` in [`app/pubspec.yaml`](app/pubspec.yaml)** to
   `X.Y.Z+N`, where `N` is one more than the previous release's build number.
5. **Refresh the status section in [`README.md`](README.md)**: the
   `## Status — vX.Y.Z` heading and the narrative under it, demoting the
   previous release to the paragraph below.
6. **Refresh the test counts**, which are quoted in both
   [`README.md`](README.md) and [`app/README.md`](app/README.md). Run
   `flutter test` and use the number it reports.
7. **Squash-merge the pull request**, then tag `master` and push the tag:

   ```bash
   git switch master && git pull && git tag -a vX.Y.Z -m vX.Y.Z && git push origin vX.Y.Z
   ```

The tag is what triggers the release build. Nothing else does.

## What CI enforces

A `v*.*.*` tag push runs
[`.github/workflows/release.yml`](.github/workflows/release.yml), which checks
the tag against the repo **before** it builds anything, and reports every
failure at once:

- **The version,** with `node scripts/dev-process/release.mjs verify vX.Y.Z`:
  the tag is `vX.Y.Z`, `CHANGELOG.md` has its `## [X.Y.Z]` heading with at
  least one entry, and the version is at least the bump its entries and the
  schema floor need from the previous release. A bigger step, such as
  `v1.0.0`, passes with a warning.
- **The metadata,** in the workflow's own step: the tag matches
  `app/pubspec.yaml` at that commit; the `[X.Y.Z]:` link reference exists and
  `[Unreleased]:` compares from `vX.Y.Z...HEAD`; the build number is higher
  than the previous release's; and the newest `drift_schemas/` snapshot
  matches `schemaVersion`, with no gaps.

The pubspec check is not hypothetical. `v0.0.3` was tagged on a commit whose
pubspec still read `0.0.2+4`, and it went unnoticed for eight releases.

A `workflow_dispatch` run of the same workflow is the dry run: it builds and
verifies the APK without creating a Release, and prints the calculator's
preview instead of the tag check.

## After the release

1. **Validate on-device from the draft Release's APK**, installing *over* the
   previous version. In-place upgrade is the entire reason the release keystore
   is guarded — see [Release signing](app/README.md#release-signing).
2. **Publish the draft GitHub Release.** CI creates it as a draft on purpose.
   Optionally, until [#75](https://github.com/aellington89/golfy/issues/75)
   automates it, build the Google Play bundle from the tag, check it and upload
   it to the internal testing track by hand — see
   [Google Play (App Bundle)](app/README.md#google-play-app-bundle).
3. **Confirm `[Unreleased]` is empty** and its compare link points at the new
   tag; the release workflow checks the link.
4. **Confirm the READMEs match what shipped**: the `## Status` heading and the
   test counts.
5. **Reconcile the roadmap** in
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
