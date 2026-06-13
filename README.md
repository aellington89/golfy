# Golfy

> A cross-platform tracker for **video-game golf** statistics (PGA Tour 2K,
> EA Sports PGA Tour, and similar titles) — not real-world golf. Built with
> Flutter for Android phones and Windows desktop from a single codebase.

[![status](https://img.shields.io/badge/status-pre--release-orange)](https://github.com/aellington89/golfy/releases)
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
management, hole-by-hole entry, and the lifetime dashboard (v0.0.2). This
release (v0.0.3) polishes them to a finished feel: system theming, empty states
everywhere, and editing of completed rounds.

## Status — v0.0.3

Phase 3 of the [roadmap](https://github.com/aellington89/golfy/issues/1)
is complete — the v0.0.2 feature set is now polished to a finished feel, with
quality tests, system theming, and editing of completed rounds:

| Feature | Issue | What it delivered |
|---|---|---|
| Dashboard stat-query tests | [#15](https://github.com/aellington89/golfy/issues/15) | Unit coverage for every lifetime-stat aggregation, incl. division-by-zero, par-3 fairway exclusion, and best-round ties |
| Empty states, theming & colour | [#16](https://github.com/aellington89/golfy/issues/16) | Icon-led empty states via a shared `EmptyState` widget, system dark/light theme, and brightness-aware score colours (input validation shipped earlier in v0.0.2) |
| Edit a completed round | [#17](https://github.com/aellington89/golfy/issues/17) | Re-open any round from its scorecard with all 18 holes pre-filled; in-place upsert and a contextual Finish / Done action |

Phase 2 (course/round management, hole entry, scorecard, and the lifetime
dashboard — issues [#8](https://github.com/aellington89/golfy/issues/8)–[#14](https://github.com/aellington89/golfy/issues/14))
shipped in **v0.0.2**, and Phase 1 (data model, DAOs, repository, and app shell
— issues [#3](https://github.com/aellington89/golfy/issues/3)–[#7](https://github.com/aellington89/golfy/issues/7))
in **v0.0.1**. See [`CHANGELOG.md`](CHANGELOG.md) for the full release history.

What is **not** yet captured: per-hole course-yardage columns (yards, drive /
approach distance, tee club) are deliberately deferred to
[#22](https://github.com/aellington89/golfy/issues/22). With Phase 3 done,
Phase 4 (release) — CI debug-APK builds and the v0.1.0 checklist — is next.

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
flutter test                           # 170 passing tests
flutter run -d windows                 # desktop
flutter run -d <android-device-id>     # Android
```

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
- **Phase 4** Release — CI debug-APK builds ([#18](https://github.com/aellington89/golfy/issues/18)), the v0.1.0 release checklist ([#19](https://github.com/aellington89/golfy/issues/19)), debug-id build config ([#23](https://github.com/aellington89/golfy/issues/23)), and schema-migration + keystore hardening ([#24](https://github.com/aellington89/golfy/issues/24))

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
