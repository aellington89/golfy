# golfy_app

Flutter front-end for Golfy — video-game golf stat tracker. See the
[top-level README](../README.md) for the project overview, status, and
roadmap.

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

## Project layout

```
app/lib/
├── data/
│   ├── database.dart              # @DriftDatabase root
│   ├── database_provider.dart     # Riverpod provider for the DB
│   ├── repository.dart            # GolfyRepository (single facade)
│   ├── repository_provider.dart   # Riverpod providers for repo + streams
│   ├── tables/                    # Courses, Rounds, HoleResults (drift)
│   ├── daos/                      # CourseDao, RoundDao, HoleResultDao, DashboardDao
│   └── models/                    # RoundWithCourse, DashboardStats value classes
├── features/
│   ├── courses/                   # CoursePicker bottom sheet + AddCourseDialog
│   ├── rounds/                    # rounds list, new-round dialog, delete + active-round helpers
│   │   └── scorecard/             # read-only per-round scorecard (totals + per-hole cards)
│   ├── hole_entry/                # 18-card per-hole entry form + in-memory HoleDraft
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
│   ├── hole_result_dao_test.dart
│   └── dashboard_dao_test.dart    # aggregation correctness against a seeded fixture
├── features/                      # widget tests + pure-formatter unit tests (mirrors lib/features/)
│   ├── courses/                   # course_picker, add_course_dialog
│   ├── rounds/                    # rounds_screen, new_round_dialog, scorecard/
│   ├── hole_entry/                # hole_entry_screen, hole_card
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
- **DAO-layer invariants throw.** Three impossible states are validated at
  the DAO before the SQL hits the database:
  - `upDownSuccess` requires `upDownAttempt`
  - `sandSave` requires `bunkerVisited`
  - `par == 3` requires `fairwayHit == null` (par-3s have no fairway)
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
flutter test                           # everything (167 tests)
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
