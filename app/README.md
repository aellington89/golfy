# golfy_app

Flutter front-end for Golfy — video-game golf stat tracker. See the
[top-level README](../README.md) for the project overview and status.

## Prerequisites

- **Flutter** 3.x with Dart SDK ≥ 3.12 (`flutter doctor` should be all-green
  for the Windows and Android toolchains).
- **Windows**: Visual Studio 2022 with the "Desktop development with C++"
  workload (required by `flutter build windows`).
- **Android**: Android SDK + an emulator or physical device with USB
  debugging enabled.

## First-time setup

```powershell
flutter pub get
dart run build_runner build
```

`build_runner` generates the drift schema mixins (`database.g.dart`) and the
per-DAO mixins (`*.g.dart` next to each DAO source). Re-run it any time a
`@DriftDatabase` / `@DriftAccessor` / `Table` definition changes.

## Daily commands

```powershell
flutter test                            # all unit + DAO + widget tests
flutter analyze                         # static analysis
flutter run -d windows                  # desktop debug build
flutter run -d <android-device-id>      # Android debug build (flutter devices to list)
dart run build_runner watch             # regenerate on file change
```

On Android, debug builds (`flutter run`, `flutter build apk --debug`) install as
`com.golfy.golfy_app.debug` with a "(debug)" launcher label, while
`flutter build apk --release` installs the canonical `com.golfy.golfy_app`. The
two sandbox to separate databases and install side-by-side; if you still have a
pre-suffix combined debug install, clear it once with
`adb uninstall com.golfy.golfy_app`.

## Project layout

```
app/lib/
├── data/
│   ├── database.dart              # @DriftDatabase root
│   ├── database_provider.dart     # Riverpod provider for the DB
│   ├── repository.dart            # GolfyRepository (single facade)
│   ├── repository_provider.dart   # Riverpod providers for repo + streams
│   ├── tables/                    # Courses, Rounds, HoleResults, Events (drift)
│   ├── daos/                      # CourseDao, RoundDao, HoleResultDao, DashboardDao, EventDao
│   └── models/                    # RoundWithCourse (+ its event), DashboardStats value classes
├── features/
│   ├── courses/                   # CoursePicker bottom sheet + AddCourseDialog
│   ├── rounds/                    # rounds list, new-round dialog, delete + active-round helpers
│   │   └── scorecard/             # read-only per-round scorecard (totals + per-hole cards)
│   ├── hole_entry/                # 18-card per-hole entry form + in-memory HoleDraft
│   ├── events/                    # event-result formatter + edit-result dialog (#35)
│   ├── dashboard/                 # lifetime-stats screen
│   └── stats/                     # pure score/stat formatters + score-to-par colour bands
├── shell/                         # AppShell + tabIndexProvider (bottom-nav state)
├── widgets/                       # shared presentational widgets (EmptyState)
├── app.dart                       # MaterialApp + light/dark theme (ThemeMode.system)
└── main.dart                      # runApp + ProviderScope

app/test/
├── database_test.dart             # schema-level constraint tests (FK, UNIQUE, CHECK)
├── widget_test.dart               # AppShell smoke test
├── app_theme_test.dart            # light/dark theme + system-brightness switching
├── dao/
│   ├── _fixtures.dart             # shared in-memory DB fixtures
│   ├── course_dao_test.dart
│   ├── round_dao_test.dart
│   ├── event_dao_test.dart
│   ├── hole_result_dao_test.dart
│   └── dashboard_dao_test.dart    # aggregation correctness against a seeded fixture
├── features/                      # widget tests + pure-formatter unit tests (mirrors lib/features/)
│   ├── courses/                   # course_picker, add_course_dialog
│   ├── rounds/                    # rounds_screen, new_round_dialog, scorecard/
│   ├── hole_entry/                # hole_entry_screen, hole_card
│   ├── events/                    # event_result_format, edit_event_result_dialog
│   ├── dashboard/                 # dashboard_screen
│   └── stats/                     # score_format, score_color, stat_format
└── widgets/                       # shared-widget tests (empty_state)
```

## Architecture notes

- **No SQL leaks past `data/`.** UI code depends on
  [`GolfyRepository`](lib/data/repository.dart) and the Riverpod stream
  providers in [`repository_provider.dart`](lib/data/repository_provider.dart);
  it never touches DAOs or `GolfyDatabase` directly.
- **Reactive by default.** Every list view subscribes to a `Stream` produced
  by drift's `.watch*()` APIs; inserts and upserts trigger UI rebuilds with no
  manual invalidation.
