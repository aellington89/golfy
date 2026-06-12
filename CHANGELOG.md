# Changelog

All notable changes to Golfy are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Versions track the `version:` field in [`app/pubspec.yaml`](app/pubspec.yaml).

## [Unreleased]

### Added
- Continuous integration via GitHub Actions: every push and pull request to
  `master` runs the test suite and builds a debug Android APK on Linux, plus a
  Windows desktop build, with the build outputs uploaded as workflow artifacts
  ([#18]).

## [0.0.3] - 2026-06-09

Phase 3 (quality & polish) — the app now respects the system dark / light
setting, every screen has a proper empty state, and a completed round can be
re-opened from its scorecard and edited.

### Added
- System-driven dark / light theme: the app follows the OS appearance setting
  via `ThemeMode.system`, with light and dark schemes built from the shared
  deep-purple seed. No in-app toggle for v0.1.0 ([#16]).
- Icon-led empty states on the Rounds and Dashboard screens, unified with Hole
  Entry's through a reusable `EmptyState` widget ([#16]).
- Edit a completed round: the scorecard's **Edit** action re-opens the round in
  Hole Entry with all 18 holes pre-filled; saving a hole upserts in place (no
  duplicate row) and the scorecard reflects the change, while the Finish action
  reads "Done" when you re-opened an already-complete round ([#17]).

### Changed
- Score-to-par colours are now brightness-aware — the green / amber bands shift
  to lighter shades on a dark scheme so they stay legible on a dark surface
  ([#16]).

## [0.0.2] - 2026-06-06

Phase 2 (core features) — round management, hole-by-hole entry, and the lifetime
dashboard. Every screen in the 3-tab shell is now functional on top of the
v0.0.1 data layer.

### Added
- Course picker bottom sheet and add-course dialog, with a duplicate pre-check
  and race-safe insert ([#8]).
- Rounds list backed by a reactive stream, with swipe-to-delete and a new-round
  dialog that defaults to today, auto-increments the round number for a
  `(course, date)` pair, and jumps straight to Hole Entry ([#9]).
- Hole Entry screen: an 18-card swipeable `PageView` capturing
  par/score/fairway/GIR/putts/up-down/bunker/penalty/notes per hole, with
  in-memory drafts across swipes, quick-nav chips showing saved state, a Finish
  Round action, and tap-to-resume from the rounds list ([#10]).
- Read-only per-round scorecard — all 18 holes plus a totals row — reachable
  from the rounds list, with an Edit hand-off back to Hole Entry ([#11]).
- Delete-round confirmation shared by the rounds-list swipe row and a new
  scorecard delete action; deleting a round cascades its holes but leaves the
  course intact ([#12]).
- Dashboard lifetime-stats screen: Scoring, score-distribution mini bar chart,
  Accuracy, and Around-the-green cards, an em-dash for any no-data stat, and a
  "Play a round to see your stats." empty state ([#13]).
- Colour-coded score-to-par badges on rounds-list rows, sourced from a shared
  `scoreToParColor` helper now reused by the scorecard ([#14]).
- `intl` dependency for locale-aware date formatting in the rounds list.

### Changed
- Rounds-list rows are now tap-to-resume; the temporary #8 course-picker demo
  block was removed once the new-round dialog embedded it directly ([#9], [#10]).
- Score-to-par colours moved from the scorecard's earlier purple/red scheme to a
  consistent green / amber / red across the rounds list and scorecard ([#14]).

### Deferred
- Per-hole course-yardage columns (yards, drive / approach distance, tee club)
  are written with placeholder defaults pending [#22].

## [0.0.1] - 2026-05-24

Phase 1 — data layer and navigation shell.

### Added
- Flutter project targeting Android phones and Windows desktop, with build
  artefacts ignored ([#3], [#4]).
- drift data model — `courses`, `rounds`, `hole_results` — with foreign keys,
  CHECK constraints, and unique indexes; round and lifetime totals are derived
  from `hole_results` at query time ([#5]).
- DAO and query layer (`CourseDao`, `RoundDao`, `HoleResultDao`, `DashboardDao`),
  a `GolfyRepository` facade, and Riverpod providers ([#6]).
- 3-tab bottom-navigation app shell (Rounds / Hole Entry / Dashboard) with
  placeholder screens ([#7]).

### Changed
- Re-platformed from the original PySide6 prototype to Flutter ([#2]); the
  legacy Python sources were removed once the schema was reimplemented in drift.

[Unreleased]: https://github.com/aellington89/golfy/compare/v0.0.3...HEAD
[0.0.3]: https://github.com/aellington89/golfy/compare/v0.0.2...v0.0.3
[0.0.2]: https://github.com/aellington89/golfy/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/aellington89/golfy/releases/tag/v0.0.1
[#2]: https://github.com/aellington89/golfy/issues/2
[#3]: https://github.com/aellington89/golfy/issues/3
[#4]: https://github.com/aellington89/golfy/issues/4
[#5]: https://github.com/aellington89/golfy/issues/5
[#6]: https://github.com/aellington89/golfy/issues/6
[#7]: https://github.com/aellington89/golfy/issues/7
[#8]: https://github.com/aellington89/golfy/issues/8
[#9]: https://github.com/aellington89/golfy/issues/9
[#10]: https://github.com/aellington89/golfy/issues/10
[#11]: https://github.com/aellington89/golfy/issues/11
[#12]: https://github.com/aellington89/golfy/issues/12
[#13]: https://github.com/aellington89/golfy/issues/13
[#14]: https://github.com/aellington89/golfy/issues/14
[#16]: https://github.com/aellington89/golfy/issues/16
[#17]: https://github.com/aellington89/golfy/issues/17
[#18]: https://github.com/aellington89/golfy/issues/18
[#22]: https://github.com/aellington89/golfy/issues/22
