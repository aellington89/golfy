# Changelog

All notable changes to Golfy are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Versions track the `version:` field in [`app/pubspec.yaml`](app/pubspec.yaml).

## [Unreleased]

### Added

- **Golfy has its own icon and launch screen** ([#71]). The stock Flutter
  icon is gone from the Android launcher and from the Windows taskbar, title
  bar and Explorer. In its place is a flag-yellow pennant on a white pin in
  the cup, with a ball on the green, under a blue sky. On Android 8 and later
  it's an adaptive icon, so it takes whatever shape your launcher uses, and on
  Android 13 and later it follows your **themed icons** colours when that
  setting is on.

  While Android starts the app, it now shows the same flag on a green circle,
  on the background colour the app opens with, light or dark to match your
  system setting. Before, it was plain white or black. Windows needs no launch
  screen: its window appears once the app is ready, as before.

### Changed

- **The score distribution names every result** ([#59]). The dashboard card
  used to fold anything at two under or better into **Eagles** and anything
  at two over or worse into **Double+**. It now has a row each for **Condor**
  (-4), **Albatross** (-3), **Eagle**, **Birdie**, **Par**, **Bogey**,
  **Double bogey**, **Triple bogey** and **Quadruple+ bogey** (+4 or worse),
  always in that order and shown at zero when empty.

  An **Ace** row sits above them, highlighted, counting holes-in-one. An ace is
  also counted in the row its score falls in: Eagle on a par 3, Albatross on a
  par 4, Condor on a par 5. A note on the card says so. The percentages are
  each row's share of holes played, and the Ace row isn't added to that total,
  so the nine score rows still add up to 100%.

### Internal

- **The icon and splash are generated from source art, and tested** ([#71]).
  The artwork is SVG under `app/branding/`. `flutter_launcher_icons` and
  `flutter_native_splash`, both dev dependencies only, turn it into the
  committed Android resources, and the multi-size Windows `.ico` is built
  from the same SVG. `test/branding/` fails if a stock Flutter icon comes
  back in any variant, or if the splash colours stop matching the theme's
  surface colours. Nothing new runs in the app: no new runtime dependency,
  permission or code path.

## [0.8.0] - 2026-10-24

A release that brings a backup back ([#70]). Since v0.4.0, **Settings → Back
up your data** has written everything to one JSON file you keep wherever you
like, but nothing could read that file again. Now **Settings → Restore from a
backup** does: pick the file, see what it holds next to what the device holds,
and confirm. A new or wiped phone gets its courses, rounds and events back,
and every backup Golfy has made restores, including those from before v0.7.0's
tee-set and pin-set split.

A restore **replaces** what is on the device rather than merging with it, and
it asks first, with a **Back up first** button whenever there is something to
lose. A file that is damaged, edited, or from a newer Golfy is refused before
anything changes, and the replace runs as one transaction, so a restore either
finishes or leaves the device as it was.

The schema does **not** move: still v9, and no migration runs on upgrade. The
release is a **minor**, for the `### Added` entry below.

### Added

- **A backup can go back onto a device** ([#70]): **Settings → Restore from a
  backup** opens the system file picker — Drive, Files and downloaded
  attachments on Android, any folder on Windows — and puts the file's courses,
  tee and pin sets, rounds, holes, shots and events onto this device. It is the
  other half of Export ([#69]): a new or wiped phone now gets its rounds back.

  Restoring **replaces** what is on the device rather than merging with it, so
  it asks first. The question shows what the file holds — when it was made, by
  which Golfy, on what, and how many rounds, courses, events, holes and shots —
  beside what the device holds now, and says plainly that it cannot be undone.
  When the device has data, **Back up first** saves it with the ordinary export
  before anything is replaced.

  A file is checked whole before anything is touched: one that is not a Golfy
  backup, was made by a newer Golfy, has been cut short or edited, or holds
  rows that do not fit together is refused with the reason, and nothing on the
  device changes. Every backup Golfy has ever written restores, from v0.4.0
  on; files made before v0.7.0's tee-set and pin-set split are converted as
  they are read, exactly as an upgraded database was. The replace itself is a
  single transaction, so a restore that fails partway leaves the device as it
  was, and every screen shows the restored data without a restart. A round
  open in Hole Entry is closed by a restore, since its id may now belong to a
  different round.

### Internal

- **The drift version check compares `major.minor`, not exact versions**
  ([#133]; merged up in [#134]). drift and drift_dev share a minor line but
  ship patch releases separately — drift 2.35.2 has no drift_dev 2.35.2 — so
  requiring the two to match exactly made a routine drift bump impossible to
  get green. A split across minor lines still fails. Test-only; nothing in the
  APK changes.

## [0.7.1] - 2026-10-18

A release that fixes the course editor losing track of the sets you played
([#130]). v0.7.0 split a course's yardage into tee sets and pin sets, and
"Update course as I play" saved each hole's yards into the round's pair, but
the editor always opened on whichever sets sort first by name, so after a
round on a new pin set the yards you had just recorded looked lost. They were
there all along; the editor now opens on the sets of the round you last played
on that course.

It also carries the dependency batch that collected on `deps/patch` since
v0.7.0, merged up to `master` in [#131]: one patch bump to the code
generator, which changes nothing that ships in the APK.

The schema does **not** move: still v9, and no migration runs on upgrade. The
release is a **patch**, for the `### Fixed` entry below.

### Fixed

- **The course editor opens on the tee set and pin set you last played**
  ([#130]). "Update course as I play" saved each hole's yards into the round's
  tee set and pin set, but the course editor always opened on whichever tee set
  and pin set sort first by name. After a round on a newly added pin set, its
  tee-to-pin yards were stored, but the editor showed another pin set's card,
  so the update looked lost. The editor now starts on the sets of the round
  last played on the course, and a set you pick or add still takes over. The
  New Round dialog also says to pick a tee set when you pick a pin set without
  one, because tee-to-pin yards are kept per tee set and a pin set alone has
  nowhere to record them.

### Internal

- **`build_runner` moves from 2.16.1 to 2.16.2** ([#129]; merged up in
  [#131]). A dev dependency only: it runs drift's codegen and is not part of
  the app, and the committed `*.g.dart` output is unchanged by it.

## [0.7.0] - 2026-10-11

A release about the yardage on a course ([#127]). Until now a course had
"yardage sets" with one number per hole, and nothing said whether a set was a
tee box or a set of pins, so the scorecard yardage and the distance to the pin
were one field. They are different numbers. A tee set's **course yards** depend
on the tee box alone. How far a hole plays to the pin depends on the tee set
and the pin set together, so **tee-to-pin** yards are kept for each tee set and
pin set. A round now records both, and each hole pre-fills from that pair. Par
and stroke index stay one per hole.

Your yardage sets come across as what they were. Each one was named "Tee Set -
Pin Set" and held that pair's distances to the pin. So "Blue - Sunday pins"
becomes the tee set Blue and the pin set Sunday pins, and its yards become
Blue's tee-to-pin yards to Sunday pins. A round played on it is now played on
that pair. Course yards start empty, because nothing recorded them before. A
set whose name has no " - " becomes a tee set on its own, and its yards become
that tee set's course yards.

The schema **moves**, v8 → v9, and a migration runs on every device that
installs this. It runs in a single step that either finishes or leaves the
database as it was. Backups made by v0.4.0 to v0.6.0 still read, converted the
same way. The release is a **minor**, both for the `### Changed` entries below
and because the schema rose.

### Changed

- **Yardage is split into tee sets and pin sets.** A course used to have just
  "yardage sets", each holding one yardage per hole, and nothing said whether a
  set was a tee box or a set of pins. Now the two are separate, because they
  change different numbers. A **tee set** (Blue, Championship) has its
  **course yards**: the scorecard yardage per hole, which depends on the tee
  set and never on where the pin is. A **pin set** (Sunday pins) has
  **tee-to-pin** yards, the distance to that pin set's pin on each hole. That
  distance depends on the tee set too, so it is kept per tee set: the same pins
  are a different distance from each tee. Par and stroke index stay one per
  hole, whatever the tee and pins. The course editor has a tee set strip and a
  pin set strip, and each hole card shows course yards for the chosen tee set
  and tee-to-pin for the chosen tee set and pin set. Starting a round now asks
  for a tee set and a pin set, which together are its **yardage set**. Each
  hole pre-fills with that pair's tee-to-pin yards, or with the tee set's
  course yards when the round has no pin set. "Update course as I play" writes
  back to whichever of the two the round used. The rounds list and the yards
  field name both sets, e.g. "Blue · Sunday pins". A tee set copied from
  another still copies its course yards with an offset. A pin set has no
  yards of its own, so there is nothing to copy.

- **The schema moves to v9, and each yardage set becomes the tee set and pin
  set it named.** An old set was one tee set and pin set together, named "Tee
  Set - Pin Set", and its yards were the tee-to-pin yards for that pair. The
  migration splits each name at the " - ": "Blue - Sunday pins" becomes the
  tee set Blue and the pin set Sunday pins, and its yards become Blue's
  tee-to-pin yards to Sunday pins. Sets that name the same tee set or pin set
  on a course share one; "Blue - Sunday pins" and "Blue - Monday pins" give one
  Blue tee set with a card for each set of pins. A round played on a set is now
  played on that tee set and pin set. Course yards start empty, since the old
  sets never recorded them; fill them in from the course editor. A set whose
  name has no " - " can't be split. It becomes a tee set on its own, and its
  yards become that tee set's course yards, which is what a round with no pin
  set uses. Rounds, holes and shots are untouched. A round that you moved to
  another course after choosing its set used to keep the old course's set. That
  link is now cleared, and editing a round's course clears its tee set and pin
  set from now on. The migration runs in one step that either finishes or leaves the
  database as it was. Backups move with it: new ones carry `tee_sets`,
  `course_yards`, `pin_sets` and `tee_to_pin_yards` in place of `course_sets`
  and `course_set_yards`. A backup made by v0.4.0 to v0.6.0 (schema v7 or v8)
  still reads, converted the same way ([`BACKUP_FORMAT.md`](BACKUP_FORMAT.md)).

### Internal

- **`rounds` is rebuilt without its two dead set columns.** `course_set_id`
  gives way to `tee_set_id` + `pin_set_id`. The legacy free-text
  `rounds.tee_set` label is dropped in the same rebuild: no build ever wrote
  it, and next to `tee_set_id` it only confused things. `CourseSetDao` becomes
  `YardageDao`. A tee set and a pin set can only pair on one course, and a
  round's sets must be on the round's course. SQL can't express either rule
  across parent tables, so the DAOs refuse a mismatch with an `ArgumentError`
  and a backup's `validate()` reports one. Splitting the old sets is one
  frozen function that the migration and the v8 backup upgrader both call
  (`lib/data/upgrades/split_yardage_sets.dart`), so a restored v8 backup and
  an upgraded v8 database hold the same rows. An old backup is checked against
  its own version's table list before it is upgraded. The tables the upgrade
  rebuilds are read strictly, with their counts checked before the split. The
  v0.6.0 golden files are frozen as `backup_v1_schema8_*.json` and tested to
  still read. Tests 770 → 829.

## [0.6.0] - 2026-10-11

A release that gives the putts their shots back ([#125]). v0.5.0 put every
shot beside the stats it decides except the putts, which it cut down to a bare
count. Now each putt is a row of its own under **Putting**, measured the way
golf games show it on the green: in feet. Add or remove a putt and the count,
the score and the up & down follow.

Putts you measured before this were in yards, the only unit a shot had, and
they come across converted: a 4-yard putt now reads 12 feet. Only putts are
converted; every other shot keeps its yards. One thing can't come back: v0.5.0
dropped the distances from a hole's putts whenever that hole was re-saved, so
those putts arrive without one.

The schema **moves**, v7 → v8, and a migration runs on every device that
installs this. It adds the putt distance column and converts the putts in
yards, in a single step that either finishes or leaves the database as it was.
Backups made by v0.4.0 and v0.5.0 still read, their putts converted the same
way. The release is a **minor**, both for the `### Changed` entries below and
because the schema rose.

### Changed

- **Each putt is a shot again, entered under Putting, with its distance in
  feet.** v0.5.0 reduced the putts to a bare Putts count. Now every putt has
  its own row in the **Putting** section — "Putt 1 · Shot 3" — asking for its
  distance to the hole in feet, the unit golf games show on the green. **Add
  putt** and each row's remove button replace the Putts stepper, so the putts
  count is simply how many rows there are; the last putt is badged Holed, and
  with no putts the section says the hole was finished from off the green. The
  score, up & down success and sand save follow the putts as before. "Count it
  as a putt", offered for a shot played from the green, now moves that shot to
  the first putt row and carries its distance across in feet. Holes saved
  before this keep their putts and still read "Saved"; a putt you saved with a
  distance in yards shows it converted to feet.

- **The schema moves to v8, and putts you measured in yards become feet.**
  Putt distances are stored in a new `hole_shots.distance_feet` column. The
  migration that adds it on upgrade also converts every putt you saved with a
  distance in yards — 4 yd becomes 12 ft — and clears the yards, so each putt
  has the one distance the form shows. A putt is what the form shows under
  Putting: the putter or from-the-green shots a hole ends on, as many as its
  putts count. Every other shot keeps its yards. A hole you re-saved in v0.5.0
  had its putts' distances dropped then (v0.5.0 rewrote putt rows without
  them), so those putts come through blank. Backups move with it: new ones
  carry `distance_feet` on every shot, and a backup made by v0.4.0 or v0.5.0
  (schema v7) still reads, its putts converted the same way
  ([`BACKUP_FORMAT.md`](BACKUP_FORMAT.md)).

### Internal

- **Backup upgraders run on the file's raw rows**, before they are decoded:
  a decoded row already has today's columns, so checking a v7 row against them
  refused the file for being old rather than broken. The v7 → v8 upgrader gives
  every shot a null `distance_feet`, refuses a v7 file that already has one,
  and converts putts in yards exactly as the migration does: which rows are
  putts is decided by one frozen function both call
  (`lib/data/upgrades/putts_in_feet.dart`), so a restored v7 backup and an
  upgraded v7 database hold the same rows. The v0.5.0 golden files are frozen as `backup_v1_schema7_*.json` and tested
  to still read; the current goldens now include a putt measured in feet.
  Tests 729 → 770.

## [0.5.0] - 2026-10-10

A release about the one screen you use on every hole. Entering a hole used to
mean filling in the stats, scrolling down to a shot list at the bottom, and
scrolling back up to make the two agree. Now each shot sits beside the stats it
decides — the tee shot with "Fairway hit?", the approach shots with GIR, bunker
and up & down, and the putts as the Putts count — so a hole is one pass down
the card. The form fills in what follows from what you have entered, and
leaves alone anything you override.

The other half is that **Save Hole now checks the hole first**. A score that
isn't the shots plus putts plus penalties, an unanswered tee shot, or a shot
list that can't have happened is refused with the reason above the button, and
the common fixes are one tap ("Add N shots", "Make the score N"). Holes you
saved before this keep their values and still read "Saved".

The schema does **not** move: still v7, and no migration runs on upgrade, so
upgrading is in place as usual. The release is a **minor** because of the
`### Changed` entry below.

### Changed

- **Hole entry follows the hole, and checks it before saving.** Each shot is
  now entered beside the stats it decides, so filling in a hole is one pass
  down the card instead of scrolling between the stats and a shot list at the
  bottom: the tee shot sits under **Tee shot** with "Fairway hit?" (or "Green
  hit?" on a par 3), approach shots sit under **Approach & around the green**
  with GIR, bunker and up & down, and putts are simply the **Putts** count —
  each one a stroke, written out as shot rows when the hole is saved, so the
  putts and the shot list can no longer disagree.

  The form fills in what follows from what you have entered. Answering "Fairway
  hit? Yes" lays out shot 2 played from the fairway ("No" from the rough), and
  changing the answer moves it. The score counts itself from the shots, putts
  and penalty strokes; GIR follows the strokes it took to reach the green; an
  up & down attempt with one putt or a chip-in is marked a success, and two
  putts clears it; a shot from a bunker turns on "Bunker visited", and getting
  down in one putt from there is a sand save; marking a shot as a penalty counts
  the stroke. Each of these is re-worked only when something it depends on
  changes, so a value you override stays put. The form no longer suggests a
  club, and only the tee shot arrives with a distance (the hole's yardage).

  **Save Hole now refuses a hole that doesn't add up**, and says why above the
  button: the tee shot's result must be recorded; the score must equal the
  shots plus putts plus penalty strokes; there can't be more shots marked as a
  penalty than penalty strokes; with no putts, the last shot must be the one
  that went in; and a par-3 tee shot that found the green can't be followed by
  more shots. A score that disagrees offers "Add N shots" or "Make the score N".
  A shot played from the green, or an up & down attempt on a green hit in
  regulation, is flagged but doesn't block. Holes saved before this keep their
  values and still read "Saved"; one whose score is ahead of the shots it has
  recorded shows the gap, and "Add N shots" closes it in one tap. No schema
  change.

## [0.4.0] - 2026-10-04

The first release since v0.3.1 that changes the app itself, and the reason is
to stop a lost phone taking your rounds with it. **Settings → Back up your
data** writes every course, yardage set, round, hole, shot and event to one
plain JSON file, and hands it to the share sheet on Android or a Save-as
dialog on Windows. You decide where the file goes: nothing is uploaded, nothing
runs on a schedule, and Golfy asks for no new permissions. Before handing the
file over, Golfy checks that it reads back as the data it came from.

This is half of a pair. Restoring a backup is [#70], and it is not in this
release. The file format is fixed and documented now, though, and the code
that reads it back already ships and is tested, so a backup made today is one
the restore will accept. Make one now; you will be able to use it then.

The Settings screen this adds, reached from the navigation drawer, is also
where the about and support sections from [#72] will go.

The schema does **not** move: still v7, and no migration runs on upgrade, so
upgrading is in place as usual. The release is a **minor** because of the two
`### Added` entries below. It is also the first Golfy build with native-code
plugins (`share_plus`, `file_selector`, `package_info_plus`), which is worth
knowing if a sideloaded install behaves differently from v0.3.3.

### Added

- **Your data can leave the device, on your terms** ([#69]): **Settings → Back
  up your data** writes everything Golfy holds — every course and yardage set,
  every round, hole, shot and event — to a single text file, and hands it to
  the share sheet on Android or a Save-as dialog on Windows so *you* choose
  where it goes. Nothing is uploaded, nothing happens on a schedule, and no
  permission is asked for: the file reaches Drive, Files or your own inbox
  because you sent it there. The tile counts what is about to be saved before
  you tap, so a backup that looks wrong looks wrong early, and the bar at the
  bottom names the file it made. A lost or replaced phone has been the one way
  to lose weeks of rounds, and this is the end of that.

  The file is plain, pretty-printed JSON with the column names the database
  itself uses, so you can open it and read your own rounds — and a program
  written years from now can too. It carries the data version it was written
  at, counts for every table, and each row's id, which is what keeps every hole
  attached to its round and every shot to its hole when it goes back. Golfy
  checks the file reads back as the data it came from *before* handing it over,
  so a backup it could not itself import is never produced.

- **A Settings screen**, reached from the navigation drawer ([#69]). It carries
  the backup action and the short version of why Golfy needs one. App version,
  open-source licences, the privacy policy and a support link are [#72]'s and
  land here as further sections.

### Internal

- **The backup format is a contract, and it is written down**
  ([`BACKUP_FORMAT.md`](BACKUP_FORMAT.md)): the envelope and its two version
  numbers, table order, key naming, how ids and nulls are treated, the
  integrity and referential checks, what a reader must accept and must refuse,
  and the restore procedure the format was designed around. Two golden files
  are committed beside it — one minimal, one the whole seeded fixture — and the
  larger is the input [#70]'s restore tests will read, so export and import are
  proven against the same bytes rather than two approximations of them.

- **Reading a backup ships with writing one** ([#69]). `BackupCodec.decode`
  and `BackupPayload.validate()` are complete and tested: decoding is total
  (either a whole payload or a refusal naming the table and row), and the
  referential check catches a file that is well-formed but describes an
  impossible database — before a restore touches anything. [#70] inherits a
  format already known to be readable and adds the database write-back and its
  UI. No Golfy build before this one can export, so no backup older than
  schema v7 can exist, and the upgrade-an-old-backup path the roadmap assumed
  is simply not needed.

- **Three guard tests exist to fail** (`app/test/data/backup/`): a ninth table
  added to the schema and not to the backup, a column added or renamed behind
  the file's keys, and a `schemaVersion` bump — each one turning a silent
  change to everybody's backups into a red test that says what to decide.
  Drift's `use_sql_column_name_as_json_key` ([`app/build.yaml`](app/build.yaml))
  is what makes a backup read like the schema's own snapshots; the column guard
  is what keeps it that way.

- **`share_plus`, `file_selector` and `package_info_plus`** are the project's
  first plugins with native code. Android has no save dialog available to
  Flutter at all — the Storage Access Framework returns a `content://` URI
  `dart:io` cannot write to — so a backup is written to the app's own cache and
  handed to the share sheet. That copy outlives the share sheet on purpose,
  because a receiving app may read it long after the sheet closes; each export
  sweeps the previous one out instead. Desktop uses a real save dialog.
  `flutter pub get` now regenerates the committed Windows plugin glue.

- **`cupertino_icons` 1.0.9 → 2.0.0** ([#118]), the one bump waiting on
  `deps/patch`, merged up to `master` ahead of this cut ([#120]). The app's
  code never references `CupertinoIcons`, so the major version changes nothing
  you can see.

- **The backup golden files are pinned to LF**
  ([`.gitattributes`](.gitattributes)). The exporter writes `\n` on every
  platform, but `core.autocrlf` checked the goldens out as CRLF on Windows,
  so both golden tests failed locally while CI on Linux passed.

## [0.3.3] - 2026-10-02

Another release with nothing in it for the app. Golfy behaves exactly as v0.3.2
did — the same screens, the same data, the same schema at v7 — and upgrading is
in place as usual. What it carries is a toolchain that had stopped resolving:
on the pinned 3.44 SDK `flutter pub get` could not solve at all once `analyzer`
13.1 wanted a `meta` that `flutter_test` pinned away, and both CI jobs were
dying before they analyzed or built anything. The pin moves to 3.47.6, which
unwedges it; the rest of the batch is what that upgrade made it sensible to
take alongside.

It is also the first time `deps/patch` has been emptied. Eight pull requests
collected there under their own CI run — four GitHub Actions majors, the Gradle
trio, the drift trio and the pub group — and merged up to `master` as a single
batch, which is the procedure v0.3.2 shipped and nothing had yet exercised.

Two of those bumps needed a hand afterwards, and both are the kind that stay
green while being wrong. [#111] moved the drift lock without regenerating the
committed `*.g.dart`, leaving the checked-in output as drift 2.33 produced it,
and declared `drift_dev` a minor behind its siblings where the caret hid it.
Codegen has been re-run, the constraint realigned, and that divergence is now a
test instead of a warning in a README. The AGP 9.4.1 / Kotlin 2.4.20 /
Gradle 9.8.0 trio was read against the new SDK with
`flutter analyze --suggestions`, which is the check a green build does not
make for you.

The schema does **not** move: still v7, and no migration runs on upgrade. Under
the project's own rules this is a **patch** and, like v0.3.2, only just —
everything below is `### Internal`, which contributes no bump, so the
calculator reports that no release is needed and offers the patch for exactly
this case.

### Internal

- **The pinned Flutter SDK moves from 3.44.0 to 3.47.6** ([#114];
  [`flutter-build.yml`](.github/workflows/flutter-build.yml),
  [`release.yml`](.github/workflows/release.yml)): three one-line pins, but the
  reason was not staleness. `flutter_test` in the 3.44 SDK pinned `meta` to
  exactly 1.18.0, `analyzer` 13.1+ wants `meta ^1.18.3`, and `build_runner`
  2.16.1 wants `analyzer >=13.3.0` — so `flutter pub get` could not solve at
  all, and both CI jobs died before analyzing or building anything. No 3.44.x
  release relaxed that pin, so [#112] had to hold `build_runner` at `^2.15.0`
  to get green. On 3.47.6 `flutter_test` asks for `meta ^1.18.3` instead; the
  lock now resolves `meta` 1.19.0 and `analyzer` 13.3.0, and
  [`app/pubspec.yaml`](app/pubspec.yaml) carries `build_runner: ^2.16.1` again
  with the hold removed. The Dart floor moves `^3.12.0` → `^3.13.0` to match:
  the caret on 3.12 would still have admitted 3.13, but it would have let a
  checkout on the old SDK resolve a lock it cannot build.

- **Windows renders through Impeller** (no repo change): 3.47 makes Impeller the
  default renderer on Windows, and
  [`windows/runner/main.cpp`](app/windows/runner/main.cpp) is the stock template
  with no opt-out, so the switch is taken rather than deferred — Flutter has
  said the opt-out goes away in a later release. Smoke-tested by hand on
  Windows: launch, first paint, the Events list, navigating into an event, and
  Material cards, icons and text at several sizes, all with no artifacts.

- **The Android toolchain is validated rather than assumed**
  ([`app/README.md`](app/README.md)):
  [`.github/dependabot.yml`](.github/dependabot.yml) has long said that the AGP
  and Kotlin versions are coupled to the pinned SDK, that a green CI run does
  not prove the combination is supported, and that these are best taken
  alongside a Flutter upgrade. This is that upgrade, so the AGP 9.4.1 /
  Kotlin 2.4.20 / Gradle 9.8.0 trio waiting on `deps/patch` was checked against
  it: `flutter analyze --suggestions` reports the Java/Gradle/AGP/KGP
  combination compatible, and a debug APK builds and still declares
  `com.golfy.golfy_app.debug`. That command is now written down in
  [`app/README.md`](app/README.md) as the check CI cannot make for you. The
  built-in-Kotlin and `newDsl` flags that 3.47's own templates now default to
  are deliberately left off; adopting them removes the plugin declaration
  Dependabot watches, which is its own decision.

- **Generated drift code caught up with drift 2.35**
  ([`database.g.dart`](app/lib/data/database.g.dart)): the drift bump in [#111]
  changed only the pubspec and the lock, so the committed output was still what
  drift 2.33 produced — exactly the mismatch
  [`app/README.md`](app/README.md) warns about when it says a merged drift bump
  still needs a local `build_runner` pass. Re-running codegen here settled it:
  alias names are now computed at generation time rather than by a runtime
  helper, and `readTable` calls carry explicit type arguments. Behaviour is
  unchanged, and the migration suite still validates every v1→v7 step against
  the committed schema snapshots. The same bump left `drift_dev` declared at
  `^2.33.0` while `drift` and `drift_flutter` moved, which the caret quietly
  papered over — it still resolved 2.35.0, so nothing was broken, but the
  declared constraint no longer said what the rule says it should. Realigned to
  `^2.35.0`; the lock does not move.

- **The drift trio rule is now a test rather than a comment**
  ([`test/tool/drift_trio_test.dart`](app/test/tool/drift_trio_test.dart)):
  grouping the three packages in [`.github/dependabot.yml`](.github/dependabot.yml)
  gets them into one pull request, but it does not guarantee all three
  constraints are rewritten — in [#111] Dependabot updated the lock for all
  three and said in its own commit message that it had updated `drift_dev`,
  while leaving `drift_dev` declared a minor behind. Nothing failed, which is
  the problem: the caret covered for it until the SDK upgrade happened to read
  the file. Three checks now run with no git, network or sqlite: `drift` and
  `drift_dev` resolve to the same version, they are declared with the same
  constraint, and all three are present in both files. The second is the one
  that catches [#111], and it was confirmed to fail on that exact state before
  being committed. Test count moves 585 → 588.

- **`flutter analyze` ignores build and platform directories**
  ([`analysis_options.yaml`](app/analysis_options.yaml)): Flutter's tooling
  writes this `analyzer: exclude:` block itself on `pub get` from 3.47 onwards.
  It narrows what is analyzed and relaxes no lint; `lib/` is untouched, so the
  committed `*.g.dart` files are still covered. Kept, with a comment saying
  where it came from so the next person does not delete it as noise.

This release stays `### Internal` on the test that matters — would someone
running the installed APK notice? The released artifact is an APK, Impeller was
already the default on Android, and the app behaves as it did. If a Windows
build ever ships as a release artifact, that reasoning needs revisiting.

## [0.3.2] - 2026-09-27

A release with nothing in it for the app. Golfy behaves exactly as v0.3.1 did —
the same screens, the same data, the same schema at v7 — and upgrading is in
place as usual. What it carries is the machinery around releases: dependency
updates that collect on their own branch under CI, and a procedure that works
out the next version number from what actually merged rather than leaving it to
be typed into four files and hoped for.

It is cut deliberately rather than left to ride the next feature. Rules that
decide a version only start protecting anything once they are on a tag CI has
checked, and the same goes for the guard that now rejects a tag disagreeing
with [`app/pubspec.yaml`](app/pubspec.yaml) — the mismatch that let `v0.0.3`
ship a pubspec still reading `0.0.2+4` and go unnoticed for eight releases.

Under those same rules this release is a **patch**, and only just: everything
below is `### Internal`, which contributes no bump at all, so the calculator
reports that no release is needed and offers the patch for exactly this case.

No schema change — the data model is untouched at v7.

### Internal

- **Dependabot keeps dependencies current without touching `master`**
  ([`.github/dependabot.yml`](.github/dependabot.yml)): weekly checks of the
  Dart packages in [`app/pubspec.yaml`](app/pubspec.yaml) and the actions used
  by both workflows, monthly for the Android Gradle plugins. Every pull request
  it opens is based on the standing **`deps/patch`** branch rather than
  `master`, so bumps accumulate there under CI and are merged up as one batch
  when a patch release is cut — a dependency change never lands untested
  alongside feature work, and one merge rather than one per package moves them
  all. Patch and minor updates are grouped into a single pull request per
  ecosystem and majors are raised individually; `drift`, `drift_dev` and
  `drift_flutter` are grouped together because the committed `*.g.dart` files
  are generated by that set, and a split bump would build against mismatched
  codegen. Dependabot **security** updates are deliberately exempt from this
  routing and continue to open against `master` directly, since a CVE fix
  should not wait in an integration branch for a release.

- **CI now covers the integration branch**
  ([`flutter-build.yml`](.github/workflows/flutter-build.yml)): `deps/patch` is
  a trigger branch for both `push` and `pull_request`, so Dependabot's pull
  requests are analyzed, tested and built like any other, and the branch is
  rebuilt as each bump merges into it. The workflow's previous
  `branches: [master]` filter matched on the *base* branch, so without this
  every one of those pull requests would have arrived carrying no checks at all.

- **The next version is derived from what merged, not chosen up front**
  ([`RELEASING.md`](RELEASING.md),
  [`app/tool/next_version.dart`](app/tool/next_version.dart)):
  `dart run tool/next_version.dart` reads this `## [Unreleased]` section and
  the drift `schemaVersion`, then prints the bump they imply along with its
  reasons — `### Fixed` or `### Security` alone is a patch, `### Added` or
  `### Changed` is a minor, a schema bump floors it at minor because a
  migration then runs on every device, and `### Removed` or a `**BREAKING:**`
  entry is a major once the project is past 1.0. Pre-1.0 that major is clamped
  to a minor, since `0.y.z` → `1.0.0` is a deliberate call ([#79]) rather than
  something a rule should make on its own — but the suppressed reason is still
  printed, so nothing about the decision is hidden. A `v*` tag push now fails
  before it builds anything when the tag disagrees with
  [`app/pubspec.yaml`](app/pubspec.yaml), when `CHANGELOG.md` carries no
  heading or link reference for it, when the build number does not increase,
  or when a schema bump arrived as a patch. That first check is not
  hypothetical: `v0.0.3` was tagged on a commit whose pubspec still read
  `0.0.2+4`, and nothing noticed for eight releases ([#86]).

- **`### Internal` is where work no app user can see now goes.** The two
  entries above are the motivating case — a Dependabot config and a CI branch
  filter, filed under `### Added` and `### Changed`, which would have counted
  as user-facing features and bumped the minor version for a release that
  changes nothing about the app. The test is simply whether someone running
  the installed APK would notice: CI, tooling, tests, docs and
  behaviour-neutral refactors would not, so they contribute no bump. A
  performance fix that is actually felt still belongs under `### Fixed`
  ([#86]).

## [0.3.1] - 2026-09-14

A bug-fix release for per-shot entry. Saving a hole a second time — the normal
way a hole is entered, a shot at a time as you play it — wrote its shot list
against the wrong row, so the edit you had just made was discarded and, when the
id it landed on belonged to another hole, that hole's own shots were overwritten
with it. The blank shot row the form leaves for you to fill in was also deleted
on save, taking the hole's shot numbering with it. Between them they made a par
3 whose tee shot misses the green almost impossible to record: the row for the
recovery shot disappeared, and the lie typed into it did too.

No schema change — the data model is untouched at v7, and upgrading is in place
as usual.

### Fixed

- **Editing a hole you already saved no longer discards the edit**: the second
  save of a hole ran as an `ON CONFLICT ... DO UPDATE`, and the row id it handed
  back came from `last_insert_rowid()` — a counter SQLite only advances on a real
  *insert*. Once the hole had shots, that counter still named one of the
  `hole_shots` rows the previous save wrote, so the shot list was attached to
  whatever row happened to carry that id: another hole (which silently lost its
  own shots and gained these) or none at all (a foreign-key error that rolled the
  whole save back). Either way the change vanished on save. The id is now read
  back with `RETURNING`, which names the row that was actually written. The same
  fix is applied to the per-hole course template and yardage upserts, which had
  the same stale-id trap.
- **A shot you haven't filled in yet survives the save**: an all-blank shot row
  was dropped wherever it sat in the list, so saving mid-entry deleted the row
  and renumbered every shot after it — the putt entered as shot 3 came back as
  shot 2. A par 3 hits this the moment the tee shot misses the green: nothing
  about the hole says where the ball finished (there is no fairway flag on a par
  3, and GIR is off), so the suggested row is deliberately blank and is exactly
  the row that disappeared. Blank rows are now dropped only from the end of the
  list, which is still the "tapped Add shot and left it" case.

## [0.3.0] - 2026-09-13

Per-hole data entry stops being two different apps. Setting a course up and
playing it were the same task — fill in eighteen holes — with different
controls, different save semantics and, in the course editor's case, no sense of
progress at all. Course setup now uses the round form's own idioms, lives on one
screen instead of three, and can be corrected from inside a round: you learn a
course's real par, yardages and stroke indexes while playing it for the first
time, and acting on that no longer means leaving the round.

Shot entry stops ignoring what the hole already knows. A hole card captures par,
yards, score, putts and the fairway / green / bunker flags, and those imply most
of the shot sequence — so shots arrive pre-filled, can be built from the score in
one tap, and quietly flag it when they disagree with the scoring fields. Every
suggestion is a starting point; shots stay optional and nothing is rewritten
behind you.

All of it ([#81]) without a schema change.

### Added

- **Shots that fill themselves in from the hole you just described** ([#81]):
  adding a shot no longer hands you four blank fields. The first shot is played
  from the `Tee` with the hole's full yardage still in front of it; after that
  each row chains from what the card already knows — a hit fairway puts the next
  shot on the fairway, a missed one in the light rough, and once the full swings
  implied by `score - putts` are used up the remaining rows become putts on the
  green. A **Build from score** button scaffolds the whole hole in one tap. The
  distance field is the distance *remaining to the pin*, so it steps down by the
  previous club's typical carry and suggests the club to play from what is left;
  typing a distance yourself fills an empty club but never replaces one you
  chose. Every suggestion is a starting point — shots stay optional, a shot-less
  hole still saves, and nothing is ever rewritten behind you.
- **Reconciliation notes when shots and the hole disagree** ([#81]): recording a
  bunker lie with "Bunker visited" off, a putts count the putter shots
  contradict, a fairway flag shot 2 disagrees with, a shot marked holed that
  isn't last, or more shots than the score allows now surfaces a quiet note under
  the Shots section. It warns rather than corrects — silently rewriting your
  entry could push the hole into a state the database rejects — and it never
  blocks a save. A partly-entered list is left alone: shots need not sum to the
  score, so stopping after the interesting ones stays a legitimate way to use the
  feature.
- **Build a tee box from one you already have** ([#81]): adding a yardage set can
  copy an existing set's eighteen yardages and shift them by a flat amount —
  "the blues, minus 20" — instead of retyping them. The copy lands in the editor
  as unsaved changes for review, because real tee boxes differ hole by hole and
  an offset is only ever an approximation.
- **Stroke index is enterable from the hole entry form** ([#81]): it sits in the
  Tee section with par and yards, where you read it off the same scorecard.
  Because it has no round-level column, it is the one field on that form that
  edits the course rather than the round — the helper text says so — and it
  saves whether or not "Update course as I play" is on, since gating it would
  make typing in the field do nothing. Entering one that another hole already
  uses is called out on the field: stroke index has to be a permutation of 1-18
  and a form showing one hole at a time cannot otherwise reveal the clash.
- **Add a yardage set while starting a round** ([#81]): the set picker in New
  Round now offers "Add new set…", matching the "Add new…" affordance the course
  and event pickers already have. A tee box you have not recorded yet no longer
  sends you out to the course editor and back. The new set can copy an existing
  set's yardages with an offset, and a set created blank is still useful —
  "Update course as I play" fills it in hole by hole as you enter the round.
- **It is obvious which yardage set a round used** ([#81]): the rounds list
  names it beside the date, and the hole entry form labels the yards field with
  it — "Yards · Blue tees" — so the number and its source appear together. A
  round with no set says so on the yards field, since that is why it arrived
  blank.
- **Fix the course while you are playing it** ([#81]): you learn a course's real
  par and yardages during the first round, and acting on that used to mean
  leaving the round, opening the course editor from the drawer, and coming back.
  The Hole Entry screen now has a course menu with **Update course as I play** —
  which keeps the template in step with each hole you save, and arms itself
  automatically when the course has no card yet — and **Edit this hole on the
  course**, a sheet showing the same per-hole card the editor uses. It is also
  the only place stroke index can be entered mid-round. Both write a single
  hole, so holes you have not reached keep whatever the course already has.

### Changed

- **Course setup now works the way hole-by-hole entry does** ([#81]): setting a
  course up and playing it were the same task with different controls — a
  dropdown here and a segmented button there for the identical 3/4/5 par choice,
  a progress strip on one screen and none on the other, par and stroke index on
  one screen with each tee box's eighteen yardages on another. There is now a
  single course editor: par (the same segmented control Hole Entry uses), stroke
  index, and the selected set's yardage together on one card per hole, with the
  chip strip and "Holes set: X / 18" counter carried over from the round form.
  It stays a scrolling list rather than a swipeable page per hole, because
  stroke index has to be a permutation of 1–18 and you cannot tell whether 7 is
  taken from a screen showing one hole.
- **The course card tells you what is unsaved** ([#81]): every hole carries a
  Saved / Unsaved chip, the nav chips mark the holes you have touched, and the
  save button reads "Save card · 3 unsaved" rather than an opaque "Save card".
  One save commits par, stroke index and every edited tee box in a single
  transaction, so a failure part-way through can no longer leave the course
  half-written while the screen claims otherwise. Backing out with unsaved edits
  now asks first.
- **Par and stroke index are visibly course-wide** ([#81]): they are shared by
  every yardage set — only yardages differ between tee boxes — so the editor and
  the mid-round sheet now say so rather than leaving a per-hole card that shows
  all three together to imply otherwise. Both remain editable while playing: par
  follows each hole you save, and stroke index through the course sheet.
- **A new course starts from a real layout** ([#81]): opening the editor on a
  course with no card pre-fills the standard par-72 arrangement — four par 3s,
  four par 5s, 36 out and 36 in — instead of eighteen par 4s. It arrives marked
  unsaved on every hole, so it is a starting point you accept rather than one
  you inherit, and nothing is written until you save.

### Fixed

- **A saved hole with shots no longer reads "Unsaved" forever** ([#81]): the
  saved-state snapshot was rebuilt from `hole_results` alone, which carries no
  shots, while the live draft was seeded with them — and hole equality compares
  the shot lists, so any hole with at least one shot looked permanently dirty the
  instant it was saved.
- **Shot dropdowns no longer show a deleted shot's values** ([#81]): shot rows are
  keyed by position, so removing one shifts every later shot's data up into a
  reused row. The club / lie / result controls seeded themselves once and never
  refreshed, leaving the removed shot's club on screen while the stored data was
  correct. They are now driven directly by the draft.

## [0.2.0] - 2026-09-07

Golfy's largest release yet. It completes the **Courses & yardage** milestone and
gives **Events** a home of their own. Courses gain reusable templates — a shared
par + stroke-index card plus any number of named yardage sets — that pre-fill
each new round, and every hole now records an ordered per-shot list (club,
distance, lie, result). Events graduate from a field on a round to a dedicated
tab with event-first navigation, become distinct per season, and carry a
per-event scoring summary surfaced on both the detail screen and the list tiles.
It ships schema versions **v5–v7**, each a migration-tested, data-preserving
upgrade.

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
- **Per-shot tracking** ([#22]): the Hole Entry form now captures an ordered
  **Shots** list per hole — each shot records its **club, distance, lie, and
  result** — replacing the old flat single-`teeClub` / drive / approach fields.
  Shots are optional and independent of scoring (`score` / `putts` stay
  authoritative). Adds a `hole_shots` table (cascading from `hole_results`) at
  schema **v7**, which also drops the three superseded flat columns
  (`tee_club`, `drive_distance_yards`, `approach_distance_yards`) via a
  table-rebuild migration that preserves every existing hole's scoring data.
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
- The **Events list tiles** now carry a compact scoring line ([#63]): an event
  with at least one scored round shows its **average score vs. par** and **best
  round to-par** (colour-banded like the detail card) next to the round count —
  e.g. `3 rounds · +2.0 · Best -3`. Events with no scored holes keep the plain
  count / "No rounds yet". Computed in-memory from the rounds stream the screen
  already watches, so the list opens no per-tile DB watcher and needs no new
  query.
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

[Unreleased]: https://github.com/aellington89/golfy/compare/v0.8.0...HEAD
[0.8.0]: https://github.com/aellington89/golfy/compare/v0.7.1...v0.8.0
[0.7.1]: https://github.com/aellington89/golfy/compare/v0.7.0...v0.7.1
[0.7.0]: https://github.com/aellington89/golfy/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/aellington89/golfy/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/aellington89/golfy/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/aellington89/golfy/compare/v0.3.3...v0.4.0
[0.3.3]: https://github.com/aellington89/golfy/compare/v0.3.2...v0.3.3
[0.3.2]: https://github.com/aellington89/golfy/compare/v0.3.1...v0.3.2
[0.3.1]: https://github.com/aellington89/golfy/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/aellington89/golfy/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/aellington89/golfy/compare/v0.1.4...v0.2.0
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
[#59]: https://github.com/aellington89/golfy/issues/59
[#63]: https://github.com/aellington89/golfy/issues/63
[#81]: https://github.com/aellington89/golfy/issues/81
[#79]: https://github.com/aellington89/golfy/issues/79
[#86]: https://github.com/aellington89/golfy/issues/86
[#69]: https://github.com/aellington89/golfy/issues/69
[#70]: https://github.com/aellington89/golfy/issues/70
[#71]: https://github.com/aellington89/golfy/issues/71
[#72]: https://github.com/aellington89/golfy/issues/72
[#111]: https://github.com/aellington89/golfy/pull/111
[#112]: https://github.com/aellington89/golfy/pull/112
[#114]: https://github.com/aellington89/golfy/issues/114
[#118]: https://github.com/aellington89/golfy/pull/118
[#120]: https://github.com/aellington89/golfy/pull/120
[#125]: https://github.com/aellington89/golfy/pull/125
[#127]: https://github.com/aellington89/golfy/pull/127
[#129]: https://github.com/aellington89/golfy/pull/129
[#130]: https://github.com/aellington89/golfy/pull/130
[#131]: https://github.com/aellington89/golfy/pull/131
[#133]: https://github.com/aellington89/golfy/pull/133
[#134]: https://github.com/aellington89/golfy/pull/134