- **Upsert preserves `id`.** `HoleResultDao.upsert` uses drift's
  `onConflict: DoUpdate(target: [roundId, holeNumber])` so re-saving a hole
  updates the existing row instead of deleting + reinserting. This keeps
  future referencing tables (notes, photos) safe.
- **DAO-layer invariants throw.** Impossible states are validated at the DAO
  before the SQL hits the database:
  - `HoleResultDao`: `upDownSuccess` requires `upDownAttempt`; `sandSave`
    requires `bunkerVisited`; `par == 3` requires `fairwayHit == null` (par-3s
    have no fairway)
  - `EventDao`: a result is exactly one of placed / cut / not-recorded — a
    missed cut can't carry a finishing position, and a tie requires one
- **Navigation is state, not a `Navigator` stack.** The bottom bar renders the
  tab named by [`tabIndexProvider`](lib/shell/tab_index_provider.dart); flows
  like "create a round → open Hole Entry" just set the index.
  [`activeRoundIdProvider`](lib/features/rounds/active_round_provider.dart) holds
  the round currently open on the Hole Entry tab — set on create or tap-to-resume,
  cleared on Finish Round or delete.
- **Hole Entry edits stay in memory until saved.** Each hole is a
  [`HoleDraft`](lib/features/hole_entry/hole_draft.dart) kept across `PageView`
  swipes; **Save Hole** upserts it via `HoleResultDao`. Course-yardage fields are
  stamped with placeholder defaults until
  [#22](https://github.com/aellington89/golfy/issues/22) adds real yardage entry.
- **Presentation logic is pure and shared.** [`features/stats/`](lib/features/stats/)
  holds widget-free helpers — `score_format` / `stat_format` (formatting) and
  `scoreToParColor` (colour bands) — so the rounds list, scorecard, and dashboard
  format and colour scores identically and unit-test without pumping a widget.
  `scoreToParColor` reads the scheme's `Brightness` so its green / amber bands
  stay legible in dark mode.
- **Theme is system-driven.** [`app.dart`](lib/app.dart) builds light + dark
  `ThemeData` from one deep-purple seed and sets `themeMode: ThemeMode.system`;
  there's no in-app toggle. Empty screens use the shared
  [`EmptyState`](lib/widgets/empty_state.dart) widget (icon + message + optional
  action) — reuse it rather than hand-rolling a centered column.

## Testing

Tests run against an in-memory drift database — no platform setup required.

```powershell
flutter test                           # everything (214 tests)
flutter test test/dao                  # DAO suites only
flutter test test/features             # widget + formatter suites only
flutter test test/database_test.dart   # schema-constraint suite only
```

The dashboard aggregation suite seeds a hand-designed 2-round, 36-hole fixture
and asserts each lifetime stat against pre-computed expected values — see
[`test/dao/dashboard_dao_test.dart`](test/dao/dashboard_dao_test.dart) for the
fixture spec.

> **Reactivity is covered at the DAO level, not in widget tests.** Widget tests
> pump a screen against a seeded in-memory database and assert the first frame —
> they do **not** drive live drift `.watch()` updates. Asserting a stream-driven
> rebuild inside `flutter_test` deadlocks the test binding and can leave
> `sqlite3.dll` locked on Windows, so verify reactive behaviour in the DAO suites
> instead.

## Generated files

`database.g.dart` and the per-DAO `*.g.dart` files **are committed**. drift's
generated code is deterministic, and committing it means CI / fresh checkouts
don't have to run `build_runner` before running tests.

If you see a `*.g.dart` diff after editing a table or DAO, that's expected —
run `dart run build_runner build` and commit the regenerated file alongside
your source change.

## Database migrations

The drift schema is versioned by `GolfyDatabase.schemaVersion`, and each version
is captured as a committed JSON snapshot under [`drift_schemas/`](drift_schemas)
so migrations can be generated and tested. The step-based `onUpgrade` in
[`database.dart`](lib/data/database.dart) is wired through the generated
[`schema_versions.dart`](lib/data/schema_versions.dart), and
[`test/migration_test.dart`](test/migration_test.dart) proves every upgrade.

To change the schema (add/alter a column, table, or index):

1. **Snapshot the current schema first**, before editing, so the *old* version
   is recorded:
   ```powershell
   dart run drift_dev schema dump lib/data/database.dart drift_schemas/
   ```
2. **Make the change** under `lib/data/tables/`, **bump** `schemaVersion` in
   `database.dart`, then regenerate drift code:
   ```powershell
   dart run build_runner build
   ```
3. **Snapshot the new schema**:
   ```powershell
   dart run drift_dev schema dump lib/data/database.dart drift_schemas/
   ```
4. **Regenerate the migration helpers** (runtime step helper + test verifiers):
   ```powershell
   dart run drift_dev schema steps drift_schemas/ lib/data/schema_versions.dart
   dart run drift_dev schema generate --data-classes --companions drift_schemas/ test/generated_migrations/
   ```
5. **Add the step** to `onUpgrade` in `database.dart`, e.g.:
   ```dart
   from2To3: (m, schema) async {
     await m.addColumn(schema.holeResults, schema.holeResults.someColumn);
   },
   ```
6. **Extend** `test/migration_test.dart` with a `migrateAndValidate(db, N)` case
   (plus a data-preservation case for anything that transforms existing rows),
   then run `flutter test test/migration_test.dart`.

The `drift_schemas/*.json` snapshots, `lib/data/schema_versions.dart`, and
`test/generated_migrations/` are **committed**, like the other generated files.

> The v2 schema carries an inert `rounds.migration_canary` column — a throwaway
> added to prove this pipeline end to end
> ([#24](https://github.com/aellington89/golfy/issues/24)). A later real
> migration may drop it. The v3 migration adds the `events` table plus the
> nullable `rounds.event_id` foreign key (`SET NULL` on delete) and its index
> ([#35](https://github.com/aellington89/golfy/issues/35)).

## Release signing

Debug builds are signed with the local Android debug key. **Release** builds are
signed with a real keystore configured via `android/key.properties` (git-ignored).
When that file is absent — CI, a fresh clone, or `flutter run --release` — the
release build falls back to debug signing, so it still succeeds; it just isn't
distributable.

To produce a real signed release build:

1. Generate a keystore once (then guard it — see the warning):
   ```powershell
   keytool -genkey -v -keystore golfy-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias golfy
   ```
2. Copy [`android/key.properties.example`](android/key.properties.example) to
   `android/key.properties` and fill in the alias, passwords, and `storeFile`.
3. `flutter build apk --release` now signs with that keystore — verify with
   `apksigner verify --print-certs <apk>`.

> **The release keystore is upgrade-critical.** Android only allows an in-place
> update (`adb install -r`, store updates) when the new build is signed with the
> **same** certificate. Lose or rotate the keystore and every existing install
> must be uninstalled first — wiping all user data. Back up `golfy-release.jks`
> **and** `key.properties` somewhere durable and reuse them for every release.

### CI release builds

The [`release.yml`](../.github/workflows/release.yml) workflow rebuilds this
signing config on the runner from four repository secrets —
`ANDROID_KEYSTORE_BASE64` (the base64-encoded `.jks`), `ANDROID_KEYSTORE_PASSWORD`,
`ANDROID_KEY_PASSWORD`, and `ANDROID_KEY_ALIAS` — so a `v*` tag push produces a
signed APK without the keystore ever entering the repo. **These secrets are not a
backup:** keep the offline copy of `golfy-release.jks` and its passwords, since
losing them blocks every future in-place update.

## Continuous integration

Every push and pull request to `master` runs
[`.github/workflows/flutter-build.yml`](../.github/workflows/flutter-build.yml):

- **Linux job** — `flutter analyze`, the full `flutter test` suite, and
  `flutter build apk --debug`, with the APK uploaded as a workflow artifact. The
  runner installs `libsqlite3-dev` so drift's `NativeDatabase` tests can load
  SQLite, and the committed `*.g.dart` files mean CI never runs `build_runner`.
- **Windows job** — `flutter build windows --debug` (build-only; the test suite
  runs once, on the Linux job).

Releases are handled by a separate workflow,
[`.github/workflows/release.yml`](../.github/workflows/release.yml): pushing a
`v*.*.*` tag runs the test suite, builds a **signed** release APK from the
`ANDROID_*` secrets (see [Release signing](#release-signing)), asserts it is
release-signed and under 20 MB, and attaches it to a **draft** GitHub Release to
publish after on-device validation. A manual `workflow_dispatch` run does the
same build but uploads the APK as an artifact instead of creating a Release — use
it to dry-run the signing pipeline before tagging.

The Flutter SDK is **pinned** (`flutter-version: 3.44.0`) for reproducible runs —
bump it in the workflow in lockstep with local Flutter upgrades, keeping it at or
above the Dart SDK floor in [`pubspec.yaml`](pubspec.yaml).
