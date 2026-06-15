# Golfy

> A cross-platform tracker for **video-game golf** statistics (PGA Tour 2K,
> EA Sports PGA Tour, and similar titles) — not real-world golf. Built with
> Flutter for Android phones and Windows desktop from a single codebase.

[![status](https://img.shields.io/badge/status-stable-brightgreen)](https://github.com/aellington89/golfy/releases)
[![CI](https://github.com/aellington89/golfy/actions/workflows/flutter-build.yml/badge.svg)](https://github.com/aellington89/golfy/actions/workflows/flutter-build.yml)
[![flutter](https://img.shields.io/badge/flutter-3.x-blue)](https://flutter.dev)
[![license](https://img.shields.io/badge/license-private-lightgrey)](#license)

---

## Why Golfy

In-game stat screens give you the round you just played — not the trend across
fifty rounds. Golfy is a small private companion app that captures **per-hole**
data as the source of truth, then derives every round-level and lifetime
statistic from it. That means a new stat is always one query away, not a
schema migration.

The data layer landed first (v0.0.1), then all three screens — round
management, hole-by-hole entry, and the lifetime dashboard (v0.0.2), polished to
a finished feel in v0.0.3 (system theming, empty states everywhere, editing of
completed rounds). **v0.1.0** is the first stable release: a signed APK you can
sideload and upgrade in place.

## Status — v0.1.0

Phase 4 of the [roadmap](https://github.com/aellington89/golfy/issues/1) is
complete — **v0.1.0 is Golfy's first stable release**: a signed Android APK,
built and published by CI, that upgrades in place over future versions:

| Feature | Issue | What it delivered |
|---|---|---|
| Debug-APK CI | [#18](https://github.com/aellington89/golfy/issues/18) | Every push/PR to `master` runs the tests and builds a debug APK plus a Windows desktop build as artifacts |
| Debug build isolation | [#23](https://github.com/aellington89/golfy/issues/23) | Debug builds install under a `.debug` application ID so dev data sandboxes away from a real install |
| Migrations & signing | [#24](https://github.com/aellington89/golfy/issues/24) | Step-based drift schema migrations (data survives upgrades) and a retained, upgrade-critical release keystore |
| Signed-APK release | [#19](https://github.com/aellington89/golfy/issues/19) | A `v*` tag builds, verifies, and publishes a signed release APK to a draft GitHub Release |

Earlier phases: Phase 3 polish — quality tests, system theming, and round
editing (issues [#15](https://github.com/aellington89/golfy/issues/15)–[#17](https://github.com/aellington89/golfy/issues/17))
— shipped in **v0.0.3**; Phase 2 core features
([#8](https://github.com/aellington89/golfy/issues/8)–[#14](https://github.com/aellington89/golfy/issues/14))
in **v0.0.2**; and Phase 1 data layer + app shell
([#3](https://github.com/aellington89/golfy/issues/3)–[#7](https://github.com/aellington89/golfy/issues/7))
in **v0.0.1**. See [`CHANGELOG.md`](CHANGELOG.md) for the full release history.

The historical [`golf_stats.xlsx`](https://github.com/aellington89/golfy/issues/20)
data was imported once, on-device, via a standalone converter
([`tools/import/`](tools/import/), [#33](https://github.com/aellington89/golfy/issues/33));
by design no import UI ships in the app. Still **not** captured: per-hole
course-yardage columns (yards, drive / approach distance, tee club —
[#22](https://github.com/aellington89/golfy/issues/22)), open for a future release.

## Stack

- **Flutter** (Dart) — single codebase for Android + Windows
- **drift** (typed SQLite ORM) — generated schema, reactive streams, in-memory testing
- **Riverpod 3** — dependency injection and reactive state
- **intl** — locale-aware date formatting in the UI
- **SQLite** — embedded local-only storage; no network, no sync

The database is a single SQLite file, `golfy.sqlite`, kept in the app's private
documents directory — nothing is ever sent over the network. On Android each
build variant sandboxes to its own database under its application ID: the
release build at `…/com.golfy.golfy_app/…` and the debug build at
`…/com.golfy.golfy_app.debug/…`, so development data never mixes with a real
install ([#23](https://github.com/aellington89/golfy/issues/23)). On Windows both
build modes share `%USERPROFILE%\Documents\golfy.sqlite`.

## Data model

```
courses ──┐
          │
          ▼
        rounds ──── hole_results (18 per round)
                    └─ par, score, fairwayHit, gir, putts,
                       upDownAttempt, upDownSuccess,
                       penaltyStrokes, bunkerVisited, sandSave,
                       yards, driveDistanceYards, …
```

Round totals and lifetime aggregates are **derived** from `hole_results` at
query time. The schema is enforced at the SQL level (FK RESTRICT on course
delete, FK CASCADE on round delete, UNIQUE on `(round_id, hole_number)`, CHECK
constraints on par / score / putts). App-level invariants that SQL can't
express (e.g. you can't make an up-and-down without attempting one) are
enforced by the DAO layer with loud `ArgumentError`s.

## Build & run

All Flutter commands run from `app/`. See [`app/README.md`](app/README.md) for
the full developer workflow. Quick start:

```powershell
cd app
flutter pub get
dart run build_runner build            # regenerate drift / DAO mixins
flutter test                           # 173 passing tests
flutter run -d windows                 # desktop
flutter run -d <android-device-id>     # Android
```

> **Releasing to Android?** Release builds are signed with a retained,
> **upgrade-critical** keystore — see
> [Release signing](app/README.md#release-signing). A different signing
> certificate on a later release blocks in-place updates and forces an
> uninstall that wipes user data, so the keystore must be backed up and reused
> for every release. Releases are cut by pushing a `v*` tag: CI builds the signed
> APK and drafts a GitHub Release — see
> [Continuous integration](app/README.md#continuous-integration).

## Repository layout

```
golfy/
├── app/                 # Flutter app (Dart + drift)
│   ├── lib/
│   │   ├── data/        # drift tables, DAOs, repository, providers, models
│   │   ├── features/    # rounds / hole_entry / dashboard screens
│   │   ├── shell/       # AppShell + bottom-nav state
│   │   ├── app.dart     # MaterialApp root
│   │   └── main.dart    # entry point
│   └── test/            # widget + DAO + schema-constraint tests
├── .gitattributes       # LF-pin generated Windows plugin glue
├── .gitignore
└── README.md            # you are here
```

## Roadmap

The full roadmap is tracked as a GitHub epic — see
[issue #1](https://github.com/aellington89/golfy/issues/1) for the live list.
Phases:

- **Phase 0** ✓ Decision — Flutter over PySide6
- **Phase 1** ✓ Foundation — data model, DAOs, and app shell (v0.0.1)
- **Phase 2** ✓ Core features — course/round management, hole entry, scorecard, and the lifetime dashboard (v0.0.2)
- **Phase 3** ✓ Quality & polish (v0.0.3) — dashboard stat-query tests ([#15](https://github.com/aellington89/golfy/issues/15)), empty states + input validation + dark/light theme ([#16](https://github.com/aellington89/golfy/issues/16)), and editing a completed round's holes ([#17](https://github.com/aellington89/golfy/issues/17))
- **Phase 4** ✓ Release (v0.1.0) — CI debug-APK builds ([#18](https://github.com/aellington89/golfy/issues/18)), debug-id build config ([#23](https://github.com/aellington89/golfy/issues/23)), schema-migration + keystore hardening ([#24](https://github.com/aellington89/golfy/issues/24)), and the signed-APK release pipeline ([#19](https://github.com/aellington89/golfy/issues/19))

## History

Golfy started life as a PySide6 desktop app in May 2026. After a week of work
it became clear the project would never reach Android from that stack, so the
framework was re-chosen via
[issue #2](https://github.com/aellington89/golfy/issues/2) and the codebase
was rebuilt in Flutter. The original Python sources were kept as a schema
reference through Phase 1 and removed in v0.0.1; the canonical schema
now lives in `app/lib/data/tables/`.

## License

Private project — no license granted. Reach out before reuse.
