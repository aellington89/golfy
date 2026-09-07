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

## Status — v0.2.0

**v0.2.0** is the latest release — Golfy's largest yet. It completes the
**Courses & yardage** milestone and gives **Events** a home of their own:

| Feature | Issue | What it delivered |
|---|---|---|
| Course templates & yardage sets | [#36](https://github.com/aellington89/golfy/issues/36) | A course saves a shared per-hole par + stroke-index card plus any number of named yardage sets (tee boxes / pin sets); starting a round picks a set and pre-fills each hole's par and yardage, still editable per round. A new Courses screen (nav drawer) manages templates and sets, and renames or deletes a course |
| Per-shot tracking | [#22](https://github.com/aellington89/golfy/issues/22) | Each hole captures an ordered shot list — club, distance, lie and result per shot — replacing the old flat tee-club / drive / approach fields, and independent of scoring |
| Dedicated Events tab | [#42](https://github.com/aellington89/golfy/issues/42) | Events graduate from a field on a round to their own tab with event-first navigation: create an event up front, open it for its rounds and a per-event scoring summary, and edit or delete it |
| Events per season | [#47](https://github.com/aellington89/golfy/issues/47) | The same event name recurs each season as its own occurrence — its own result, rounds and edits — with the season a typed, editable field |
| Event tile scoring | [#63](https://github.com/aellington89/golfy/issues/63) | The Events list tiles carry a compact scoring line — average score vs. par and best round to-par — beside the round count |

It ships schema versions **v5–v7**, each a migration-tested, data-preserving
upgrade.

It builds on **v0.1.4**, which re-themed the app to a green / yellow / blue golf
palette and smoothed a couple of hole-entry rough edges
([#51](https://github.com/aellington89/golfy/issues/51),
[#52](https://github.com/aellington89/golfy/issues/52),
[#53](https://github.com/aellington89/golfy/issues/53)); **v0.1.3**, which
tightened hole-entry data integrity and finished the play-order form redesign
([#34](https://github.com/aellington89/golfy/issues/34),
[#37](https://github.com/aellington89/golfy/issues/37)); **v0.1.2**, a hotfix
making a round's details editable after creation
([#45](https://github.com/aellington89/golfy/issues/45)); and **v0.1.1**, which
added event organisation and the score-distribution percentage
([#35](https://github.com/aellington89/golfy/issues/35),
[#39](https://github.com/aellington89/golfy/issues/39)).

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
with multiple yardage sets ([#36](https://github.com/aellington89/golfy/issues/36)),
and each hole carries an ordered **per-shot list** — club, distance, lie and
result ([#22](https://github.com/aellington89/golfy/issues/22)).

**What's next** lives in GitHub, not here — the per-release
[milestones](https://github.com/aellington89/golfy/milestones) and the
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
        rounds ──── hole_results (18 per round) ── hole_shots (per-shot list)
          │         └─ par, score, yards, fairwayHit,    └─ club, distance,
          └─ course_set_id  gir, putts, upDown…,            lie, result
             (played set)   penalty, bunker, sandSave, …
```

A course optionally saves a **template**: a shared per-hole par + stroke index
(`course_holes`) and one or more named **yardage sets** (`course_sets`), each
with its own 18-hole yardage card (`course_set_yards`) so the same course can be
played at different yardages. A round records which set it used
(`rounds.course_set_id`); starting a round pre-fills each hole's par from the
course and yardage from the chosen set, and the round keeps its own editable
copy in `hole_results` — so a template edit never rewrites past rounds. Each hole
optionally carries an ordered **shot list** (`hole_shots`) — club, distance, lie
and result per shot — separate from the authoritative `score` / `putts`.
Round totals and lifetime aggregates are **derived** from `hole_results` at
query time. The schema is enforced at the SQL level (FK RESTRICT on course
delete, FK CASCADE on round / set / hole delete, UNIQUE on `(round_id,
hole_number)`, `(course_id, hole_number)`, `(course_id, name)`,
`(course_set_id, hole_number)`, `(hole_result_id, shot_number)`, CHECK
constraints on par / score / putts / yards). App-level invariants that SQL can't
express (e.g. you can't make an up-and-down without attempting one) are enforced
by the DAO layer with loud `ArgumentError`s.

## Build & run

All Flutter commands run from `app/`. See [`app/README.md`](app/README.md) for
the full developer workflow. Quick start:

```powershell
cd app
flutter pub get
dart run build_runner build            # regenerate drift / DAO mixins
flutter test                           # 390 passing tests
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
