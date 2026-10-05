# Golfy backup format

The file Golfy's **Export** action writes, and the contract anything that
reads one has to keep ([#69](https://github.com/aellington89/golfy/issues/69),
[#70](https://github.com/aellington89/golfy/issues/70)).

The short version: one UTF-8 JSON file, pretty-printed, holding an envelope and
every row of every table. It is meant to be read — by a person with a text
editor, and by a future version of Golfy restoring it onto a new phone.

```
golfy-backup-20261003-1432.json
```

Local time in the name, because that is the one you recognise later; UTC inside
the envelope, because that is the one a machine should read. A plain `.json`
extension, so every share target, mail client and text editor handles it
without being taught.

---

## The envelope

```json
{
  "golfyBackup": {
    "formatVersion": 1,
    "schemaVersion": 7,
    "appVersion": "0.4.0+38",
    "exportedAt": "2026-10-03T14:32:07.000Z",
    "platform": "android",
    "rowCounts": { "courses": 1, "course_holes": 2, "…": 0 }
  },
  "data": { "…": [] }
}
```

| Field | Meaning |
|---|---|
| `formatVersion` | The **container** version — the shape of this envelope. Starts at 1 and moves only if the container itself changes. A reader refuses a version it does not know. |
| `schemaVersion` | The drift `schemaVersion` the rows were written at. This is the one that decides whether a reader understands the *data*. |
| `appVersion` | What `app/pubspec.yaml` said, e.g. `0.4.0+38`. Diagnostics only; nothing branches on it. |
| `exportedAt` | When the file was written, in UTC, ISO-8601. |
| `platform` | `android` or `windows`. |
| `rowCounts` | Rows per SQL table name, as written. The integrity check. |

**Two version numbers, because they answer different questions.** A container
change (say, splitting `data` into chunks) and a data change (a new column) are
not the same event and must not share a number.

**No device identifier, ever.** `platform` is the whole of it. Everything else
in a backup is golf data the user typed in themselves. Export is also the only
thing that moves data off the device, and only where the user sends it — see
[#77](https://github.com/aellington89/golfy/issues/77) for the Play Data Safety
declaration this supports.

## The data

```json
  "data": {
    "courses": [
      { "id": 1, "name": "Pebble Beach", "game_title": "PGA Tour 2K25" }
    ],
    "course_holes": [
      { "id": 1, "course_id": 1, "hole_number": 1, "par": 4, "stroke_index": 7 },
      { "id": 2, "course_id": 1, "hole_number": 2, "par": 3, "stroke_index": null }
    ]
  }
```

1. **All eight tables of schema v7**, every time: `courses`, `course_holes`,
   `course_sets`, `course_set_yards`, `events`, `rounds`, `hole_results`,
   `hole_shots`. A missing table is a malformed file, not an empty one — an
   empty table is `[]`.
2. **Parents first**, in the order listed above, so the file reads top-down and
   a streaming importer could insert as it parses. **A reader must not depend on
   that order** — it uses its own, so a file assembled by hand or by another
   tool still restores. (`backup_table_order` in the code; a test proves a
   reversed file still reads.)
3. **Rows ordered by `id`**, so two exports of the same data are byte-identical
   and therefore diffable.
4. **Keys are SQL names.** Table keys are table names, row keys are column
   names (`game_title`, not `gameTitle`) — so a backup reads identically to
   `app/drift_schemas/drift_schema_v7.json`, the schema's own description of
   itself. This comes from drift's `use_sql_column_name_as_json_key` option in
   [`app/build.yaml`](app/build.yaml).
5. **Every column, explicitly**, including ones the app no longer writes
   (`rounds.tee_set`, `rounds.migration_canary`). A null is written as `null`
   rather than omitted, so a **missing key is an error** — otherwise a mangled
   file would decode as a deliberate null and lose data quietly.
6. **Booleans are `true` / `false`**, not 0 / 1. It is a file people are meant
   to be able to read.
7. **Row ids are part of the data.** They are written as they are and restored
   unchanged: that is what preserves which hole belongs to which round, which
   round to which course and set, which shot to which hole. Ids in a real
   database have gaps (re-saving a hole consumes an autoincrement id), which is
   exactly why the file carries them rather than renumbering. SQLite's
   autoincrement counter re-derives itself from the highest id inserted, so
   rounds recorded *after* a restore cannot collide with restored ones, and
   nothing about `sqlite_sequence` needs to be in the file.

Size: a year of serious play (~100 rounds, 1 800 holes, ~7 000 shots) comes to
a few MB. Not compressed — that would cost the inspectability that justified
JSON in the first place.

---

## Reading a backup

A reader does three things, in this order, and none of them touches the
database:

**1. Decode.** Total by design: either a complete, typed payload comes back or
it throws, naming the table and row that defeated it. There is no
partially-understood backup, because a restore acting on one would lose data
silently. The refusals are a closed set (`BackupFormatProblem`): not JSON, no
envelope, a bad envelope field, an unknown container version, a newer or
unupgradable data version, a missing `data` section, a missing or unknown
table, a bad row, a row-count mismatch.

**2. Check the counts.** `rowCounts` against the rows actually parsed. A
truncated file fails to parse at all; a doctored or half-written one fails
here. That is deliberately the whole integrity story — no checksum library,
because a checksum would add a dependency to catch what these two already
catch.

**3. Check the references.** `BackupPayload.validate()` is pure and returns a
readable list: ids present and unique, every foreign key resolvable *within the
file*, no duplicated unique key, hole and shot numbering in range. SQLite would
catch all of it too, mid-restore, as a constraint error naming nothing a person
could act on. Doing it first means a bad file is refused with a reason and an
untouched database. Per-column CHECK constraints stay the database's job.

Decoding does **not** validate: a file can be perfectly well-formed and still
describe an impossible database, so the two stay separate steps.

### Version compatibility

| The file says | A reader does |
|---|---|
| `schemaVersion` **equal** to the app's | Read it |
| `schemaVersion` **greater** | Refuse: "this backup was made by a newer version of Golfy" |
| `schemaVersion` **lower** | Run the registered payload upgraders, in order, then read it |
| `formatVersion` anything but 1 | Refuse |

The upgrader registry is **empty**, and that is not an oversight: export did
not exist before schema v7, so no Golfy build can ever have written an older
backup. The registry exists so the first schema bump after this one has an
obvious home, and a guard test makes sure it is not forgotten.

## Restoring one

Implemented by [#70](https://github.com/aellington89/golfy/issues/70); the
procedure is here because the format was designed around it.

1. **Pick a file** with the system picker. `file_selector`'s *open* dialog
   works on Android as well as Windows — it is only *save* that Android lacks
   — so import needs no dependency export did not already add.
2. **Decode, check counts, check references.** Refuse with the reason, having
   touched nothing.
3. **Show the user what the file holds** (row counts, when it was made, which
   app version made it) *and* what they currently have, then require an
   explicit confirmation. Replacing is destructive and must look it.
4. **Apply in one transaction**: delete children → parents, insert parents →
   children with the ids from the file. If anything fails, the transaction
   rolls back and the device is exactly as it was. That, rather than a
   backup-of-the-backup, is the answer to "what if restore dies halfway".
5. **Insert through the tables, not the DAOs.** The DAO-layer invariants
   (`upDownSuccess` requires an attempt, `putts < score`, and so on) exist to
   stop bad *user input*; a restore replays rows that already passed them, and
   the SQL CHECK constraints still police a hand-edited file.
6. **Nothing else.** The database stays the same file, foreign keys stay on,
   and drift's watchers fire on commit — every screen refreshes by itself, with
   no app restart and no file swap.

Because restore *replaces*, there is no id remapping and no conflict resolution
to design. If merge is ever wanted, this format supports it: every row carries
its natural key as well as its id (course name + game title, round date +
course + number, event name + season, hole number within a round).

---

## When the schema changes

Three guard tests in
[`app/test/data/backup/backup_guards_test.dart`](app/test/data/backup/backup_guards_test.dart)
exist to fail, so none of this depends on remembering it.

**A table was added** → "every table in the schema is in the backup" fails.
Add it to `BackupPayload` (a typed list, plus its entry in `tables`), to
`backupTableOrder` **parents-first**, and to `BackupCodec.decode`'s row
factories. Add rows to `TestFixtures.seedFullBackupFixture()` and to
`samplePayload()` in `app/test/data/backup/_sample.dart`, then regenerate the
golden files.

**A column was added, renamed or dropped** → "every column of every table is
in the backup" fails. Nothing to write: rows serialize from drift's own
definitions. Regenerate the goldens and read the diff — the keys in it are the
format, and files already exist in the old shape.

**`schemaVersion` was bumped** → "the codec reads the schema version the app is
on" fails. Decide:

- *Old backups can still be read* — register an upgrader in
  `BackupCodec._upgraders`, keyed by the version it upgrades **from**, that
  rewrites only the tables the migration touched (`BackupPayload.copyWith`
  exists for this). Capture a golden file at the old version so the upgrade
  stays tested. Then bump `supportedSchemaVersion`.
- *They cannot* — bump `supportedSchemaVersion` and declare the break with a
  `- **BREAKING:**` changelog entry, which
  [`RELEASING.md`](RELEASING.md#declaring-a-breaking-change) treats as a major
  (clamped to minor pre-1.0, with a migration note).

Regenerating the goldens after a deliberate change:

```bash
cd app
GOLFY_UPDATE_GOLDEN=1 flutter test test/data/backup/backup_golden_test.dart
```

Read that diff as carefully as you would read a migration.

---

## Decisions, and what was rejected

**A JSON file rather than a copy of `golfy.sqlite`.** A database copy is less
code: `VACUUM INTO`, and a restore that swaps the file. It was rejected because
a backup you cannot read is a backup you have to trust — a subtly broken one
announces itself only on the day it is needed. Restoring is also safer from
JSON: the whole file can be checked *before* the database is touched and then
applied in one transaction, where swapping a file means closing a live
database, overwriting it and reopening, a sequence that can fail halfway and
that Windows file locking can block outright. And a text file leaves a future
merge mode possible.

**`.json`, not `.golfybak` or `.golfy.json`.** A distinctive extension was
considered so Android could offer "Open with Golfy". An Android intent filter
matches reliably on MIME type, not on a file-name pattern, and a file arriving
from Drive or Files comes through as an opaque `content://` URI whose name the
system may not expose — so the association would be unreliable whatever the
extension, while claiming `application/json` outright would claim every JSON
file on the device. Restoring goes through Golfy's own picker, which does not
care. The `golfy-backup-` prefix is what makes the file recognisable.

**No compression and no checksum.** Compression would cost inspectability; a
checksum would add a dependency to catch what JSON parsing plus `rowCounts`
already catch.

**The share sheet on Android.** Not a choice so much as the only option:
`file_selector` does not implement a save location on Android, because SAF
returns a `content://` URI `dart:io` cannot write to
([flutter/flutter#113441](https://github.com/flutter/flutter/issues/113441)).
Writing to the app's own cache and handing the file to the share sheet needs no
permission and reaches Drive, Files and mail. The cache copy is left in place
after the share — a receiving app may read the content URI long after the sheet
closes — and the next export sweeps it away. A direct "save to device" can be
added later behind the same `BackupDestination` interface without touching this
format.

## Where the code is

| What | Where |
|---|---|
| Format, envelope, payload, codec | [`app/lib/data/backup/`](app/lib/data/backup) |
| Reading every table in one transaction | [`app/lib/data/daos/backup_dao.dart`](app/lib/data/daos/backup_dao.dart) |
| Building a file and handing it over | `backup_service.dart`, `backup_destination.dart` |
| The Export action | [`app/lib/features/settings/`](app/lib/features/settings) |
| Format tests, guards, golden files | [`app/test/data/backup/`](app/test/data/backup) |
| The seeded fixture every suite shares | `app/test/dao/_fixtures.dart` (`seedFullBackupFixture`) |
