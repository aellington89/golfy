# Implementation plan — #70 Import / restore Golfy data from a backup file

## Context

Golfy stores everything on the device. Export ([#69], shipped in v0.4.0) lets a user save a backup file, but nothing can read that file back in yet. So a user with a new or wiped phone holds a backup they can't use, and the app tells them so: the Settings copy says restoring is "coming in a later update" (`app/lib/features/settings/settings_screen.dart:43-49`), and so does the README (`README.md:250-254`). This issue adds the other half: pick a backup, check it, show what it holds next to what the device has now, then replace the device's data in one transaction.

**Summary.** #69 already built and tested the risky reading side (decode, version gates, the v7→v8→v9 upgraders, cross-table validation, and the golden files). What's left here is (a) a transactional `replaceAll` on `BackupDao`, (b) a file-picking `BackupSource` that mirrors `BackupDestination`, (c) a `RestoreService` that refuses bad files before touching anything, and (d) a Settings tile with a confirmation dialog. **Size: M.** No new dependency, no schema change, no codegen.

### Acceptance criteria (from the issue, amended where later discussion or the code changed them)

1. Reads a backup chosen with the system file picker (SAF on Android, the open dialog on Windows).
2. ~~Run the drift migrations forward on an older backup~~ **Superseded:** an older backup (schema 7 or 8) is upgraded **as JSON** by `BackupCodec._upgraders`, which use the same frozen rules as the DB migrations (`app/lib/data/upgrades/`). A newer backup is refused. *(The #70 comment said the upgrader registry is empty. It is out of date: v7 and v8 upgraders now exist, `backup_codec.dart:61-67`, with frozen goldens to test against.)*
3. Merge-vs-replace is defined and documented. **Replace**, behind an explicit, destructive-looking confirmation.
4. After a restore, the device holds a logical state identical to the source. Proven by an export → wipe → import round trip and against `golden/backup_v1_full.json`.
5. Golfy's own backup format only. The `golf_stats.xlsx` import (#33) stays out.
6. Tests cover: round trip, older-schema upgrade-on-import, and refusal of malformed files.
7. *(Proposed)* A refused file leaves the database untouched, and so does a restore that fails partway. Every screen refreshes without a restart, and no stale in-memory state (the active round's drafts) can write into restored data.

## Scope

**In:** the DAO write path, the picker abstraction, the restore service, the Settings tile and dialog, tests, and docs (README, BACKUP_FORMAT.md, CHANGELOG, a plan doc).
**Out:** merge mode, "Open with Golfy" intent filters (rejected in BACKUP_FORMAT.md), automatic or scheduled backups, the rest of #72's Settings/About content, and the xlsx import (#33).
**Non-goals:** swapping the database file, restarting the app, id remapping.

## Current state (verified)

- **Reading is finished.** `BackupCodec.decode` (`app/lib/data/backup/backup_codec.dart:440-565`) is total: it returns a `BackupBundle(manifest, payload)` or throws a `BackupFormatException` carrying a `describe` string (`backup_format_exception.dart:72-79`). It refuses a newer schema (`:475`), refuses an older schema with no upgrader (`:483`), and upgrades v7 and v8 (`:524-528`). It checks row counts (`:543-562`).
- **`BackupPayload.validate()`** (`backup_payload.dart:158-280`) is a pure check of ids, foreign keys, unique keys, numbering and same-course yardage. It returns `List<BackupProblem>`, whose `toString()` is readable (`:35-38`).
- **`BackupDao`** (`app/lib/data/daos/backup_dao.dart`) already lists all 10 tables in `@DriftAccessor`. Its only method is `readAll()` (one transaction, ordered by id). Its comment at `:21-24` reserves the write side for #70. Adding methods needs **no** `build_runner` run, because the mixin only depends on the table list.
- **The repository** exposes only `readBackupPayload()` (`app/lib/data/repository.dart:280-285`).
- **Export pattern to mirror:**
  - `BackupService` (`backup_service.dart:49-139`) never throws and returns a typed result. It self-checks its output (`_verifyReadableBack`, `:131`), and its comment `:124-130` says validation is the restore's job.
  - `BackupDestination` (`backup_destination.dart:67-72`) is a one-method platform interface, faked in tests through `backupDestinationProvider` (`backup_provider.dart:12`).
  - `ExportBackupTile` (`app/lib/features/settings/export_backup_tile.dart`) has a busy guard, snackbars per status, and a Retry action.
- **Schema facts that make id-preserving replace safe:**
  - Every `id` is `INTEGER PRIMARY KEY AUTOINCREMENT` (10 occurrences in `database.g.dart`). After explicit-id inserts, `sqlite_sequence` = max(old counter, highest inserted id), so new rows can't collide.
  - FKs are ON (`database.dart` `beforeOpen`), and are checked immediately.
  - `rounds.course_id` is `RESTRICT` (`tables/rounds.dart:17`); everything else cascades or is set to null. Deleting in reverse `backupTableOrder` (`backup_payload.dart:11-22`) and inserting forward satisfies all FKs.
  - No nullable column has a default (`withDefault` appears only on non-null `season`, `tied`, `missed_cut`, `round_number`). Still, inserting via `toCompanion(false)` keeps explicit nulls explicit if that ever changes.
- **Picker on Android** (`file_selector_android 0.5.2+11`, already a transitive dependency): `openFile` fires `ACTION_OPEN_DOCUMENT`, maps `XTypeGroup.extensions` to MIME types via `MimeTypeMap` (`FileSelectorApiImpl.java:278`), and **copies the picked document into `cacheDir/{uuid}/{name}`** (`FileUtils.java:112`). So the result is a real path that `dart:io` can read, and those copies pile up in the cache unless deleted.
- **Stale-state hazard (found during investigation, not mentioned in the issue):**
  - Settings is *pushed over* the shell (`app/lib/shell/app_drawer.dart:56-62`). The tabs stay alive underneath in an `IndexedStack` (`app_shell.dart:18`).
  - `HoleEntryScreen` keeps per-round drafts keyed on `activeRoundIdProvider` (`hole_entry_screen.dart:299-310`; `features/rounds/active_round_provider.dart`).
  - Restored ids come from another device, so after a restore, id 5 may be a *different* round. A pending draft could then be saved into it.
- **Tests to follow:**
  - `test/dao/backup_dao_test.dart`: in-memory DB plus `TestFixtures.seedFullBackupFixture()` (`test/dao/_fixtures.dart:169`).
  - `test/data/backup/backup_golden_test.dart`: reads the goldens, including `backup_v1_schema{7,8}_{minimal,full}.json`.
  - `test/data/backup/_sample.dart`: provides `samplePayload()` and `sampleManifest()`.
  - `test/features/settings/settings_screen_test.dart`: the real service over an in-memory DB, a `FakeDestination`, and stream providers overridden with `Stream.value` (per memory: never widget-test live drift `.watch()`).
- **Copy that becomes wrong:**
  - `settings_screen.dart:43-49` ("Restoring a backup is coming…"), and its test "says what restoring will need" (`settings_screen_test.dart` ~`:127`).
  - The drawer subtitle "Back up your data" (`app_drawer.dart:55`).
  - `README.md:250-257`.
  - `BACKUP_FORMAT.md` § Restoring one ("Implemented by #70", future tense).

## Proposed design

### Flow

```
Settings ▸ Restore from a backup
  └─ RestoreService.prepare()
       BackupSource.pick() ── cancelled ─▶ snackbar "Restore cancelled — nothing changed"
         │ picked(name, text)
         ├─ size > cap / not UTF-8 ───────▶ refused(reason)
         ├─ strip BOM → BackupCodec.decode ─ BackupFormatException ▶ refused(e.describe)
         ├─ payload.validate() non-empty ─▶ refused(first problems)
         └─ BackupDao.countRows() (device now) ▶ ready(RestorePlan)
  └─ RestoreConfirmDialog(plan) ── Cancel ─▶ nothing changed
         │ Replace
  └─ RestoreService.apply(plan)
       BackupDao.replaceAll(payload)   ← ONE transaction:
         delete reverse(backupTableOrder) → insert backupTableOrder (ids verbatim)
         → readAll() == payload, else throw → rollback
       ├─ failed ─▶ dialog "Restore failed — your data is unchanged" + reason
       └─ restored ─▶ clear activeRoundId; snackbar "Restored 42 rounds · 3 courses · 4 events"
  drift watchers fire on commit → every tab refreshes itself
```

### Interfaces (sketches)

```dart
// app/lib/data/daos/backup_dao.dart
Future<void> replaceAll(BackupPayload payload);   // one transaction; throws → rolled back
Future<Map<String, int>> countRows();             // SQL table name → COUNT(*), backupTableOrder keys

// app/lib/data/repository.dart
Future<void> restoreBackupPayload(BackupPayload payload) => _db.backupDao.replaceAll(payload);
Future<Map<String, int>> countBackupRows() => _db.backupDao.countRows();

// app/lib/data/backup/backup_source.dart  (mirror of backup_destination.dart)
sealed/enum-backed BackupPickOutcome { picked(fileName, contents) | cancelled | failed(error) }
abstract class BackupSource { Future<BackupPickOutcome> pick(); }
class FileSelectorBackupSource implements BackupSource  // openFile, size cap, UTF-8, delete Android cache copy
BackupSource createPlatformBackupSource();

// app/lib/data/backup/restore_service.dart
class RestorePlan { fileName; BackupManifest manifest; BackupPayload payload; Map<String,int> currentCounts; bool get deviceIsEmpty; }
sealed class RestorePreparation { cancelled | refused(String reason) | ready(RestorePlan) }
class RestoreResult { RestoreStatus status (restored|failed); Map<String,int> rowCounts; String? error; }
class RestoreService {
  RestoreService({required GolfyRepository repository, required BackupSource source});
  Future<RestorePreparation> prepare();   // never throws; touches nothing
  Future<RestoreResult> apply(RestorePlan plan); // never throws
}

// app/lib/data/backup/backup_provider.dart  (add)
final backupSourceProvider = Provider<BackupSource>(...);
final restoreServiceProvider = Provider<RestoreService>(...);

// app/lib/features/settings/restore_backup_tile.dart, restore_confirm_dialog.dart
```

### Key decisions

- **`replaceAll` writes the tables directly** with drift `batch` + `insertAll(table, rows.map((r) => r.toCompanion(false)), mode: InsertMode.insert)`, one explicit line per table, matching `readAll`'s style.
  - Why not through the DAOs: their invariants police user input. BACKUP_FORMAT.md §Restoring 5 makes the same call.
  - Why `InsertMode.insert`: a duplicate fails loudly and rolls back, rather than overwriting quietly.
- **A read-back check inside the transaction.** `readAll() == payload`, otherwise throw. This mirrors export's `_verifyReadableBack`: it proves *this* restore on *this* device, costs one read, and turns any silent drift-insert mismatch into a rollback. (Drift nests `transaction` as a savepoint.)
- **Validation lives in `RestoreService.prepare`, not the DAO.** The DAO's guarantees are atomicity and SQL constraints. A plan can only be built from a validated payload, so `apply` never sees an unvalidated one.
- **`countRows()` rather than `readAll().rowCounts`** for the "what you have now" panel. It's ten `COUNT(*)` queries instead of reading a few MB.
- **Two phases (prepare / apply)** so the dialog sits between them, and so each phase can be tested without UI.
- **Clear `activeRoundIdProvider` after a successful restore.** This removes the stale-draft hazard, and HoleEntry falls back to its empty state (`hole_entry_screen.dart:301`). The user stays on Settings and sees the success snackbar.
- **Refusals go in an `AlertDialog`, not a snackbar.** The reasons are long and specific (e.g. "this backup was made by a newer version of Golfy … update Golfy and try again", or "rounds row 3: course_id 9 is not in courses"). Show up to 5 validation problems, then "…and N more". Cancel and success use snackbars, like export.
- **Input hygiene in the source and service:**
  - A **64 MB cap**, checked with `XFile.length()` before reading. A year of heavy play is a few MB; the cap stops an accidentally picked video from exhausting memory.
  - UTF-8 decode errors come back as a readable refusal.
  - A leading BOM (`\uFEFF`, typical of a file re-saved in Notepad) is stripped before `decode`. Done in the service so the codec contract stays as it is.
  - Android's cache copy is deleted after reading (best effort, like `_sweepStaleBackups`).
- **Picker filter.** Windows: `XTypeGroup(label: 'Golfy backup', extensions: ['json'])`. Android: also `mimeTypes: ['application/json', 'text/plain', 'application/octet-stream']`, because Drive and mail attachments don't always keep `application/json`. A loose filter costs nothing, since decode refuses anything that isn't a backup and says why.
- **Confirmation dialog content.** Uses `intl` (already a dependency).
  - Title: *"Replace everything on this device?"*
  - The file: made <local date/time> by Golfy <appVersion> on <platform>; holds N rounds · N courses · N events (N holes, N shots).
  - The device now: same counts, or "nothing yet".
  - A note when `schemaVersion` < current: "made by an older Golfy — it will be updated as it is restored".
  - "This can't be undone."
  - Buttons: Cancel, and **Replace** as an error-coloured `FilledButton`.
  - On an empty device, the wording softens ("Restore this backup?") but the dialog still appears.

### Alternatives rejected

- **Swap the SQLite file:** rejected in BACKUP_FORMAT.md. It needs a live-DB close and reopen, Windows file locks get in the way, and the file can't be checked first.
- **Restore through the DAOs:** the invariants would wrongly refuse legitimate history, and there'd be ~10 call sites to keep in step.
- **Generic loop over `db.allTables`:** shorter, but loses typing, and drift's `TableInfo<T, D>` generics make it awkward. The round-trip test already catches a table added to the schema but not restored.
- **Merge:** deferred, as the issue recommends. The format still supports it via natural keys.
- **Running the drift migrations on old backups (the original AC2):** the JSON upgraders do the same job without a scratch database, and they share the migration's frozen rules.

### Compatibility and migration

No schema change and no format change. Backups at schema 7, 8 and 9 (every file Golfy has ever written) restore. A backup from a newer Golfy is refused with "update Golfy".

## Implementation steps

1. **DAO write side.** Files: `backup_dao.dart` (`replaceAll`, `countRows`; update the class comment), `repository.dart` (two pass-throughs), `test/dao/backup_dao_test.dart` (new group). *Depends on nothing.*
2. **Picker abstraction.** Files: new `app/lib/data/backup/backup_source.dart` and `backupSourceProvider` in `backup_provider.dart`. The platform implementation isn't unit-testable, like `BackupDestination`. *Independent of 1; can be done in parallel.*
3. **RestoreService.** Files: new `app/lib/data/backup/restore_service.dart`, `restoreServiceProvider`, and `test/data/backup/restore_service_test.dart` with a `FakeSource`. *Depends on 1 and 2.*
4. **UI.** Files:
   - new `restore_backup_tile.dart` and `restore_confirm_dialog.dart` under `app/lib/features/settings/`
   - `settings_screen.dart`: add the tile under Export; replace the "coming in a later update" paragraph with "Restoring replaces everything on this device with what the file holds."
   - `app_drawer.dart`: subtitle becomes "Back up & restore"
   - `settings_screen_test.dart`: update the copy test and add a restore group, or add a sibling `restore_backup_tile_test.dart`

   *Depends on 3.*
5. **Docs and handoff.** README, BACKUP_FORMAT.md, CHANGELOG, `docs/plans/issue-70-data-restore.md`, and an issue comment (details below). *Depends on 4 for the final copy.*

Steps 1 and 2 can go in parallel. Steps 3, 4 and 5 run in sequence. No pubspec bump on the feature branch: per the #69 plan's departure notes and RELEASING.md, the bump belongs to the `release/vX.Y.Z` cut.

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Restore dies halfway | One transaction plus a read-back check. Any throw rolls back. Tested by injecting a CHECK violation in the **last** table (`hole_shots`), so the earlier deletes and inserts are proven to roll back too |
| The user restores the wrong or old file and loses newer data | The dialog shows both sides' counts and dates, uses destructive styling, and says "can't be undone". See Q1 for an optional "Back up first" |
| Stale in-memory state writes into restored ids | Clear `activeRoundIdProvider` on success. The drafts reset when the active round changes (`hole_entry_screen.dart:305-310`). Covered by a widget test |
| The Android filter hides a valid file | Loose MIME set. Checked on a device against a Drive copy, a Gmail attachment and a Files copy |
| A huge or non-text file | 64 MB cap before reading; UTF-8 errors become a refusal |
| Cache copies pile up (Android) | Delete the picked copy after reading, best effort |
| `sqlite_sequence` collisions | Not possible with AUTOINCREMENT, since the counter only rises. Tested: a round inserted after a restore gets an id above every restored id, including when the restored ids are *lower* than the device's old counter |
| Widget test hangs on drift under `FakeAsync` | Stream providers stay overridden (no live `.watch()`). Writes happen on `NativeDatabase.memory()` just as the export test's reads do. Fallback: wrap `apply` in `tester.runAsync` |
| Decode time on a large file | A few MB parse well under a second. As in #69, `compute()` is the one-line fallback, used only if a device run shows jank |
| Rollback of the feature | It's purely additive. Revert the PR; no data or schema to undo |

## Testing strategy

**DAO (`test/dao/backup_dao_test.dart`, new group "restoring"):**
- `replaceAll(decode(golden full).payload)` on an empty DB, then `readAll() == payload`.
- The same onto a DB pre-seeded with *different* data. Afterwards none of the old rows remain, and `readAll() == payload`.
- An empty payload wipes the device to zero rows.
- A CHECK violation in the last table throws, and `readAll()` equals the pre-state, so nothing changed.
- A duplicate id throws and rolls back.
- After a restore, a new round's id is greater than every restored id. This includes restoring a low-id backup over a high-counter device.
- `countRows()` matches `seedFullBackupFixture()`'s returned counts, with keys equal to `backupTableOrder`.

**Service (`test/data/backup/restore_service_test.dart`):**
- **Round trip (AC4 and AC6):** seed the fixture, `BackupService.createBackup` into a `FakeDestination`, a fresh in-memory DB, `RestoreService` with a `FakeSource` holding those contents, `prepare`, `apply`, then `readAll()` equals the original.
- **Older schema (AC2 and AC6):** each of `backup_v1_schema7_full.json` and `backup_v1_schema8_full.json` → `prepare` is `ready` and `manifest.schemaVersion` is 7 or 8 → `apply` → `readAll()` equals `BackupCodec.decode(file).payload` and validates clean.
- **Malformed (AC6):** each of these gives `refused` with a specific reason, and the DB is untouched, by a `readAll()` comparison:
  - not JSON
  - not UTF-8 bytes
  - newer `schemaVersion`
  - unknown `formatVersion`
  - a row-count mismatch
  - a dangling FK (passes decode, fails `validate`)
  - over the size cap
- A BOM-prefixed golden is accepted.
- Cancelled pick gives `cancelled`; source failure gives `refused` naming the error.
- `currentCounts` reflects the device; `deviceIsEmpty` is right on both kinds of DB.
- `apply` on a failure (inject via a payload that validates but breaks a CHECK) gives `failed` and the data is unchanged. It never throws.

**Widget (Settings):**
- The tile is shown, and the copy no longer says "coming".
- Cancel in the picker gives the "nothing changed" snackbar.
- A refused file shows the dialog with its reason.
- The confirm dialog shows the file's counts, its date, its app version and the device's counts.
- Cancel in the dialog leaves the DB unchanged.
- Replace gives the success snackbar, the DB equals the file, and `activeRoundIdProvider` is null.
- A second tap while busy is ignored, and progress is shown.

**Regression:** the existing export, golden and guard suites must still pass unchanged, which proves the codec wasn't touched. Run them as targeted `flutter test test/...` runs (per memory: the full run can hit the sqlite3.dll lock).

**Device checklist (in the PR):**
- Android: restore from Drive, from a Gmail attachment, and from Files.
- Android: restore onto a freshly installed app, then check every tab refreshes.
- Windows: open dialog, then cancel.
- A v0.4.0-era (schema 7) file from a real device.

| AC | Verified by |
|---|---|
| 1 Picker | `BackupSource` fake in service and widget tests; device checklist for the real pickers |
| 2 Version handling | Service tests on the schema7 and schema8 goldens; refusal test for newer schema |
| 3 Replace semantics | DAO "different data beforehand" test; widget confirm-dialog tests; BACKUP_FORMAT.md + README |
| 4 Identical state | Export→wipe→import round trip; golden-full DAO test |
| 5 Own format only | Scope; a non-backup JSON is refused (`missingManifest`) |
| 6 Coverage | All three named categories above |
| 7 Untouched on failure / no stale state | Rollback DAO tests; refused-file "untouched" assertions; widget active-round test |

## Documentation and handoff

- **CHANGELOG.md** `[Unreleased]` → `### Added`: a narrative entry on restoring a backup, replace semantics, which files restore (anything Golfy has exported, v0.4.0 onward), and that a refused or failed restore changes nothing. `### Added` → minor → **v0.8.0** via `tool/next_version.dart`.
- **README.md:** rename the section "Back up and restore your data". Add a numbered **Restore** walkthrough:
  1. Get the file onto the device: Drive, Files or mail on Android; any folder on Windows.
  2. Settings → **Restore from a backup**.
  3. Pick the file.
  4. Read the comparison: what the file holds, and what's here now.
  5. **Replace**.
  6. Check the counts in the bar.

  Also add an FAQ: "What if I pick the wrong file?" (read the dialog; nothing happens until Replace), "Will it merge?" (no, it replaces), and "A file from a newer Golfy" (update first). Replace the "arrives with #70" text at `:250-257`.
- **BACKUP_FORMAT.md:**
  - § Restoring one: present tense, plus the confirmation contents, the size cap, BOM tolerance, and the post-restore active-round reset.
  - § When the schema changes → "A table was added": add "and a line in `BackupDao.replaceAll` (the round-trip test fails until you do)".
  - § Where the code is: add `restore_service.dart`, `backup_source.dart` and the restore tile.
- **In-app copy:** the Settings paragraph and the drawer subtitle (step 4).
- **Plan doc:** `docs/plans/issue-70-data-restore.md`, following `issue-69-data-export.md`'s structure and ending with a "what was built" section.
- **Issue hygiene:** comment on #70 that AC2 is now met by the JSON upgraders, not the drift migrations, and that the "registry is empty" note is stale. #72 needs no change, since restore sits in the same Data section.
- **Maintainer:** there's no new runtime config. The device checklist goes in the PR. The read-back check in `replaceAll` is the place to look first if a restore ever reports "did not read back".

## Open questions

1. **Offer "Back up what's here first" in the confirm dialog when the device has data?** It matters because replace destroys the current data, and restoring the wrong file is the most likely user error. *Recommend:* yes, a text button that closes the dialog and runs the existing export (`backupServiceProvider`). The user then taps Restore again; that re-pick is accepted as the cost. Silent auto-snapshots are rejected: on Android a user can't reach app-private storage to restore one. *Not blocking.* Step 4 only.
2. **Restoring a backup with zero rows onto a device with data:** allow or refuse? *Recommend:* allow, with the dialog saying "This backup is empty — replacing will erase everything on this device." It's a legitimate file, and refusing would need its own explanation. *Not blocking.*
3. **Android picker filter:** use the loose MIME set (json, text/plain, octet-stream) as proposed? *Recommend:* yes, and confirm on a device. *Not blocking.*
4. **Size cap of 64 MB?** *Recommend:* yes. That's about 20× a heavy year of data. *Not blocking.*
5. **After a successful restore, stay on Settings and just clear the active round?** The alternative is popping to the Rounds tab. *Recommend:* stay, plus the snackbar. *Not blocking.*
6. **Release:** ship as v0.8.0 on its own, since Export already shipped alone in v0.4.0? *Recommend:* yes. *Not blocking.*

[#69]: https://github.com/aellington89/golfy/issues/69

---

## What was built, and where it departed from this plan

All five steps landed as planned, in four commits (DAO; source + service; UI;
docs). The open questions were taken at their recommendations: **Back up
first** is offered when the device has data (Q1); an empty backup is allowed,
with the dialog saying it will erase everything (Q2); the loose Android MIME
set (Q3); a 64 MB cap (Q4); the user stays on Settings and the active round is
cleared (Q5); the release is a minor on its own (Q6).

Departures, all small:

- **The restore DAO tests are their own file**,
  `app/test/dao/backup_dao_restore_test.dart`, rather than a group in
  `backup_dao_test.dart` — the export file's header describes the read side,
  and the two read better apart. It also carries a DAO-level reactivity test
  (a `rounds` watcher hears the restore), which is where drift reactivity is
  tested in this repo rather than in widget tests.
- **`BackupPickOutcome` carries bytes, not text.** The size cap lives in
  `readPickedBackup(XFile)`, a pure function the tests drive with an in-memory
  `XFile`; UTF-8 decoding and the byte-order mark are the service's, so "not
  text" is tested at the service level with a fake source. On `dart:io` an
  `XFile`'s name is the last segment of its path, which is what the picker's
  Android cache copy is named after.
- **`showBackupResult` was extracted from `ExportBackupTile`**, so **Back up
  first** reports an export exactly as the export tile does.
- **The tile's spinner shows only while work runs**, not while a dialog waits
  on the user: an indicator animating behind a modal both looked wrong and kept
  `pumpAndSettle` from ever settling. A separate `_busy` flag still ignores a
  second tap for the whole restore.
- **`replaceAll` compares the read-back with the payload sorted by id**, so a
  hand-assembled file whose rows come in another order still restores (tested).

### What could not be verified here, and by what it will be

| Not verified | Covered by |
|---|---|
| The Android picker reaching Drive, Files and a Gmail attachment with the loose MIME filter, and the cache copy being deleted | The device checklist, before the release is cut |
| The Windows open dialog, and cancelling it | Same checklist |
| Every tab refreshing after a restore on a real device | Same checklist (the DAO test proves watchers fire) |
| A schema 7 file made by a real v0.4.0 install | Same checklist (the frozen schema 7 goldens prove the upgrade) |
