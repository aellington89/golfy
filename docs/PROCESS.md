# Golfy process

Golfy follows the shared development process in `~/.claude/dev_process/PROCESS.md`. This page
adds only what's specific to Golfy, and records where it does things its own way. The facts the
process needs, such as commands and the default branch, are in the Dev process table in
`CLAUDE.md`.

## Differences from the shared process

| Area      | This project                                                                                                                                                                                    | Why, and whether to converge                                                                                                                                   |
| --------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Branching | Work lands on `test`, then reaches `master` in a `test` → `master` PR. Dependabot targets `deps/patch`, merged up in "Merge deps/patch up to master" PRs. Releases use `release/vX.Y.Z`.        | It predates the shared process. Converging to a branch per issue changes Dependabot's target and CI's triggers, so it deserves its own ADR and PR.             |
| PR titles | A sentence with the issue reference: `Make the Play bundle check run in Git Bash on Windows (#74)`. Releases are `Cut vX.Y.Z release`. The shared PR template and PR title check aren't synced. | The history is consistent this way. Converge together with the branching.                                                                                      |
| Issues    | Plain-sentence titles with no roadmap ids, and no issue forms (the shared forms aren't synced).                                                                                                 | Milestones group issues by theme instead of a numbered roadmap. Keep.                                                                                          |
| Labels    | Unprefixed area labels (`ui`, `ux`, `database`, `infra`, `android`), and `semver:none`, `semver:patch`, or `semver:minor` on PRs.                                                               | They already work; the process labels are added beside them. RELEASING.md explains why the `semver:` labels never decide the version. Keep.                    |
| Changelog | Keep a Changelog's sections plus `### Internal` and `### Deferred`, and a schema change raises the version to at least a minor.                                                                 | Golfy's own calculator, `tool/next_version.dart`, applies these rules, which otherwise match the shared table, so the shared `release.mjs` isn't synced. Keep. |
| Versions  | Every release also raises the build number (`+N`) in `app/pubspec.yaml`, because it's Android's `versionCode`.                                                                                  | Google Play rejects a lower one. Permanent.                                                                                                                    |

## Definition of Ready additions

- [ ] A change to stored data says how existing rounds migrate, and plans the new
      `app/drift_schemas/drift_schema_vN.json` and its migration test.
- [ ] A change to what a backup holds updates BACKUP_FORMAT.md, and says how older backups
      restore.
- [ ] UI work says how each new control reads with TalkBack.

## Definition of Done additions

- [ ] CI's `build` (Linux: analyze, test, debug APK) and `build-windows` jobs pass.
- [ ] A schema change ships its `drift_schema_vN.json` and passes the migration tests.
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

- **How:** RELEASING.md, "Cutting the release": a `release/vX.Y.Z` branch that rolls the
  changelog and bumps `version:` and the build number in `app/pubspec.yaml`, merged by PR, then
  a `vX.Y.Z` tag on `master`.
- **What it builds:** `.github/workflows/release.yml` builds the signed APK and drafts the
  GitHub release, and rejects a tag that disagrees with `tool/next_version.dart`.
- **Not yet in CI:** the Google Play App Bundle (#75).

## Upgrades

- **Dependabot** opens pub and GitHub Actions updates weekly and Gradle updates monthly, all
  against `deps/patch` (see Differences).
- **High risk:** Flutter and Dart SDK majors, drift majors, the Android Gradle Plugin, and
  anything that touches signing.
- **Stored data:** each schema version is dumped to `app/drift_schemas/`, and the migration
  tests upgrade every earlier version.

## Automation

| Automation                             | Trigger                                     | Lives in                                                |
| -------------------------------------- | ------------------------------------------- | ------------------------------------------------------- |
| Analyze, test, and build the debug APK | Pushes and PRs to `master` and `deps/patch` | `.github/workflows/flutter-build.yml` (`build`)         |
| Windows build                          | The same                                    | `.github/workflows/flutter-build.yml` (`build-windows`) |
| Process check                          | The same                                    | `.github/workflows/flutter-build.yml` (`process`)       |
| Signed APK and a draft release         | A `v*` tag                                  | `.github/workflows/release.yml`                         |
| Dependency update PRs                  | Weekly (pub, Actions), monthly (Gradle)     | `.github/dependabot.yml`                                |

## Repository setup

- If a ruleset is added for `master`, it requires `build`, `build-windows`, and
  `Process check`.
- The Claude review needs the `CLAUDE_CODE_OAUTH_TOKEN` and `DEV_PROCESS_SSH_KEY` secrets; it's
  skipped with a notice until both are set.

## Terms

| Term            | Meaning                                                                    |
| --------------- | -------------------------------------------------------------------------- |
| Hole            | One hole's record: the source of truth every statistic is derived from     |
| Round           | One round played on a course; its statistics come from its holes           |
| Course template | A reusable course card, with its tee sets and pin sets                     |
| Backup          | The export file BACKUP_FORMAT.md describes, which restores a whole history |

## Known gaps

- The shared issue forms, PR template, and PR title check aren't used until Golfy moves to a
  branch per issue (see Differences).
- No end-to-end tests; the golden path is checked by hand on a device.
