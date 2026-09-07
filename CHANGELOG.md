# Changelog

All notable changes to Golfy are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Versions track the `version:` field in [`app/pubspec.yaml`](app/pubspec.yaml).

## [Unreleased]

### Added
- **Course templates with multiple yardage sets** ([#36]): a course now saves a
  shared per-hole **par + stroke index** card, plus any number of named
  **yardage sets** (a "pin set" or tee box), each with its own 18-hole yardage
  card — so the same course can be played at different yardages. A new
  course-management screen (reached from the app's **navigation drawer →
  Courses**) edits the par/SI card and adds / renames /
  deletes sets and their yardages; a course can also be renamed or deleted
  (delete is blocked while it still has rounds). Starting a round lets you pick
  one of the course's sets; Hole Entry then **pre-fills par from the course and
  yardage from the chosen set**, still editable per round (the round keeps its
  own copy, so template edits never rewrite past rounds). Adds `course_holes`
  (par + stroke index), `course_sets`, `course_set_yards`, and a nullable
  `rounds.course_set_id` (`SET NULL` on delete) at schema **v6** — a plain
  additive migration.
- A dedicated **Events** tab ([#42]): create an event up front — including an
  empty one with no rounds yet — from a `+` action, rather than only as a side
  effect of starting a round. Open an event to see its rounds, add a round with
  the event pre-selected, edit its result, **edit** its name or season, or
  **delete** it, and see a per-event scoring summary (rounds scored, average
  score vs. par, best round). Deleting an event stays non-destructive — its rounds are detached to
  "No event" (`SET NULL`), never deleted. The Rounds-tab event headers now tap
  through to the same detail screen. No schema change: builds on the #35 data
  layer and the existing `eventsStreamProvider`, adding only an event-details
  update method on `EventDao` (`rename`, generalized to name + season in #47).
- Internal: a keyed `event → rounds` query (`RoundDao.watchRoundsForEvent`,
  surfaced as `roundsForEventProvider`) so the Events feature can fetch a single
  event's rounds directly rather than filtering the full rounds stream in
  memory. Data-model groundwork for per-event stats; no user-facing or schema
  change — builds on the existing `rounds.event_id` index from #35 ([#55]).
- Internal: the Event detail screen's scoring summary (rounds scored, average
  score vs. par, best round — shipped in #42) is now a **DB-derived aggregate**
  (`DashboardDao.watchEventStats`, modeled as `EventStats` and surfaced via
  `eventStatsStreamProvider`), and the screen's rounds list now reads the keyed
  `event → rounds` query (#55) — replacing the in-memory computation. Mirrors the
  lifetime dashboard aggregate; no schema or user-facing change ([#56]).

### Changed
- Events are now distinct **per season**: the same event name recurs each season
  as its own occurrence — with its own result, rounds, and edits — instead of a
  single shared row per name. The New/Edit Round pickers, the Events tab, the
  detail screen and the Rounds-tab headers all show the season (e.g. "The
  Legends Championship (Season 2)"). The season is a typed number field when
  adding an event (auto-filling the next unused season when you re-enter an
  existing name) and is editable afterwards from the event's **Edit** action
  (which now changes both name and season). Recording a result on one season no
  longer overwrites another's. Adds an
  `events.season` column (`NOT NULL`, default 1) and swaps the unique key to
  `(name, season)` at schema **v5**; the migration recreates the `events` table,
  preserves existing events and their round links, and backfills every existing
  event to season 1 ([#47]).

## [0.1.4] - 2026-07-19

This release gives Golfy a golf-appropriate look and smooths a couple of
hole-entry rough edges: the app is re-themed from deep purple to a green /
yellow / blue golf palette, a new hole now starts at one putt instead of two, and
the Event field becomes a pick-from-list dropdown so a typo can't silently spawn
a duplicate event.

### Changed
- The **Event** field in the New Round and Edit Round dialogs is now a dropdown
  + modal-sheet picker matching the Course picker, replacing the free-text
  typeahead. Existing events are chosen from a list and a brand-new event is
  created only via an explicit "Add new event…" action — so a typo no longer
  silently spawns a duplicate event. The field stays optional via a
  "No event / Casual round" choice, and editing a round pre-selects its current
  event. Backed by a new `eventsStreamProvider` ([#51]).
- New/untouched holes now default to **1 putt** (was 2) — fewer taps for the
  common one-putt / regulation-hole entry ([#52]).
- Re-themed the app from the deep-purple seed to a **golf palette** — a
  fairway-green primary with flag-yellow and sky-blue accents, in both light and
  dark. Score-to-par colour bands (green / amber / red) are unchanged and still
  coordinate with the new surfaces ([#53]).

## [0.1.3] - 2026-07-18

This release tightens hole-entry data integrity and finishes the play-order form
redesign: the form now follows the sequence a hole is actually played, and two
more "impossible state" combinations are blocked at both the form and the
database — an up & down success needs one putt or fewer, and putts must be fewer
than the score — with a one-time schema-v4 migration cleaning any pre-existing
rows.

### Changed
- The hole-entry form now enforces two more "impossible state" rules for a hole,
  matching the existing DAO guards: an **up & down success requires one putt or
  fewer** (a 1-putt or a chip-in — the success toggle disables with an
  "N/A — 2+ putts" note, and raising putts past 1 clears it), and **putts must be
  fewer than the score** (the tee shot is never a putt — the putts and score
  steppers now cap each other). A schema **v4** data migration cleans rows saved
  before these rules existed: it clears any up & down success recorded with 2+
  putts and clamps putts down to `score - 1` where they met or exceeded it
  ([#37]).
- The hole-entry form now follows the order a hole is actually played — **Tee**
  (par, fairway hit) → **Approach & Around the Green** (GIR, up/down attempt,
  bunker visited) → **Putting** (putts) → **Score** (up/down success, sand save,
  penalty strokes, then score). Fields are grouped under stage headers and
  **Score is entered last**, once the hole is complete, rather than appearing
  second under Par ([#34]).

## [0.1.2] - 2026-07-02

A hotfix on v0.1.1: rounds are no longer immutable once created — a round's own
details can be edited after the fact.

### Added
- Edit an existing round's details: a new **Edit Round** dialog changes a
  round's event, course, date, round number and notes, pre-filled with the
  round's current values and reachable from both the rounds-list row and the
  scorecard. This is how a round created without an event gets one attached (and
  how a mis-entered course / date / round number is corrected) without deleting
  and re-creating the round — its holes are preserved. Backed by a new
  `RoundDao.updateById`; no schema change (the `rounds.event_id` foreign key has
  been nullable since v3) ([#45]).

### Changed
- The scorecard's **Edit** action is now labelled **Edit scores** (it resumes
  hole entry), distinguishing it from the new **Edit details** action that opens
  the Edit Round dialog ([#45]).

## [0.1.1] - 2026-06-21

The first feature release after v0.1.0: rounds can be organised into **events**
with recorded results, the score-distribution card gains percentage context, and
the historical spreadsheet was imported on-device via a one-time tool.

- Imported the historical `golf_stats.xlsx` data on-device via a one-time
  migration tool (built and then removed under [#33]); the shipping app is
  unchanged by it — no import UI and no migration code retained.

### Added
- Event tracking: a round can now belong to a named **event** (tournament,
  league, charity scramble, casual outing). Pick or create one from a typeahead
  in the New Round dialog; the Rounds list groups rounds under per-event headers
  (casual rounds fall under "No event"), and each event header shows — and lets
  you edit — a structured result (finishing position, a tie, or missed cut).
  Adds an `events` table and a nullable `rounds.event_id` foreign key
  (`SET NULL` on delete) at schema v3 ([#35]).
- Score-distribution card now shows each category's share of total holes as a
  prominent percentage above the raw count ([#39]).

## [0.1.0] - 2026-06-14

Phase 4 (release) — Golfy's first stable release. Pushing a `v*` tag now builds,
verifies, and publishes a **signed** Android APK via CI, completing the release
pipeline atop the migration-safe upgrades and retained keystore from v0.0.x.

### Added
- Tag-triggered release workflow (`.github/workflows/release.yml`): a `v*.*.*`
  tag builds a signed release APK, asserts it is release-signed (not debug) and
  under 80 MB, and attaches it to a **draft** GitHub Release to publish after
  on-device validation; `workflow_dispatch` runs the same build as an artifact
  dry-run ([#19]).
- Continuous integration via GitHub Actions: every push and pull request to
  `master` runs the test suite and builds a debug Android APK on Linux, plus a
  Windows desktop build, with the build outputs uploaded as workflow artifacts
  ([#18]).
- Drift schema-migration harness: a step-based `onUpgrade`, committed per-version
  schema snapshots under `app/drift_schemas/`, generated migration test helpers,
  and a `migration_test.dart` suite that validates each upgrade and that data
  survives it — plus a documented workflow for future schema changes ([#24]).
- Release signing configuration: `android/key.properties` drives a real release
  `signingConfig` (falling back to debug signing when absent), with a committed
  `key.properties.example` template and docs noting the keystore is
  upgrade-critical and must be retained ([#24]).

### Changed
- Debug / `flutter run` builds now install under their own
  `com.golfy.golfy_app.debug` application ID — with a `-debug` version suffix and
  a "(debug)" launcher label — so development data sandboxes to a separate
  app-private database and the debug build can coexist with a release install on
  one device. This also removes the `INSTALL_FAILED_UPDATE_INCOMPATIBLE` data
  loss when a signed release later replaces a `flutter run` build ([#23]).
- Bumped the drift `schemaVersion` to 2, adding an inert `rounds.migration_canary`
  column, to exercise the new migration pipeline end to end before the first real
  schema change ([#24]).

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

[Unreleased]: https://github.com/aellington89/golfy/compare/v0.1.4...HEAD
[0.1.4]: https://github.com/aellington89/golfy/compare/v0.1.3...v0.1.4
[0.1.3]: https://github.com/aellington89/golfy/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/aellington89/golfy/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/aellington89/golfy/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/aellington89/golfy/compare/v0.0.3...v0.1.0
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
[#19]: https://github.com/aellington89/golfy/issues/19
[#22]: https://github.com/aellington89/golfy/issues/22
[#23]: https://github.com/aellington89/golfy/issues/23
[#24]: https://github.com/aellington89/golfy/issues/24
[#33]: https://github.com/aellington89/golfy/issues/33
[#34]: https://github.com/aellington89/golfy/issues/34
[#35]: https://github.com/aellington89/golfy/issues/35
[#36]: https://github.com/aellington89/golfy/issues/36
[#37]: https://github.com/aellington89/golfy/issues/37
[#39]: https://github.com/aellington89/golfy/issues/39
[#45]: https://github.com/aellington89/golfy/issues/45
[#51]: https://github.com/aellington89/golfy/issues/51
[#52]: https://github.com/aellington89/golfy/issues/52
[#53]: https://github.com/aellington89/golfy/issues/53
[#42]: https://github.com/aellington89/golfy/issues/42
[#55]: https://github.com/aellington89/golfy/issues/55
[#47]: https://github.com/aellington89/golfy/issues/47
[#56]: https://github.com/aellington89/golfy/issues/56
