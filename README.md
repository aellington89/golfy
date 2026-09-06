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

## Status — v0.1.4

**v0.1.4** is the latest release — it gives Golfy a golf-appropriate look and
smooths a couple of hole-entry rough edges:

| Feature | Issue | What it delivered |
|---|---|---|
| Golf-themed palette | [#53](https://github.com/aellington89/golfy/issues/53) | The app is re-themed from a single deep-purple seed to a golf palette — a fairway-green primary with flag-yellow and sky-blue accents — across light and dark, with the score-to-par colour bands kept coordinated |
| One-putt default | [#52](https://github.com/aellington89/golfy/issues/52) | A new, untouched hole now starts at one putt instead of two — fewer taps for the common one-putt or regulation hole |
| Event picker dropdown | [#51](https://github.com/aellington89/golfy/issues/51) | The Event field in the New / Edit Round dialogs is now a pick-from-list dropdown + modal sheet mirroring the Course picker; a brand-new event is added only via an explicit action, so a typo no longer spawns a duplicate |

It builds on **v0.1.3**, which tightened hole-entry data integrity and finished
the play-order form redesign ([#34](https://github.com/aellington89/golfy/issues/34),
[#37](https://github.com/aellington89/golfy/issues/37)).

It builds on **v0.1.2**, a hotfix on v0.1.1 that made a round's event, course,
date, round number and notes editable after creation
([#45](https://github.com/aellington89/golfy/issues/45)).

It builds on **v0.1.1**, which added event organisation and richer scoring
context:

| Feature | Issue | What it delivered |
|---|---|---|
| Event tracking | [#35](https://github.com/aellington89/golfy/issues/35) | Rounds can belong to a named event (tournament / league / casual); the Rounds list groups by event and each event carries a recorded result — a finishing position, a tie, or a missed cut |
| Score-distribution % | [#39](https://github.com/aellington89/golfy/issues/39) | The dashboard's score-distribution card shows each category's share of total holes as a percentage above the raw count |

**v0.1.0** was Golfy's first stable release and completed Phase 4 of the
[roadmap](https://github.com/aellington89/golfy/issues/1): a signed Android APK,
built and published by CI, that upgrades in place — debug-APK CI
([#18](https://github.com/aellington89/golfy/issues/18)), debug-build isolation
([#23](https://github.com/aellington89/golfy/issues/23)), step-based drift
migrations and a retained, upgrade-critical keystore
([#24](https://github.com/aellington89/golfy/issues/24)), and the signed-APK
release pipeline ([#19](https://github.com/aellington89/golfy/issues/19)).

Earlier phases: Phase 3 polish — quality tests, system theming, and round
editing (issues [#15](https://github.com/aellington89/golfy/issues/15)–[#17](https://github.com/aellington89/golfy/issues/17))
— shipped in **v0.0.3**; Phase 2 core features
([#8](https://github.com/aellington89/golfy/issues/8)–[#14](https://github.com/aellington89/golfy/issues/14))
in **v0.0.2**; and Phase 1 data layer + app shell
([#3](https://github.com/aellington89/golfy/issues/3)–[#7](https://github.com/aellington89/golfy/issues/7))
in **v0.0.1**. See [`CHANGELOG.md`](CHANGELOG.md) for the full release history.

The historical [`golf_stats.xlsx`](https://github.com/aellington89/golfy/issues/20)
data was imported once, on-device, via a one-time migration tool
([#33](https://github.com/aellington89/golfy/issues/33)); by design no import UI
ships in the app. Per-hole **yardage** is captured via reusable course templates
with multiple yardage sets ([#36](https://github.com/aellington89/golfy/issues/36)).
Still **not** captured: the per-round shot fields — drive / approach distance and
club used per shot ([#22](https://github.com/aellington89/golfy/issues/22)) —
open for a future release.

**What's next** lives in GitHub, not here — the per-release
[milestones](https://github.com/aellington89/golfy/milestones) (Phases 5–7,
through v0.2.0) and the
[Golfy Release Tracking](https://github.com/users/aellington89/projects/29)
project board. [`CHANGELOG.md`](CHANGELOG.md) remains the record of shipped
releases.

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
courses ──┬── course_holes (18 per course)   → shared par + stroke index
          ├── course_sets (named yardage sets) ── course_set_yards (18 per set)
          ▼
        rounds ──── hole_results (18 per round)
          │         └─ par, score, fairwayHit, gir, putts,
          │            upDownAttempt, upDownSuccess,
          └─ course_set_id  penaltyStrokes, bunkerVisited, sandSave,
             (played set)   yards, driveDistanceYards, …
```

A course optionally saves a **template**: a shared per-hole par + stroke index
(`course_holes`) and one or more named **yardage sets** (`course_sets`), each
with its own 18-hole yardage card (`course_set_yards`) so the same course can be
played at different yardages. A round records which set it used
(`rounds.course_set_id`); starting a round pre-fills each hole's par from the
course and yardage from the chosen set, and the round keeps its own editable
copy in `hole_results` — so a template edit never rewrites past rounds.
Round totals and lifetime aggregates are **derived** from `hole_results` at
query time. The schema is enforced at the SQL level (FK RESTRICT on course
delete, FK CASCADE on round / set delete, UNIQUE on `(round_id, hole_number)`,
`(course_id, hole_number)`, `(course_id, name)`, `(course_set_id, hole_number)`,
CHECK constraints on par / score / putts / yards). App-level invariants that SQL
can't express (e.g. you can't make an up-and-down without attempting one) are
enforced by the DAO layer with loud `ArgumentError`s.

## Build & run

All Flutter commands run from `app/`. See [`app/README.md`](app/README.md) for
the full developer workflow. Quick start:

```powershell
cd app
flutter pub get
dart run build_runner build            # regenerate drift / DAO mixins
flutter test                           # 284 passing tests
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
