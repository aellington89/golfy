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

## Status — v0.8.0

**v0.8.0** is the latest release, and it lets a backup back onto a device.
**Settings → Restore from a backup** picks a backup file, shows what it holds
next to what the device holds now, and on your say-so puts its courses, tee and
pin sets, rounds, holes, shots and events in place of the device's own — with a
**Back up first** button when there is anything to lose. A damaged, edited or
newer-than-the-app file is refused before anything changes, and every backup
Golfy has written restores, from v0.4.0 on. The schema stays at v9.

**v0.7.1** fixed the course editor opening on the wrong sets: it now starts on
the tee set and pin set of the round you last played on that course, so yards
saved by "Update course as I play" show up where you expect them. The New Round
dialog also asks for a tee set when you pick a pin set without one.

**v0.7.0** split a course's yardage into **tee
sets** and **pin sets**. A tee set has its **course yards**, the scorecard
number for each hole, which the pins never change. A pin set has
**tee-to-pin** yards for each tee set, because the same pins are a different
distance from each tee. A round records both, and each hole pre-fills with that
pair's tee-to-pin yards, or with the tee set's course yards when the round has
no pin set. Old yardage sets, named "Tee Set - Pin Set", became that tee set
and pin set on upgrade, and their yards became tee-to-pin yards. The schema
moved to v9, and backups made by v0.4.0 to v0.6.0 still read.

**v0.6.0** gave each putt a shot row of its own under **Putting**, with its
distance to the hole in feet — the unit golf games show on the green. Adding or
removing a putt row is how the putts are counted. Putts measured in yards were
converted to feet on upgrade; every other shot kept its yards. The schema moved
to v8.

**v0.5.0** reworked the hole entry card. Each shot was entered beside the stats
it decides — the tee shot with "Fairway hit?", approach shots with GIR, bunker
and up & down, putts as a Putts count — so a hole is one pass down the card,
and the form fills in what follows from what you enter. **Save Hole** checks
that the hole adds up before saving it, and offers a one-tap fix when the score
and the shots disagree. The schema stayed at v7.

