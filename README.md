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

The data layer landed first (v0.0.1); this release wires up all three screens —
round management, hole-by-hole entry, and the lifetime dashboard — on top of it.

## Status — v0.0.2 pre-release

Phases 2 and 3 of the [roadmap](https://github.com/aellington89/golfy/issues/1)
are complete — every screen in the 3-tab shell is now live on top of the v0.0.1
data layer:

| Feature | Issue | What it delivered |
|---|---|---|
| Course picker + add-course | [#8](https://github.com/aellington89/golfy/issues/8) | Reusable `CoursePicker` bottom sheet and `AddCourseDialog` with a duplicate pre-check |
| Rounds list + new round | [#9](https://github.com/aellington89/golfy/issues/9) | Reactive rounds list, swipe-to-delete, and a new-round dialog that jumps to Hole Entry |
| Hole Entry | [#10](https://github.com/aellington89/golfy/issues/10) | 18-card swipeable per-hole form with in-memory drafts, quick-nav chips, and tap-to-resume |
| Read-only scorecard | [#11](https://github.com/aellington89/golfy/issues/11) | Per-round scorecard (18 holes + totals) with hand-off to Hole Entry for edits |
| Delete-round confirmation | [#12](https://github.com/aellington89/golfy/issues/12) | Shared confirm-delete used by the rounds list and a scorecard delete action |
| Dashboard lifetime stats | [#13](https://github.com/aellington89/golfy/issues/13) | Scoring / distribution / accuracy / around-the-green cards, with an empty state |
| Score-vs-par row labels | [#14](https://github.com/aellington89/golfy/issues/14) | Colour-coded score-to-par badges on rounds-list rows, unified with the scorecard |

Phase 1 (data model, DAOs, repository, and app shell — issues
[#3](https://github.com/aellington89/golfy/issues/3)–[#7](https://github.com/aellington89/golfy/issues/7))
shipped in **v0.0.1**. See [`CHANGELOG.md`](CHANGELOG.md) for the full release
history.

What is **not** yet captured: per-hole course-yardage columns (yards, drive /
approach distance, tee club) are deliberately deferred to
[#22](https://github.com/aellington89/golfy/issues/22). Phase 4 polish — app
icon and broader error handling — is still open.

## Stack

- **Flutter** (Dart) — single codebase for Android + Windows
- **drift** (typed SQLite ORM) — generated schema, reactive streams, in-memory testing
- **Riverpod 3** — dependency injection and reactive state
- **intl** — locale-aware date formatting in the UI
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
flutter test                           # 150 passing tests
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
- **Phase 1** ✓ Data + scaffold (v0.0.1)
- **Phase 2** ✓ Round management + hole-by-hole entry (v0.0.2)
- **Phase 3** ✓ Lifetime stats dashboard (v0.0.2)
- **Phase 4** Polish — app icon, broader error handling, per-hole yardage entry ([#22](https://github.com/aellington89/golfy/issues/22))

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
