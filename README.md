# Golfy

> A cross-platform tracker for **video-game golf** statistics (PGA Tour 2K,
> EA Sports PGA Tour, and similar titles) — not real-world golf. Built with
> Flutter for Android phones and Windows desktop from a single codebase.

[![status](https://img.shields.io/badge/status-pre--release-orange)](https://github.com/aellington89/golfy/releases)
[![flutter](https://img.shields.io/badge/flutter-3.x-blue)](https://flutter.dev)
[![license](https://img.shields.io/badge/license-private-lightgrey)](#license)

---

## Why Golfy

In-game stat screens give you the round you just played — not the trend across
fifty rounds. Golfy is a small private companion app that captures **per-hole**
data as the source of truth, then derives every round-level and lifetime
statistic from it. That means a new stat is always one query away, not a
schema migration.

The first phase (this pre-release) ships the data layer and a navigation shell;
the next phases fill in the three screens.

## Status — v0.0.1 pre-release

Phase 1 of the [roadmap](https://github.com/aellington89/golfy/issues/1) is
complete:

| Phase 1 | Issue | What it delivered |
|---|---|---|
| Flutter project init | [#3](https://github.com/aellington89/golfy/issues/3) | Cross-platform scaffold targeting Android + Windows |
| Build-artefact ignores | [#4](https://github.com/aellington89/golfy/issues/4) | `.gitignore` covers Flutter, Dart, Android, Windows outputs |
| Data model | [#5](https://github.com/aellington89/golfy/issues/5) | drift tables: `courses`, `rounds`, `hole_results` with FKs, CHECKs, unique indexes |
| DAO + query layer | [#6](https://github.com/aellington89/golfy/issues/6) | `CourseDao`, `RoundDao`, `HoleResultDao`, `DashboardDao`, `GolfyRepository`, Riverpod providers, 53 passing tests |
| App shell | [#7](https://github.com/aellington89/golfy/issues/7) | 3-tab bottom navigation (Rounds / Hole Entry / Dashboard) with placeholder screens |

What is **not** yet wired up: the three screens are placeholders. Round
creation, hole-by-hole entry, and dashboard rendering all land in Phase 2
(issues [#11](https://github.com/aellington89/golfy/issues/11)–[#13](https://github.com/aellington89/golfy/issues/13)).

## Stack

- **Flutter** (Dart) — single codebase for Android + Windows
- **drift** (typed SQLite ORM) — generated schema, reactive streams, in-memory testing
- **Riverpod 3** — dependency injection and reactive state
- **SQLite** — embedded local-only storage; no network, no sync

The database file lives at `~/.golfy/golfy.db` (Windows:
`%USERPROFILE%\.golfy\golfy.db`). Nothing is ever sent over the network.

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
flutter test                           # 53 passing tests
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

- **Phase 0** ✓ Framework decision (Flutter over PySide6)
- **Phase 1** ✓ Data + scaffold (this release)
- **Phase 2** Round management + hole-by-hole entry
- **Phase 3** Lifetime stats dashboard
- **Phase 4** Polish (empty states, error handling, app icon)

## History

Golfy started life as a PySide6 desktop app in May 2026. After a week of work
it became clear the project would never reach Android from that stack, so the
framework was re-chosen via
[issue #2](https://github.com/aellington89/golfy/issues/2) and the codebase
was rebuilt in Flutter. The original Python sources were kept as a schema
reference through Phase 1 and removed for this release; the canonical schema
now lives in `app/lib/data/tables/`.

## License

Private project — no license granted. Reach out before reuse.
