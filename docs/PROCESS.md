# Golfy process

Golfy follows the shared development process in `~/.claude/dev_process/PROCESS.md`: a branch
and a pull request per issue, squash merges, the shared issue forms and PR titles, and the
shared version calculator. This page adds only what's specific to Golfy, and records where it
still does things its own way. The facts the process needs, such as commands and the default
branch, are in the Dev process table in `CLAUDE.md`, and the architecture is in
[ARCHITECTURE.md](ARCHITECTURE.md).

## Differences from the shared process

| Area           | This project                                                                                                                                      | Why, and whether to converge                                                                                               |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| Labels         | Unprefixed area labels (`ui`, `ux`, `database`, `infra`, `android`), and `semver:none`, `semver:patch`, or `semver:minor` on issues at triage.    | They already work, beside the process labels. The `semver:` labels are a triage note; they never decide the version. Keep. |
| Versions       | Every release also raises the build number (`+N`) in `app/pubspec.yaml`, because it's Android's `versionCode`.                                    | Google Play rejects a lower one. Permanent.                                                                                |
| Release checks | Besides the shared `release.mjs verify`, the release workflow checks the pubspec, the link references, the build number, and the drift snapshots. | Those are Golfy's own release metadata (RELEASING.md, "What CI enforces"). Keep.                                           |
| Older issues   | Issues filed before the shared forms keep their plain titles.                                                                                     | Retitling them adds nothing. New issues use the forms and roadmap ids.                                                     |

## Definition of Ready additions

- [ ] A change to stored data says how existing rounds migrate, and plans the new
      `app/drift_schemas/drift_schema_vN.json` and its migration test.
- [ ] A change to what a backup holds updates BACKUP_FORMAT.md, and says how older backups
      restore.
- [ ] UI work says how each new control reads with TalkBack.

## Definition of Done additions

- [ ] CI passes: `build` (Linux: analyze, test, debug APK), `build-windows`, `Process check`,
      and `Title and description`.
- [ ] A schema change ships its `drift_schema_vN.json` and passes the migration tests, and its
      changelog entry is under Added or Changed: the schema floor makes the release a minor.
- [ ] No new Android permission, unless PRIVACY.md and the permission assertion in CI change
      with it.

## Code review additions

### Data safety

- Stored data changes through a drift schema version and a tested migration, never in place.
- Backups stay restorable: restoring validates the data it reads (BACKUP_FORMAT.md).

### Security and privacy

- Golfy asks for no Android permissions; `tool/assert_permissions.sh` checks the APK in CI.
- Release signing never changes: a different certificate blocks in-place updates and wipes
  user data (app/README.md, "Release signing").

## Testing

| Level              | Tool                                                                                   | Where it runs                    |
| ------------------ | -------------------------------------------------------------------------------------- | -------------------------------- |
| Static             | `flutter analyze`, and the process check                                               | CI (`build`, `Process check`)    |
| Unit and component | `flutter test` over `app/test/`: data access, features, theme, and accessibility       | CI (`build`, Linux)              |
| Integration        | The drift migration tests (`app/test/migration_test.dart`)                             | CI (`build`, Linux)              |
| End to end         | n/a: none yet                                                                          | n/a                              |
| Release QA         | Install the signed APK over the previous release on a device, and walk the golden path | Before publishing (RELEASING.md) |

## Release

- **How:** RELEASING.md. `/release` runs the shared calculator, rolls the changelog, bumps
  `version:` and the build number in `app/pubspec.yaml`, and opens a `Release: vX.Y.Z` pull
  request from `release/vX.Y.Z`; the tag on `master` follows the merge.
- **The floor:** `.github/release.json` makes any change under `app/drift_schemas/` at least a
  minor, because a new schema migrates every install.
- **What it builds:** `.github/workflows/release.yml` checks the tag (the shared
  `release.mjs verify`, then Golfy's metadata step), builds the signed APK, and drafts the
  GitHub release.
- **Not yet in CI:** the Google Play App Bundle (#75).

## Upgrades

- **Dependabot** opens pub and GitHub Actions updates weekly and Gradle updates monthly, all
  against `master`, titled `Upgrade: bump …`.
- **Merged by CI:** development dependencies' patch and minor updates, and non-major GitHub
  Actions updates, once every job passes.
- **Wait for you:** production packages, the drift group (which may need a `build_runner`
  pass), the Gradle group (coupled to the pinned Flutter SDK), and every major.
- **High risk:** Flutter and Dart SDK majors, drift majors, the Android Gradle Plugin, and
  anything that touches signing.
- **Stored data:** each schema version is dumped to `app/drift_schemas/`, and the migration
  tests upgrade every earlier version.

## Automation

| Automation                                 | Trigger                                 | Lives in                                                |
| ------------------------------------------ | --------------------------------------- | ------------------------------------------------------- |
| Analyze, test, and build the debug APK     | Every PR, and pushes to `master`        | `.github/workflows/flutter-build.yml` (`build`)         |
| Windows build                              | The same                                | `.github/workflows/flutter-build.yml` (`build-windows`) |
| Process check                              | The same                                | `.github/workflows/flutter-build.yml` (`process`)       |
| Merge low-risk Dependabot updates          | A Dependabot PR, once CI passes         | `.github/workflows/flutter-build.yml` (`dependabot`)    |
| Check the tag, sign the APK, draft release | A `v*.*.*` tag                          | `.github/workflows/release.yml`                         |
| Dependency update PRs                      | Weekly (pub, Actions), monthly (Gradle) | `.github/dependabot.yml`                                |

The shared workflows (the PR standards check, the Claude review, `@claude`, and labels) are in
the process's "What's automated".

## Repository setup

- The `master` ruleset requires `build`, `build-windows`, `Process check`, and
  `Title and description`.
- Squash merging only, with the PR title as the commit message, and automatic deletion of head
  branches.
- The Claude review needs the `CLAUDE_CODE_OAUTH_TOKEN` and `DEV_PROCESS_SSH_KEY` secrets; it's
  skipped with a notice until both are set.
- Once this lands: delete the `test` and `deps/patch` branches.

## Terms

| Term            | Meaning                                                                    |
| --------------- | -------------------------------------------------------------------------- |
| Hole            | One hole's record: the source of truth every statistic is derived from     |
| Round           | One round played on a course; its statistics come from its holes           |
| Course template | A reusable course card, with its tee sets and pin sets                     |
| Backup          | The export file BACKUP_FORMAT.md describes, which restores a whole history |

## Known gaps

- No end-to-end tests; the golden path is checked by hand on a device.
- The Google Play App Bundle is built by hand (#75).