**v0.4.0** was the first release since v0.3.1 worth installing
for its own sake: your data could now leave the device. **Settings → Back up your
data** writes every course, round, hole and shot to one plain JSON file and
hands it to the share sheet (Android) or a Save-as dialog (Windows). You choose
where it goes, and nothing is uploaded. Restoring from a backup came with
v0.8.0 ([#70](https://github.com/aellington89/golfy/issues/70)), reading the
format fixed then and documented in [`BACKUP_FORMAT.md`](BACKUP_FORMAT.md).
The schema stayed at v7.

**v0.3.3**, like v0.3.2 before it, changed nothing about the app: the same
screens, the same data, the same schema at v7. What it carried was the
toolchain. The pinned Flutter SDK moved 3.44.0 → 3.47.6, which
is what unwedged a `flutter pub get` that had stopped resolving at all, and the
first full batch of dependency updates — eight pull requests — came up from
the `deps/patch` branch with it.

**v0.3.2** put the release machinery itself on a tag: dependency updates that
collect on their own branch under CI, and a procedure that derives the next
version number from what actually merged instead of leaving it to be typed into
four files. See [`RELEASING.md`](RELEASING.md).

**v0.3.1** is the release worth having: a bug fix that makes per-shot entry
survive a second save. Saving a hole again — the normal way a hole is entered,
a shot at a time as you play it — attached its shot list to the wrong row, so
the edit was discarded and could overwrite another hole's shots; the blank shot
row the form leaves you to fill in was deleted on save as well. A par 3 whose
tee shot misses the green hit both at once. It needs no schema change and no
re-entry of existing rounds.

Both build on **v0.3.0**, where per-hole data entry stopped being two different
apps: setting a course up uses the round form's own controls and progress
signals, lives on one screen instead of three, and can be corrected from inside
a round — while shots arrive pre-filled from what the hole card already knows:

| Feature | Issue | What it delivered |
|---|---|---|
| One course editor | [#81](https://github.com/aellington89/golfy/issues/81) | Par, stroke index and the selected yardage set's yardage on one card per hole, using the round form's segmented par control, chip strip and "Holes set: X / 18" counter — replacing a par/stroke-index screen plus a separate screen per tee box. Per-hole Saved / Unsaved feedback, one transactional save, and a standard par-72 starting layout you accept rather than inherit |
| Course edits while you play | [#81](https://github.com/aellington89/golfy/issues/81) | "Update course as I play" keeps the template in step with each hole saved and arms itself on a course with no card; a sheet edits one hole's course data mid-round; stroke index is enterable straight from the hole entry form. Yardage sets can be created while starting a round, copied from an existing set with an offset, and which set a round used is visible on the rounds list and the yards field |
| Smarter shot entry | [#81](https://github.com/aellington89/golfy/issues/81) | Shots pre-fill from the hole's own data — tee lie, chained lies from the fairway flag, putts once the implied full swings run out, remaining distance stepped down per club — with a one-tap "Build from score" and non-blocking notes when shots disagree with the scoring fields. Every suggestion is overrideable and shots stay optional |

v0.3.0 needed **no schema change** either — the data model carried it unaltered
at v7.

Before that, **v0.2.0** was Golfy's largest release to that point, completing
the **Courses & yardage** milestone and giving **Events** a home of their own:

| Feature | Issue | What it delivered |
|---|---|---|
| Course templates & yardage sets | [#36](https://github.com/aellington89/golfy/issues/36) | A course saves a shared per-hole par + stroke-index card plus any number of named yardage sets (tee boxes / pin sets); starting a round picks a set and pre-fills each hole's par and yardage, still editable per round. A new Courses screen (nav drawer) manages templates and sets, and renames or deletes a course |
| Per-shot tracking | [#22](https://github.com/aellington89/golfy/issues/22) | Each hole captures an ordered shot list — club, distance, lie and result per shot — replacing the old flat tee-club / drive / approach fields, and independent of scoring |
| Dedicated Events tab | [#42](https://github.com/aellington89/golfy/issues/42) | Events graduate from a field on a round to their own tab with event-first navigation: create an event up front, open it for its rounds and a per-event scoring summary, and edit or delete it |
| Events per season | [#47](https://github.com/aellington89/golfy/issues/47) | The same event name recurs each season as its own occurrence — its own result, rounds and edits — with the season a typed, editable field |
| Event tile scoring | [#63](https://github.com/aellington89/golfy/issues/63) | The Events list tiles carry a compact scoring line — average score vs. par and best round to-par — beside the round count |

v0.2.0 shipped schema versions **v5–v7**, each a migration-tested,
data-preserving upgrade.

Before that, **v0.1.4** re-themed the app to a green / yellow / blue golf
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
— course yards per tee set, and tee-to-pin yards per tee set and pin set
([#36](https://github.com/aellington89/golfy/issues/36)),
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
- **share_plus / file_selector** — the system share sheet (Android) and save
  dialog (Windows) a data backup is handed to; **package_info_plus** for the
  installed version

The database is a single SQLite file, `golfy.sqlite`, kept in the app's private
documents directory — nothing is ever sent over the network. On Android each
build variant sandboxes to its own database under its application ID: the
release build at `…/com.golfy.golfy_app/…` and the debug build at
`…/com.golfy.golfy_app.debug/…`, so development data never mixes with a real
install ([#23](https://github.com/aellington89/golfy/issues/23)). On Windows both
build modes share `%USERPROFILE%\Documents\golfy.sqlite`.

## Data model

```
courses ──┬── course_holes (18 per course)  → par + stroke index, per hole
          ├── tee_sets ──── course_yards (18 per tee set)
          ├── pin_sets       └─ the scorecard yards; vary with the tee set only
          ├── tee_to_pin_yards (18 per tee set × pin set)
          │     └─ distance from a tee set to a pin set's pin; vary with both
          ▼
        rounds ──── hole_results (18 per round) ── hole_shots (per-shot list)
          │         └─ par, score, yards, fairwayHit,    └─ club, distance
          └─ tee_set_id + gir, putts, upDown…,            (yds, or ft for a
             pin_set_id    penalty, bunker, sandSave, …     putt), lie, result
             (yardage set)
```

A course optionally saves a **template**. **Par and stroke index** belong to the
hole whatever it is played from (`course_holes`). A **tee set** (`tee_sets`) is
a tee box with a standard yardage per hole — its **course yards**
(`course_yards`), which change with the tee set and never with where the pin is.
A **pin set** (`pin_sets`) is a set of pin positions with no yardage of its own:
how far a hole plays depends on the tee set and the pin set together, so
**tee-to-pin** yards (`tee_to_pin_yards`) are kept per tee set × pin set — the
same pins are a different distance from each tee set. A **yardage set** is one
tee set plus one pin set, and its yards on a hole are that pair's tee-to-pin
yards.

A round records its yardage set (`rounds.tee_set_id`, `rounds.pin_set_id`, both
optional and both on the round's own course). Starting a round pre-fills each
hole's par from the course and its yards from the yardage set — tee to pin, or
the tee set's course yards when the round has no pin set — and the round keeps
its own editable copy in `hole_results`, so a template edit never rewrites past
rounds. Each hole optionally carries an ordered **shot list** (`hole_shots`) —
club, distance (yards to the pin, or feet to the hole for a putt), lie and
result per shot — separate from the authoritative `score` / `putts`.
Round totals and lifetime aggregates are **derived** from `hole_results` at
query time. The schema is enforced at the SQL level (FK RESTRICT on course
delete, FK CASCADE on round / set / hole delete, FK SET NULL from a round to
its tee set and pin set, UNIQUE on `(round_id, hole_number)`, `(course_id,
hole_number)`, `(course_id, name)` per set kind, `(tee_set_id, hole_number)`,
`(tee_set_id, pin_set_id, hole_number)`, `(hole_result_id, shot_number)`, CHECK
constraints on par / score / putts / yards). App-level invariants that SQL can't
express (e.g. you can't make an up-and-down without attempting one, or pair a
tee set with another course's pin set) are enforced by the DAO layer with loud
`ArgumentError`s.

## Back up and restore your data

Golfy keeps everything on the device and sends nothing anywhere, which also
means a lost or wiped phone loses every round. **Export** writes the lot —
courses, tee sets, pin sets and their yards, rounds, holes, shots and events —
to one file you choose the home for
([#69](https://github.com/aellington89/golfy/issues/69)), and **Restore** puts
that file back onto a device
([#70](https://github.com/aellington89/golfy/issues/70)).

### Back up

1. Open the side menu → **Settings**.
2. Check the line under **Back up your data**: it says how many rounds, courses
   and events are about to be saved.
3. Tap it. Android shows your usual share sheet; Windows opens a Save-as box.
4. Pick somewhere **off the phone** — Google Drive, OneDrive, or email it to
   yourself. Saving to the phone's own Files app protects you from a mistaken
   delete, but not from a lost phone.
5. The bar at the bottom names the file it made, e.g.
   `golfy-backup-20261003-1432.json`.
6. Open it once, out of curiosity. It is plain text: at the top you can see
   when it was made and how many of each thing it holds. That is how you know
   it worked.

**How often?** After any session you would not want to re-enter. **Does it go
anywhere by itself?** No — nothing leaves the device unless you send it, and no
backup is ever made without you asking.

### Restore

1. Make sure the device can reach the file: on Android, in Drive, in Files, or
   as a downloaded attachment; on Windows, in any folder.
2. Open the side menu → **Settings** → **Restore from a backup**.
3. Pick the file. Golfy reads and checks all of it before anything happens; a
   file it cannot restore is refused with the reason, and nothing changes.
4. Read the question. It shows what the backup holds — when it was made, by
   which version of Golfy, and how many rounds, courses, events, holes and
   shots — beside what this device holds now.
5. Tap **Replace** (or **Restore**, on a device with nothing on it yet).
6. The bar at the bottom says what was restored. Every tab shows the restored
   data straight away.

**Does it merge with what is already here?** No — restoring **replaces**
everything on the device with what the file holds. If the device has rounds
you want to keep, tap **Back up first** in the question; it saves them with the
ordinary export, and you can restore again afterwards. **What if I pick the
wrong file?** Nothing happens until you tap Replace, and the question shows
what is in the file, so read it first. **What if it fails partway?** The
restore is all or nothing: the device is left exactly as it was. **Which files
restore?** Any backup Golfy has made, from v0.4.0 on. A file made by a *newer*
Golfy is refused — update Golfy first. **Was I in the middle of a round?** A
restore closes the round open in Hole Entry; open it again from Rounds.

The format is documented in [`BACKUP_FORMAT.md`](BACKUP_FORMAT.md), the
contract both Export and Restore keep.

## Build & run

All Flutter commands run from `app/`. See [`app/README.md`](app/README.md) for
the full developer workflow. Quick start:

```powershell
cd app
flutter pub get
dart run build_runner build            # regenerate drift / DAO mixins
flutter test                           # 885 passing tests
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
> [Continuous integration](app/README.md#continuous-integration). The version
> on that tag is **derived from what merged**, not picked by hand, and CI
> rejects a tag that disagrees with the repo — see
> [`RELEASING.md`](RELEASING.md).

## Repository layout

```
golfy/
├── app/                 # Flutter app (Dart + drift)
│   ├── lib/
│   │   ├── data/        # drift tables, DAOs, repository, providers, models,
│   │   │                #   backup/ (the portable export format)
│   │   ├── features/    # rounds / hole_entry / dashboard screens
│   │   ├── shell/       # AppShell + bottom-nav state
│   │   ├── app.dart     # MaterialApp root
│   │   └── main.dart    # entry point
│   ├── branding/        # launcher icon + splash source art (SVG); the Android
│   │                    #   and Windows icon resources are generated from it
│   ├── tool/            # release version calculator (no app code)
│   └── test/            # widget + DAO + schema-constraint tests
├── .github/
│   ├── workflows/       # CI build+test, and the tag-driven signed release
│   └── dependabot.yml   # dependency PRs, based on the deps/patch branch
├── .gitattributes       # LF-pin generated Windows plugin glue
├── .gitignore
├── CHANGELOG.md         # Keep a Changelog; the input to the next version
├── RELEASING.md         # how a release is cut and its version derived
├── BACKUP_FORMAT.md     # the backup file format — a contract, read before changing
├── docs/plans/          # design notes written before a non-trivial feature
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
