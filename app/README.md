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
│   ├── rounds/                    # rounds list screen (placeholder)
│   ├── hole_entry/                # hole-by-hole entry screen (placeholder)
│   └── dashboard/                 # lifetime stats screen (placeholder)
├── shell/                         # AppShell with bottom navigation
├── app.dart                       # MaterialApp + theme
└── main.dart                      # runApp + ProviderScope

app/test/
├── database_test.dart             # schema-level constraint tests (FK, UNIQUE, CHECK)
├── widget_test.dart               # AppShell smoke test
└── dao/
    ├── _fixtures.dart             # shared in-memory DB fixtures
    ├── course_dao_test.dart
    ├── round_dao_test.dart
    ├── hole_result_dao_test.dart
    └── dashboard_dao_test.dart    # aggregation correctness against a seeded fixture
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

## Testing

Tests run against an in-memory drift database — no platform setup required.

```powershell
flutter test                           # everything
flutter test test/dao                  # DAO suites only
flutter test test/database_test.dart   # schema-constraint suite only
```

The dashboard aggregation suite seeds a hand-designed 2-round, 36-hole fixture
and asserts each lifetime stat against pre-computed expected values — see
[`test/dao/dashboard_dao_test.dart`](test/dao/dashboard_dao_test.dart) for the
fixture spec.

## Generated files

`database.g.dart` and the per-DAO `*.g.dart` files **are committed**. drift's
generated code is deterministic, and committing it means CI / fresh checkouts
don't have to run `build_runner` before running tests.

If you see a `*.g.dart` diff after editing a table or DAO, that's expected —
run `dart run build_runner build` and commit the regenerated file alongside
your source change.
