# Implementation plan — #69 Export all Golfy data to a portable backup file

> Status: **implemented** on `ccr-0dbe29db-wnq84q`. Written and built
> 2026-10-03 against `master` @ `72d22ae` (v0.3.2, drift `schemaVersion` 7,
> 585 tests → **685**). What was built differs from the plan below in a few
> places, all of them additions; §15 records them, and the plan text is left as
> written so the reasoning stays legible.
> Issue: [#69](https://github.com/aellington89/golfy/issues/69) ·
> Pairs with [#70](https://github.com/aellington89/golfy/issues/70) (import /
> restore) and [#72](https://github.com/aellington89/golfy/issues/72)
> (Settings / About).
>
> **The file is designed as a two-way contract, not an export artifact.** It
> exists to be read back in. So #69 ships the format *and* both halves of the
> code that handles it — writing a file, reading one, and checking that a file
> is safe to act on — proven by tests against committed sample files. #70 then
> implements putting a decoded file back into the database, and the user
> interface around it. §4.1 states exactly what #70 inherits.

---

## 1. Decisions in plain language

Eight calls worth making consciously. Each has a recommendation; none of them
is reversible for free once a user has a backup file on their phone, because
whatever format ships has to stay readable forever.

| # | Decision | Recommendation | Why it matters |
|---|---|---|---|
| 1 | **What the backup file looks like** — a readable text file, or a straight copy of the app's database file | **Readable text file (JSON)** | A text file can be opened, inspected and checked by eye, survives changes to how the app stores things, and leaves the door open to a future "merge my old rounds in" option. A database copy is less work today but is an opaque blob: if it is subtly broken nobody finds out until a restore fails. **It also makes restoring far safer:** the app can read and check the whole file *before* it touches your data, then put it back in a single all-or-nothing step, with the screens refreshing by themselves. Swapping in a copied database file instead means closing the live database, overwriting it, and reopening — a step that can fail halfway and, on Windows, can be blocked outright by file locking. |
| 2 | **Where the file goes** | **The user chooses, every time** — Android hands it to the normal share sheet (Drive, Files, email to yourself), Windows opens a Save-as dialog | Nothing leaves the device unless the user sends it somewhere. No storage permission is needed, which also keeps the Play Store privacy declarations ([#77](https://github.com/aellington89/golfy/issues/77)) simple and honest. |
| 3 | **Where the Export button lives** | **A new Settings screen**, reached from the existing side menu, containing only a "Data" section for now | [#72](https://github.com/aellington89/golfy/issues/72) already plans Settings as the home for Export, version, licences and support. Building the shell here means no throwaway UI, and #72 just adds its rows later. |
| 4 | **Ship Export on its own, or wait for Import** | **Build and merge Export now; cut the release when Import ([#70](https://github.com/aellington89/golfy/issues/70)) lands** | A backup file is insurance the moment it exists, so there is no reason to delay the work. But "you can save a file you cannot yet put back" is an awkward thing to put in release notes, and the two issues were always one milestone. If Import slips badly, Export can still ship alone with wording that is clear about it. |
| 5 | **Which release this becomes** | **v0.4.0** (the issue still says v0.3.0, which shipped the course editor instead) | The project derives version numbers from what merged, not from plans. A new user-facing feature is a MINOR bump from today's 0.3.2. Nothing to argue about — the tooling prints it. |
| 6 | **Restoring an older backup** | **Make it impossible to have one.** Export does not exist before today's data format, so no older file can ever exist. Import only has to handle "same as me" and refuse "newer than me" | This removes the single most expensive requirement in the pair of issues (upgrading an old backup during restore) without losing anything. The groundwork for a future upgrade path still ships, and a test fails the build the day the data format next changes, so it cannot be forgotten. |
| 7 | **How much goes in the file** | **Everything, including two retired columns nobody uses** | A backup that silently drops a field is worse than no backup. Exporting straight from the database's own definition of itself — rather than a hand-written list of fields — means a future new field is included automatically, and a test fails if one is ever missed. |
| 8 | **Three new third-party components** (share sheet, Windows save dialog, app-version reader) | **Accept them** | All three are standard, widely used Flutter packages from the Flutter team or its community, they satisfy the project's current Android build requirements, and the first two are the only sane way to let a user pick where a file goes. |
| 9 | **Who proves the file can be read back in** | **This issue does.** #69 ships the reading and checking code with the writing code; #70 adds only "put these rows in the database" and the screens around it | A format is only a promise until something reads it. Shipping the reader alongside the writer means the day Export merges, there is proof — in the test suite, against committed sample files — that a backup can be understood and validated. The alternative is discovering the format is unusable weeks later, after real users already hold files in it. It also leaves #70 the part that genuinely needs care (replacing live data safely) rather than that *plus* reverse-engineering last month's decisions. |

Two things deliberately **not** decided here: whether restore replaces or merges
data (that is #70's call, and this format supports either), and whether backups
can ever be automatic or scheduled (out of scope — Golfy has no background work
and no network).

---

## 2. What the issue asks for, and what has changed since it was written

The issue is sound, with two pieces of stale context:

- **Target release.** It says v0.3.0. v0.3.0 shipped the course editor instead;
  the project is at **v0.3.2**, so this lands in **v0.4.0+38** — confirmed by
  `dart run tool/next_version.dart` at implementation time, which derives it
  from the `### Added` entry this work adds to `CHANGELOG.md`.
  ([`RELEASING.md`](../../RELEASING.md) is explicit that versions are derived,
  and even uses this very issue as its example of a plan that moved.)
- **Where it is surfaced.** "Settings/About screen — see the settings issue"
  (#72) is targeted at v0.4.0 and lists Export as one of *its* acceptance
  criteria, so the two issues each wait on the other. Decision 3 above breaks
  the deadlock: this work builds the Settings screen shell.

Everything else in the issue holds, including the right instinct in its closing
note — the format decision is the one that matters most.

---

## 3. Codebase review — what the design has to work with

| Fact | Where | Consequence for this work |
|---|---|---|
| Eight tables at schema v7: `courses`, `course_holes`, `course_sets`, `course_set_yards`, `events`, `rounds`, `hole_results`, `hole_shots` | [`app/lib/data/tables/`](../../app/lib/data/tables) | Matches the issue's list exactly. Export must cover all eight and prove it. |
| drift generates `toJson()` / `fromJson()` on every row class, and nothing in `lib/` currently uses them | `app/lib/data/database.g.dart` | Serialization is essentially free and field-complete. A drift build option can make the keys the real SQL column names. |
| `allTables` is exposed on the generated database | `database.g.dart:3781` | A test can assert the exporter covers every table the schema knows about — the guard that makes decision 7 enforceable. |
| All writes go through `GolfyRepository`; "no SQL leaks past `data/`" | [`app/lib/data/repository.dart`](../../app/lib/data/repository.dart), `app/README.md` | Export belongs behind a repository method plus a service, not called from the UI. |
| Cross-table work already uses one transaction (`replaceCourseCard`, `saveHole`) | `repository.dart` | Export reads inside one transaction too, so a save mid-export cannot tear the file. |
| `rounds` carries two dead columns — `tee_set` (legacy) and `migration_canary` (a v2 migration canary) | `app/lib/data/tables/rounds.dart` | Export them anyway. A restore has to reproduce the row as it was; filtering "columns we think matter" is how a backup quietly loses data. |
| Foreign keys are enforced (`PRAGMA foreign_keys = ON` in `beforeOpen`), with CASCADE / RESTRICT / SET NULL rules | `app/lib/data/database.dart` | The file must list tables parents-first so a future importer can insert in file order. |
| Ids are `INTEGER PRIMARY KEY AUTOINCREMENT` | tables | Row ids go in the file. Restoring them verbatim preserves every relationship and resets SQLite's own counter automatically, so later rounds cannot collide. |
| Migrations are step-based and schema snapshots are committed per version | `database.dart`, `app/drift_schemas/` | No schema change here (stays at v7) — so no new snapshot, and the release tag guard's schema checks stay satisfied. |
| Widget tests pump a screen against an in-memory database with Riverpod overrides, and deliberately do not drive live streams | `app/test/features/**`, `app/README.md` | The Export action must be testable with a fake file destination — no plugin may be called in a test. |
| No plugins with native code are in the project yet; Windows plugin glue is LF-pinned in `.gitattributes` | `app/windows/flutter/`, `.gitattributes` | The three new packages will regenerate that glue; it must be committed, and `flutter build windows --debug` has to be run locally once. |
| Android: AGP 9.0.1, Kotlin 2.3.20, Gradle 9.1.0, Flutter pinned to 3.44.0 in CI | `app/android/settings.gradle.kts`, `.github/workflows/` | Comfortably above what the new packages require (AGP ≥ 8.12.1, Kotlin 2.2.0, Flutter ≥ 3.38.1). |

**One verified constraint drove decision 2.** Flutter's own `file_selector`
package cannot ask Android where to save a file — "choose a save location" is
supported on Windows, macOS and Linux only, because Android hands back a
`content://` URI that Dart's `File` cannot write to
([flutter/flutter#113441](https://github.com/flutter/flutter/issues/113441),
[#168318](https://github.com/flutter/flutter/issues/168318)). So the two
platforms need two different write paths, behind one interface:

- **Android** — write to the app's own cache directory, then hand the file to
  the system **share sheet** (`share_plus`). The user sends it to Drive, Files,
  Gmail, wherever. No permission, no storage access framework plumbing.
- **Windows** — `file_selector`'s save dialog, then write the file directly.
  (`share_plus` on Windows only supports sharing text by email, so it is not an
  option there.)

---

## 4. The backup format, v1

One file. UTF-8 JSON, pretty-printed with two-space indent, named
`golfy-backup-<YYYYMMDD>-<HHmm>.json` using the device's local time (the
manifest carries UTC). Plain `.json` rather than a custom extension, so share
targets, mail clients and text editors all handle it without special-casing.

> A distinctive extension (`.golfybak`, or `.golfy.json`) was considered, on
> the theory that it would let Android offer "Open with Golfy" on a backup file.
> Rejected: an Android intent filter matches reliably on MIME type, not on a
> file-name pattern, and a file arriving from Drive or Files comes through as an
> opaque `content://` URI whose name the system may not expose at all — so the
> association would be unreliable whatever the extension, while claiming
> `application/json` outright would claim *every* JSON file on the device.
> Restoring happens through Golfy's own file picker instead, which does not care
> about the extension. The `golfy-backup-` prefix is what makes the file
> recognisable, and `.json` is what keeps it openable everywhere.

```json
{
  "golfyBackup": {
    "formatVersion": 1,
    "schemaVersion": 7,
    "appVersion": "0.4.0+38",
    "exportedAt": "2026-10-03T14:32:07Z",
    "platform": "android",
    "rowCounts": {
      "courses": 3, "course_holes": 54, "course_sets": 5,
      "course_set_yards": 90, "events": 4, "rounds": 42,
      "hole_results": 756, "hole_shots": 2814
    }
  },
  "data": {
    "courses": [{ "id": 1, "name": "Pebble Beach", "game_title": "PGA Tour 2K25" }],
    "course_holes": [],
    "course_sets": [],
    "course_set_yards": [],
    "events": [],
    "rounds": [],
    "hole_results": [],
    "hole_shots": []
  }
}
```

Rules, all of them testable:

1. **Two version numbers, not one.** `formatVersion` describes the envelope
   (starts at 1, changes only if the container shape changes).
   `schemaVersion` is the drift schema the rows match — 7 today. The issue
   asked for the schema version to travel with the data; the envelope version
   is what lets the container itself evolve.
2. **Table keys are SQL table names; row keys are SQL column names.** Set
   drift's `use_sql_column_name_as_json_key: true` in a new `app/build.yaml`,
   so generated `toJson()` emits `game_title`, not `gameTitle`. The file then
   reads identically to `app/drift_schemas/drift_schema_v7.json`, which is the
   schema's own committed description of itself.
3. **Every column of every table, explicitly.** Nulls are written as `null`
   rather than omitted, so a missing key means a malformed file, not a default.
   Legacy columns included (decision 7).
4. **Tables in dependency order**, parents first:
   `courses → course_holes → course_sets → course_set_yards → events → rounds
   → hole_results → hole_shots`. Rows within a table ordered by `id` ascending,
   so two exports of the same data are byte-identical and diffable. The order
   is a courtesy to the reader and to a future streaming importer; **an importer
   must not depend on it** — it uses its own compile-time ordering, so a file
   written by hand or by another tool still restores correctly.
5. **Booleans are `true` / `false`**, not 0 / 1 (drift's serializer already
   does this) — it is a file people are meant to be able to read.
6. **`rowCounts` is the integrity check.** On import, counts are compared
   against what was actually parsed. A truncated file fails JSON parsing; a
   doctored or half-written one fails the count check. That is enough without
   adding a checksum library — stated here so #70 does not have to re-decide it.
7. **No device identifiers.** `platform` is `"android"` or `"windows"`, and
   that is the whole of it. Everything else in the file is golf data the user
   typed in themselves.
8. **Version compatibility on read** (implemented by #70, specified here):
   equal `schemaVersion` → apply; **greater** → refuse with "this backup came
   from a newer version of Golfy"; **lower** → run the registered payload
   upgraders. That list is empty today and, per decision 6, can never be
   exercised by a real file, because no Golfy build before this one can export.
   The day `schemaVersion` becomes 8, a guard test fails until an upgrader and a
   golden file for v7 are added.
9. **Row ids are part of the data.** Every row carries its `id`, and a restore
   writes it back unchanged — that is what preserves which hole belongs to which
   round, which round to which course and set, and which shot to which hole.
   SQLite's own autoincrement counter re-derives itself from the highest id
   inserted, so rounds recorded after a restore cannot collide with restored
   ones. Nothing about the counter needs to be in the file.
10. **The file is checkable before it is acted on.** Decoding is *total*: it
    either returns a complete, typed payload or throws, naming the table and row
    index that defeated it — it never returns something half-understood. On top
    of that, `BackupPayload.validate()` is a pure cross-table check that every
    foreign key in the file points at a row that is also in the file, that no
    unique key is duplicated (`(course_id, hole_number)`, `(round_id,
    hole_number)`, `(name, season)` and the rest), and that hole numbers are
    1–18. A restore runs both **before** it touches the database, so a bad file
    is refused with a readable reason instead of failing halfway through a
    SQLite constraint error.

Size: a year of serious play (roughly 100 rounds, 1 800 holes, ~7 000 shots) is
well under 5 MB pretty-printed. Not worth compressing, and compression would
cost the inspectability that justified JSON in the first place.

### 4.1 The import contract — what #70 inherits

**Finished and tested by #69**, so that #70 starts from a format that is already
known to be readable:

- **`BackupCodec.decode(String)`** → a typed bundle (manifest + payload), or a
  `BackupFormatException` that names the table and row index that defeated it.
- **`BackupPayload.validate()`** → the pure cross-table check of rule 10:
  foreign keys resolvable within the file, unique keys not duplicated, hole
  numbers in range. Returns a readable list of problems, writes nothing.
- **Version gatekeeping** — rule 8's accept / refuse / upgrade decision, with
  the upgrader registry in place and empty, and the guard test that fails the
  day `schemaVersion` moves.
- **Two committed sample files**: `golden/backup_v1_minimal.json` (a handful of
  rows, pinning the format byte for byte) and `golden/backup_v1_full.json` (the
  whole seeded multi-round fixture, with every awkward case in it). #70's
  restore tests read the second rather than inventing their own input, so export
  and import are tested against *the same bytes*.
- **A home for the write side** — `BackupDao` already spans all eight tables
  transactionally, so #70 adds one method (`replaceAll(BackupPayload)`) rather
  than a new access layer.

**Still #70's to own**, stated here only so the format can be judged against
what it has to support:

1. Pick a file. `file_selector`'s *open* dialog works on Android as well as
   Windows (it is only *save* that Android lacks), so import needs **no new
   dependency** — it reuses what this issue already adds.
2. Decode and validate. Refuse with the reason, having touched nothing.
3. Show the user what the file holds (row counts, when it was made, which app
   version made it) *and* what they currently have, then require an explicit
   confirmation — replacing is destructive and must look it.
4. Apply in **one transaction**: delete children → parents, insert parents →
   children with the ids from the file. If anything fails, the transaction rolls
   back and the device is exactly as it was. That, rather than a backup-of-the-
   backup, is the answer to "what if restore dies halfway".
5. Insert through the tables directly, not through the DAOs. The DAO-layer
   invariants (`upDownSuccess` requires an attempt, `putts < score`, and so on)
   exist to stop bad *user input*; a restore replays rows that already passed
   them, and the SQL-level CHECK constraints still police a hand-edited file.
6. Nothing else. The database stays the same file, foreign keys stay on, and
   drift's watchers fire on commit — every screen refreshes by itself, with no
   app restart and no file swap.
7. Report what was restored, in the same counts the export tile shows.

Two consequences of the format worth noting for that work: because restore
*replaces*, there is no id remapping and no conflict resolution to design — the
ids in the file become the ids on the device. And if merge is ever wanted, this
format supports it, because every row carries its natural key as well as its id
(course name + game title, round date + course + number, event name + season,
hole number within a round); nothing here commits to building it.

---

## 5. Architecture

```
app/lib/data/backup/
├── backup_manifest.dart      # envelope model + validation (pure)
├── backup_payload.dart       # typed row lists for all 8 tables (pure)
├── backup_codec.dart         # payload <-> JSON text, typed failures (pure)
├── backup_destination.dart   # where a file goes: interface + 2 impls + provider
└── backup_service.dart       # orchestration + result type + provider

app/lib/data/daos/backup_dao.dart    # reads all 8 tables in one transaction
app/lib/features/settings/
├── settings_screen.dart      # drawer destination; "Data" section only for now
└── export_backup_action.dart # tile + confirm/progress/snackbar logic
```

Flow:

```
SettingsScreen ──▶ backupServiceProvider.createBackup()
                      │
                      ├─ repository.readBackupPayload()      one transaction,
                      │    └─ BackupDao.readAll()            ordered by id
                      ├─ BackupManifest.create(...)          package_info_plus
                      ├─ BackupCodec.encode(manifest, payload) → String
                      └─ BackupDestination.save(fileName, contents)
                            ├─ ShareSheetDestination   (Android: cache + share_plus)
                            └─ SaveDialogDestination   (Windows: file_selector)
```

Design notes:

- **The codec and the payload are pure Dart** — no database, no file system, no
  plugins. That is where the detailed tests live, and they run in milliseconds.
  **Both directions ship here** (decision 9): `encode`, `decode` and
  `validate`, so the file is provably readable before anyone holds one. Only
  the database write-back and its UI wait for #70.
- **`BackupPayload` holds typed drift row objects** (`List<Course>`,
  `List<HoleResult>`, …) rather than loose maps, so adding a table is a compile
  error rather than a silent omission, and drift's value equality gives
  round-trip tests a one-line assertion. It also exposes
  `Map<String, List<DataClass>> get tables`, keyed by SQL table name, for the
  coverage guard test.
- **`BackupDestination` is the seam that keeps plugins out of tests.** One
  abstract method, `Future<BackupSaveOutcome> save(String fileName, String
  contents)`, returning `saved` / `shared` / `cancelled` / `failed(reason)`.
  Tests inject a recording fake through `backupDestinationProvider`.
- **`BackupService` returns a result, never throws at the UI.** The screen maps
  the outcome to a snackbar; unexpected errors are caught and reported as
  `failed`, because "export silently did nothing" is the worst failure mode a
  backup feature can have.
- **Temp-file hygiene** (Android): the cache copy is deleted once the share
  sheet returns, and the service sweeps any stale `golfy-backup-*.json` left in
  the cache directory by an interrupted earlier attempt.
- **Why a new DAO rather than a method on an existing one**: the read spans all
  eight tables, so it belongs to none of them; a `@DriftAccessor` over all
  eight keeps it typed and transactional, and gives #70 the obvious home for
  the write-side counterpart (`replaceAll`).
- **Import needs nothing new from the toolbox.** `file_selector` is being added
  here for the Windows save dialog, and its *open* dialog is supported on
  Android too — so #70's file picker is already paid for, on both platforms.

### UI

`SettingsScreen` — a drawer destination beside Courses, titled **Settings**.
One section, **Data**, containing:

- a short explanation: *"Golfy keeps everything on this device. A backup is a
  single file, and you choose where it goes — nothing is uploaded."*
- a tile, **Back up your data**, subtitled with live counts
  (*"42 rounds · 3 courses · 4 events"*) so the user can see what they are
  about to save and whether it looks right;
- on tap: progress indicator → the share sheet or save dialog → a snackbar
  naming the file (`Backup created · golfy-backup-20261003-1432.json`), or a
  failure snackbar with **Retry**.

An empty database still exports a valid file (zero counts), with the subtitle
reading *"Nothing recorded yet"* — refusing to export would be a surprise, and
an empty backup is still a legitimate "this is where I started" file.

---

## 6. Build plan

**Dependencies** (`cd app && flutter pub add …`):

| Package | Version today | Why | Platforms used |
|---|---|---|---|
| `share_plus` | 13.3.1 | Android share sheet | Android |
| `file_selector` | 1.1.0 | Windows save dialog | Windows |
| `package_info_plus` | 10.2.2 | real installed version for the manifest; #72 needs it too | both |

All three clear the project's Android toolchain requirements (AGP ≥ 8.12.1 vs
9.0.1, Kotlin 2.2.0 vs 2.3.20, Gradle ≥ 8.13 vs 9.1.0, Flutter ≥ 3.38.1 vs
3.44.0). No Android manifest change and no runtime permission: `share_plus`
ships its own file provider, and nothing writes outside app-private storage.

**Code generation.** New `app/build.yaml` enabling
`use_sql_column_name_as_json_key: true`, then
`dart run build_runner build`. This regenerates `database.g.dart` (JSON keys
become SQL column names — safe, nothing in `lib/` uses `toJson` today) and adds
`backup_dao.g.dart`. Both are committed, as the project already does for
generated files.

**Platform glue.** `flutter pub get` will rewrite
`app/windows/flutter/generated_plugins.cmake` and
`generated_plugin_registrant.{cc,h}` to register the new plugins. These are
committed and LF-pinned; run `flutter build windows --debug` once locally to
prove the CMake side links.

**No schema change.** `schemaVersion` stays 7, no new `drift_schemas/`
snapshot, no migration step, no change to `migration_test.dart`.

**Version and release.** The feature branch adds only a `### Added` entry under
`## [Unreleased]` in `CHANGELOG.md`. The version bump itself belongs to the
separate `release/vX.Y.Z` cut described in `RELEASING.md` (promote the section,
update link references, bump `app/pubspec.yaml`, refresh both READMEs' status
and test counts, tag). Expected outcome: **0.4.0+38**.

**CI.** No workflow change. The existing Linux job (`flutter analyze`, full
`flutter test`, debug APK) and Windows build job cover this; the new plugins add
a few hundred KB, nowhere near the 80 MB APK ceiling the release workflow
asserts.

> Note: this container has no Flutter/Dart toolchain, so none of the commands
> above were executed while writing this plan. First implementation step is to
> run the existing suite green on a machine that has Flutter 3.44.0.

---

## 7. Implementation sequence

Seven commits on `ccr-0dbe29db-wnq84q`, each independently reviewable and
green. Roughly top-to-bottom dependency order, so review can start before the
UI exists.

1. **`build.yaml` + regenerate.** Add the drift JSON-key option, re-run
   `build_runner`, commit the regenerated `database.g.dart`. Mechanical and
   isolated on purpose — it is a large generated diff with no behaviour change,
   and nothing else should be hidden in it.
2. **Format and codec, both directions (pure).** `backup_manifest.dart`,
   `backup_payload.dart`, `backup_codec.dart` — `encode`, `decode` with its
   typed `BackupFormatException` cases (`notJson`, `missingManifest`,
   `unsupportedFormatVersion`, `newerSchemaVersion`, `unknownTable`,
   `missingTable`, `rowCountMismatch`, `badRow(table, index, cause)`), the empty
   payload-upgrader registry, and `BackupPayload.validate()`. Plus their tests
   and the minimal golden file. No app wiring yet — this step is the import
   contract of §4.1, and it is reviewable on its own.
3. **`BackupDao` + repository method.** `@DriftAccessor` over all eight
   tables; `readAll()` inside `transaction()`, each table ordered by `id`.
   Register the DAO on `@DriftDatabase`, regenerate, add
   `GolfyRepository.readBackupPayload()`, extend `test/dao/_fixtures.dart` with
   the full multi-round fixture, add the DAO tests and both guard tests. Commit
   `golden/backup_v1_full.json`, exported from that fixture — the file #70's
   restore tests will read.
4. **Destinations.** `backup_destination.dart` — the interface, the Android
   share-sheet implementation, the Windows save-dialog implementation, the
   platform factory and the Riverpod provider. Thin by design; verified on
   devices in step 7, not in unit tests.
5. **`BackupService`.** Orchestration, file naming, outcome type, temp
   cleanup, provider — with tests against a fake destination and a mocked
   `package_info_plus`.
6. **Settings screen.** `SettingsScreen`, `export_backup_action.dart`, the
   drawer entry, widget tests, and the updated `app_drawer_test.dart`.
7. **Docs, training and device verification.** Section 8 and 9 below, plus the
   manual checklist in section 10, then the `CHANGELOG.md` entry.

---

## 8. Testing plan

Target: **roughly 60–75 new tests** on top of today's 585, all runnable with
`flutter test` against in-memory SQLite — no device, no plugins. Rather more
than an export alone would need, because the reading and checking half is tested
here too (decision 9): the suite's job is to make "this file can be imported" a
fact before anyone owns one of these files.

**New fixture.** `test/dao/_fixtures.dart` gains `seedFullBackupFixture()`,
returning the expected row counts, and deliberately exercising every awkward
case in one dataset: two courses (one with a template, one without), two
yardage sets on one course, an event with a recorded finish plus one that
missed the cut plus a second season of the same name, three rounds (one with no
event and no set, one mid-round with 7 of 18 holes, one complete), a par 3 with
`fairway_hit` null, holes with and without shot lists, shots with null club /
distance / lie / result, notes containing quotes, newlines and non-ASCII
characters, and a round carrying a legacy `tee_set` value.

| Suite | File | Covers |
|---|---|---|
| Codec, pure | `test/data/backup/backup_codec_test.dart` | encode → decode round trip equals the original payload; key sets per table; booleans as `true`/`false`; nulls present and explicit; dependency order of `data` keys; rows ordered by id; pretty-printing stable; rejects non-JSON, missing envelope, unknown `formatVersion`, a newer `schemaVersion`, an unknown or missing table, a count mismatch, a row with a missing or wrongly typed column — each with the specific exception and a message naming table and row index |
| Golden, minimal | `test/data/backup/backup_v1_golden_test.dart` + `golden/backup_v1_minimal.json` | a small fixed payload encodes to a byte-identical committed file, and that file decodes back to the same payload. This is the format contract; a diff here means the format changed and #70 and every existing user file are affected |
| Golden, full | same suite + `golden/backup_v1_full.json` | the whole seeded fixture, exported and committed, decodes back to a payload equal to the fixture and passes `validate()`. This is the file **#70's restore tests read**, so export and import are proven against the same bytes rather than two hand-written approximations |
| Decode and validate | `test/data/backup/backup_decode_test.dart` | decoding is total — a file is either fully understood or rejected, never half-applied; `validate()` catches a `rounds` row whose `course_id` is absent from the file, a `hole_results` row whose `round_id` is absent, a duplicated `(round_id, hole_number)`, a duplicated `(name, season)`, a hole number of 0 or 19; a valid full payload reports no problems; every rejection message names the table and the row |
| Coverage guard | same suite | `BackupPayload.tables.keys` equals `db.allTables.map((t) => t.actualTableName)` — **fails the day a ninth table is added** |
| Column guard | same suite | for each table, the JSON keys of a round-tripped row equal `db.<table>.$columns.map((c) => c.name)` — **fails the day a column is added or renamed**, which is how a silent format change gets caught |
| Schema-version guard | same suite | `BackupCodec.supportedSchemaVersion == GolfyDatabase().schemaVersion` — **fails the day `schemaVersion` is bumped**, forcing a conscious decision and a payload upgrader |
| Export read | `test/dao/backup_dao_test.dart` | against `seedFullBackupFixture()`: every table's rows present and complete; counts match; ordering by id; null columns preserved; legacy columns preserved; an empty database yields eight empty lists; read is transactional (a concurrent write is not half-captured) |
| Service | `test/data/backup/backup_service_test.dart` | manifest fields (`formatVersion`, `schemaVersion`, app version from a mocked `PackageInfo`, UTC `exportedAt`, platform, counts matching the payload); file name shape and local-time stamp; outcome mapping for saved / shared / cancelled / destination failure / database failure; the file read back before it is handed over (see §15) |
| Screen | `test/features/settings/settings_screen_test.dart` | tile and explanatory copy render; subtitle counts render, including the empty-database wording; tap calls the destination exactly once with the expected file name and non-empty contents; success snackbar names the file; failure snackbar offers Retry and a retry calls again; progress indicator shown while in flight |
| Drawer | `test/shell/app_drawer_test.dart` (existing) | the Settings entry exists and pushes `SettingsScreen` |

**What is explicitly *not* tested here**, and where it is instead:

- A full export → wipe → import round trip **at the database level** is #70's
  acceptance criterion, as the issue says: writing the rows back, and proving
  the device ends up in the state it started in. What #69 proves is everything
  up to that line — the file contains every row and column, decodes back to an
  identical payload, and passes its own referential checks. #70 inherits a
  format it cannot misread, plus the sample file to read.
- The share sheet and the Windows save dialog are platform code behind a
  one-method interface; they are covered by the manual checklist in section 10,
  not by a widget test that would just assert a mock.

**Commands**, matching the project's existing idiom:

```powershell
cd app
flutter analyze
flutter test                              # full suite, expect ~630-640
flutter test test/data/backup             # codec + decode + service + guards
flutter test test/dao/backup_dao_test.dart
flutter test test/features/settings
```

---

## 9. Documentation plan

| Document | Change |
|---|---|
| **`BACKUP_FORMAT.md`** (new, repo root beside `RELEASING.md`) | The two-way contract: the envelope, the two version numbers and what each one means, table order and why an importer must not rely on it, key naming, type rules, ids and why they are restored verbatim, the integrity and referential checks, what an importer must accept and what it must refuse, the restore procedure of §4.1 (validate first, one transaction, no file swap), and the runbook "what to do when `schemaVersion` changes" — with the guard tests named as the things that will fail if it is skipped. This is the file #70 implements against, and the one a future maintainer reads first. |
| **`app/README.md`** | New **Data backup (export)** section: where the code lives, the one-transaction read, the two platform write paths and *why* Android cannot use a save dialog, the `build.yaml` JSON-key option, and the three guard tests with what each one protects. Plus: the project-layout tree (new `data/backup/`, `features/settings/`, new test dirs), a new architecture bullet ("Export is a pure codec behind a platform seam"), the dependency list, and the test count. |
| **`README.md`** (top level) | Status section at release time; a line in **Stack** for the three new packages; and a short user-facing **Back up your data** passage under the data-model section — this is the public doc a user actually reads. |
| **`CHANGELOG.md`** | One `### Added` entry under `[Unreleased]`, in the repo's narrative register: what it does, where it is, what the file contains, that nothing is uploaded, and that restoring arrives with #70. |
| **`RELEASING.md`** | Its "Declaring a breaking change" section already uses *"the backup file format changed and 0.3.x backups cannot be restored"* as its worked example. Turn that into a link to `BACKUP_FORMAT.md`, so the rule and the contract point at each other. |
| **Issue hygiene** | Comment on #69 with the two stale facts (target release is v0.4.0; Settings shell is being built here) and the format decision with its reasoning. Comment on #70 with the format contract link and the decision-6 simplification. Comment on #72 noting the shell exists and what remains for it. |

---

## 10. Training plan

Three audiences. The point of writing them down is that a backup feature nobody
knows how to use has not solved the problem the issue opens with.

### For the user — "How to back up your Golfy data"

Lives in the top-level `README.md` and, verbatim in shorter form, in the release
notes. Six steps, written for someone holding a phone:

1. Open the side menu → **Settings**.
2. Check the line under **Back up your data** — it tells you how many rounds,
   courses and events are about to be saved.
3. Tap it. Android shows your usual share sheet.
4. Pick somewhere **off the phone**: Google Drive, OneDrive, or email it to
   yourself. Saving it to the phone's own Files app protects you from a
   mistaken delete, but not from a lost phone.
5. The green bar at the bottom names the file it made, e.g.
   `golfy-backup-20261003-1432.json`.
6. Open it once, out of curiosity. It is plain text: at the top you will see
   when it was made and how many of each thing it holds. That is how you know
   it worked.

Plus the three questions this will actually generate, answered in the same
place: **How often?** After any session you would not want to re-enter.
**Does it go anywhere by itself?** No — nothing leaves the phone unless you
send it. **Can I put it back?** The file is built to be
read back in, and Golfy already knows how to read and check one — putting it
back on the device arrives with #70. Keep every file you make until then;
they will still be valid when it lands.

### In-app copy (part of the UI, reviewed as text)

The explanatory sentence, the tile title and subtitle, and all four snackbar
messages are written out in section 5 and land as real strings. Microcopy is
the only training most users will ever read, so it is reviewed as deliberately
as the code.

### For the maintainer — two runbooks in `app/README.md`

- **When you add a table.** Add it to `BackupPayload`, to the codec's row
  factories and to the dependency-ordered table list; add fixture rows; bump
  nothing else. The coverage guard test fails until the first step is done, so
  this cannot be forgotten.
- **When you bump `schemaVersion`.** The schema-version guard fails. Then:
  decide whether old files can still be read; if yes, add a payload upgrader
  from the old version and a golden file captured at it; update
  `BACKUP_FORMAT.md`'s compatibility table; if no, the release carries a
  `- **BREAKING:**` changelog entry per `RELEASING.md`. A worked example is
  written out so the first person to hit it has a template rather than a blank
  page.

### Pre-release verification checklist (goes in the pull request)

Run on a device, because none of it can be unit-tested:

- Android, real data: share → Google Drive; → Files ("Save to device"); →
  Gmail to self. Each produces a file that opens as text and whose `rowCounts`
  match the tile's subtitle.
- Android: dismiss the share sheet → no error, no stray file left in the cache.
- Android: airplane mode → still works (nothing in this path is online).
- Windows: save dialog writes to a chosen folder; cancel is a clean no-op.
- Empty database on both platforms → a valid file with zero counts.
- A large database (seed ~100 rounds) → no visible jank; note the duration, and
  move the JSON encode to an isolate only if it is actually felt.
- Reinstall over the previous version first, so the backup path is exercised on
  a database that arrived by migration rather than by fresh creation.

---

## 11. Risks

| Risk | Mitigation |
|---|---|
| **Format lock-in** — the day a user has a v1 file, Golfy must read it forever | Golden file plus the three guard tests make an accidental change a failing build; `BACKUP_FORMAT.md` makes a deliberate one a documented decision |
| **A field is silently left out of the backup** | Nothing is hand-listed: rows serialize from drift's own definitions, and the column guard test compares the file's keys against the live schema |
| **The format turns out to be awkward or impossible to import**, discovered after users hold files in it | The reason for decision 9: the reader, the validator and the sample files ship in this issue, so the claim "this file can be imported" is tested before a single user has one. #70 inherits a proven format, not a hopeful one |
| **A torn file if a hole is saved mid-export** | The whole read is one transaction |
| **Export lands without import, and a user believes they are safe when they are not** | Decision 4 (release together); in-app and release-note copy is explicit until #70 ships |
| **Three new native plugins, first in the project** | All standard and current; Windows glue committed and built once locally; Dependabot will now group their bumps onto `deps/patch` like any other dependency |
| **Android gives no true "Save as…"** | Verified and designed for (share sheet). If users ask for a direct save later, a SAF-capable plugin can be added behind the existing `BackupDestination` interface without touching the format or the service |
| **Large database stalls the UI thread during encode** | Progress indicator; measured in the checklist; `compute()` is a one-line fallback behind the service |
| **Play Data Safety declaration** ([#77](https://github.com/aellington89/golfy/issues/77)) | Export is user-initiated sharing of the user's own data with no automatic transmission — note it in #77 so the declaration stays accurate |

---

## 12. Out of scope

Deliberately not in this issue: **writing a decoded backup back into the
database** and the screens around it (#70) — note the line, since reading and
validating a file *is* in scope per decision 9, and only the database write-back
and UI are not; merge-vs-replace semantics (#70); the rest of the Settings
screen (#72); automatic or scheduled backups (Golfy has no background work);
cloud storage integration (it is local-only by design); and any selective or
partial export ("just this season") — the issue asks for a complete backup, and
a filtered export is a different feature with a different file.

---

## 13. Traceability to the issue's acceptance criteria

| Acceptance criterion | Where it is met |
|---|---|
| An Export action surfaced from Settings/About produces one backup file | §5 (Settings shell + `export_backup_action.dart`), decision 3 |
| Captures all eight tables at schema v7 | §4 rule 3, §8 coverage + column guard tests |
| Embeds the drift schema version for restore to validate/upgrade | §4 rules 1 and 8, §8 schema-version guard |
| Share sheet / SAF; nothing leaves the device automatically | §4 decision 2, §5 destinations, §10 checklist |
| Round-trips cleanly to an equivalent logical state | §4 rules 3, 4 and 9 (completeness, order, ids) plus §8's round-trip, both goldens and the decode/validate suite; the database-level round trip is #70's test, as the issue specifies |
| **The file can be imported** (the pairing with #70) | §4.1: decode, validate, version gatekeeping and the committed sample files all ship here; #70 inherits a format already proven readable and adds only the database write-back and its UI |
| Unit/integration coverage for a seeded multi-round fixture | §8 `seedFullBackupFixture()` + `backup_dao_test.dart` |
| Semver: additive user-facing feature → MINOR | §6: v0.4.0+38, derived not chosen (the issue's "v0.3.0" is stale) |
| Format decision (JSON vs SQLite copy) made during implementation | Decision 1: JSON, with the reasoning recorded |

---

## 14. Effort

About **two and a half focused days** for one developer, excluding review —
a little more than export alone, because the read half of the contract ships
here (decision 9) and pays for itself in #70:

| Step | Estimate |
|---|---|
| 1 — build.yaml + regenerate | 30 min |
| 2 — format, codec both directions, validation, tests and minimal golden | 5.5 h |
| 3 — BackupDao, repository, fixture, DAO + guard tests | 3 h |
| 4 — destinations (both platforms) | 2 h |
| 5 — service + tests | 2 h |
| 6 — Settings screen + widget tests | 3 h |
| 7 — docs, training, device verification | 3 h |

The long poles are the fixture and the codec tests, which is the right place
for the time to go: they are what make the format safe to live with — and what
let #70 be a short issue about writing rows into a database rather than a long
one about deciphering a file.

---

## 15. What was built, and where it departed from this plan

Implemented in one pass on `ccr-0dbe29db-wnq84q`. `flutter analyze` is clean
and the suite is **685 passing** (585 before, 100 new). The repo's own
calculator confirms the version: `dart run tool/next_version.dart` → **MINOR,
0.4.0+38**.

Everything in §§4–10 landed as described. Six departures, each an addition
rather than a change of direction:

1. **The export checks its own output before handing it over.** `BackupService`
   decodes the text it just produced and compares it to the payload it came
   from; a file that does not read back is never written. The suite proves the
   codec in general, this proves the one file on that device with that data —
   and it is the strongest possible answer to "is it really importable".
2. **Decoding rejects a row whose columns do not match the table**, in both
   directions — an unexpected key *and* a missing one. The missing case is the
   one that matters: a nullable column whose key had been dropped would
   otherwise decode as a deliberate null, turning a mangled file into silent
   data loss. The expected key set comes from the row drift just built, so
   there is no list to maintain.
3. **`BackupPayload.copyWith`** exists, because the payload upgraders a future
   schema bump will need rewrite one or two tables and leave the rest alone —
   and the validation tests wanted exactly the same shape.
4. **Temp-file sweeping lives in the destination, not the service, and the
   shared file is not deleted after the share.** §5 above says the cache copy
   is deleted "once the share sheet returns"; building it made clear that is
   wrong. A receiving app may read the content URI long after the sheet closes
   — Gmail holding a draft, a drive app queueing an upload — so deleting it
   then risks a 0-byte attachment behind a "Backup created" message, which is
   the worst failure this feature has. `share_plus` says the same of files it
   writes itself: clean up "once in a while", not immediately. Each export
   therefore sweeps the *previous* backups out of the cache before writing its
   own, which the Android destination owns because it owns the directory.
5. **100 new tests rather than the estimated 60–75**, mostly in the decode
   suite: the closed set of refusal reasons turned out to be worth a case each.
6. **`test/data/backup/_sample.dart`** holds the hand-built sample payload and
   the JSON-surgery helpers the format suites share, so each test damages one
   thing and asserts on the complaint.

Two things deliberately left undone, both of which the plan already assigned
elsewhere:

- **The test counts quoted in both READMEs still say 585.**
  [`RELEASING.md`](../../RELEASING.md) makes refreshing them step 7 of cutting
  a release, so a feature branch leaving them alone is the documented
  behaviour, not an oversight.
- **The pubspec version is untouched at `0.3.2+37`.** Same reason: the bump
  belongs to the `release/vX.Y.Z` cut, which this branch is not.

### What could not be verified here, and by what it will be

| Not verified | Covered by |
|---|---|
| `flutter build windows --debug` (the regenerated plugin glue links) | The CI Windows job, on every push |
| The Android share sheet reaching Drive / Files / Gmail, and a cancelled share | §10's device checklist, before the release is cut |
| The Windows save dialog writing to a chosen folder, and cancel | Same checklist |
| Export timing on a large database (~100 rounds) | Same checklist; `compute()` stays the one-line fallback |
