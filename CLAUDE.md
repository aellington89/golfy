# Golfy

A small private companion app that tracks golf statistics for video game golf. Per-hole data is
the source of truth, and every round-level and lifetime statistic is derived from it. Flutter
for Android and Windows, with drift over SQLite. Solo-developer project, built with the shared
dev process (Dev process, below).

## Commands

All Flutter commands run from `app/`; app/README.md has the full developer workflow.

- `flutter pub get`, then `dart run build_runner build` after changing drift tables or DAOs.
- `flutter analyze` and `flutter test`: what CI's Linux job runs.
- `flutter run -d windows`, or `flutter run -d <android-device-id>`.
- `node scripts/dev-process/release.mjs next`, from the root: the next version, derived from
  CHANGELOG.md and the drift schema floor. RELEASING.md explains the rules.

## Layout

- `app/lib/`: the app. `app/test/`: its tests. `app/drift_schemas/`: one JSON per schema
  version, for migration tests.
- RELEASING.md: how releases are cut and versioned. BACKUP_FORMAT.md: the backup file format.
  PRIVACY.md: what the app collects (nothing) and the permissions it asks for (none).

## Dev process

@~/.claude/dev_process/CONVENTIONS.md

This project follows the shared development process in `~/.claude/dev_process` (from
`aellington89/dev_process`; the version of its synced files is in `.dev-process.json`). Its
additions, and where it differs from the shared process, are in `docs/PROCESS.md`. The skills
read these facts:

| Fact              | Value                                                                                                                                      |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| Default branch    | `master`                                                                                                                                   |
| Verify            | `flutter analyze` and `flutter test` in `app/`, then `node scripts/dev-process/check-process.mjs` in the root                              |
| Unit tests        | `flutter test` in `app/`                                                                                                                   |
| End-to-end tests  | n/a: none yet; the golden path is checked on a device before a release (RELEASING.md)                                                      |
| Run the app       | `flutter run -d windows` in `app/`, or `-d <android-device-id>`                                                                            |
| Format            | `dart format .` in `app/`                                                                                                                  |
| Next version      | `node scripts/dev-process/release.mjs next` in the root (with the drift schema floor in `.github/release.json`)                            |
| Prepare a release | `node scripts/dev-process/release.mjs prepare`, then `version:` in `app/pubspec.yaml` to `X.Y.Z+N`, one build number higher (RELEASING.md) |
| User guide        | README.md: back up and restore, privacy, and help                                                                                          |
| Roadmap           | GitHub milestones named `Phase N`; a feature is `<N>.<n> · <name>` in its phase (RELEASING.md, "When to cut")                              |
