# Implementation plan — #59 Expand the dashboard score-distribution breakdown

## Context

The dashboard's **Score distribution** card puts every hole into five buckets: Eagles (-2 or better), Birdies, Pars, Bogeys, and Double+ (+2 or worse). A player who makes a hole-in-one, an albatross or a quadruple bogey can't see it. It is just counted as an "Eagle" or a "Double+". In a video golf game, extreme scores are more common than in real golf, so these hidden rows matter. #59 asks for the full set of golf scoring names, including an **Ace** (hole-in-one). An ace isn't its own `score - par` value; it overlaps Eagle, Albatross or Condor depending on par.

**Summary.** Each `ScoreBucket` gets a hole-in-one count from the existing distribution query. `groupScoreDistribution` maps the buckets to 10 fixed rows. The card shows Ace as a highlighted row that is also counted in its par-relative row, and it is left out of the percentage total. **Size: S–M.** There is no schema change, no migration and no codegen.

## Acceptance criteria (from the issue; no comments or linked PRs)

1. The card shows Ace, Condor, Albatross, Eagle, Birdie, Par, Bogey, Double bogey, Triple bogey and Quadruple+ bogey.
2. Rows are assigned by `score - par`, and Quadruple+ takes everything at +4 or worse.
3. Ace is detected by stroke count, and its overlap with Eagle/Albatross/Condor is handled and documented. *Correction: the schema has no `strokes` column. `hole_results.score` is gross strokes for the hole (`app/lib/data/tables/hole_results.dart:14-15`; the dashboard sums it as strokes per round at `dashboard_dao.dart:32-33`). So an ace means `score = 1`.*
4. `groupScoreDistribution` and its unit tests are updated.
5. `_countKeys`, the widget test keys and the dashboard widget tests are updated.
6. All rows render in a fixed order, at zero when there's no data.

## Scope

**In scope:** the distribution SQL, the `ScoreBucket` model, `groupScoreDistribution`/`ScoreCategoryCount`, the dashboard card's rows, keys, label width and ace highlight, the tests, and the CHANGELOG.

**Out of scope / non-goals:**
- Hiding rows that are zero (criterion 6 wants a stable display).
- Colouring bars by score band.
- A distribution on the event detail screen (`EventStats` has none).
- Detecting aces from `hole_shots`.
- Backup format changes (the distribution is derived data).
- Checking that score agrees with putts and penalties.

## Current state (verified)

- **Query:** `_scoreDistSql` returns `(score - par) AS bucket, COUNT(*) AS c`, grouped and ordered by bucket (`app/lib/data/daos/dashboard_dao.dart:64-69`). The rows are mapped to `ScoreBucket` at `dashboard_dao.dart:130-135`. It is one of three queries `_computeStats` runs each time the inert `SELECT 1` trigger fires on `hole_results`, `rounds` or `courses` (`dashboard_dao.dart:106-127`).
- **Model:** `ScoreBucket {scoreVsPar, count}` has value `==`, `hashCode` and `toString` (`app/lib/data/models/dashboard_stats.dart:71-92`). The comment at `dashboard_stats.dart:60-62` lists the old five labels.
- **Bucketing:** `groupScoreDistribution` is an if/else chain whose final `else` catches everything at +2 or worse, so no bucket is ever dropped. It always returns five rows in order, at zero when empty (`app/lib/features/stats/stat_format.dart:60-93`). `ScoreCategoryCount {label, count}` is at `stat_format.dart:39-58`.
- **UI:** `_ScoreDistributionSection` (`app/lib/features/dashboard/dashboard_screen.dart:221-256`):
  - It maps each label to a test key with `_countKeys[c.label]!`, so a label with no key crashes at runtime.
  - `maxCount` and `total` are both taken over every row.

  `_DistributionBar` (`dashboard_screen.dart:264-336`):
  - The label sits in a fixed **84 px** box (`:290-293`).
  - The bar fill is `count / maxCount` passed to `FractionallySizedBox.widthFactor` (`:284, 302`).
  - The percentage is `count / total` (`:316`).
- **Possible values:** `CHECK (par BETWEEN 3 AND 5)` and `CHECK (score >= 1)` (`hole_results.dart:12-15`) mean `score - par ≥ -4`. A condor (-4) is only possible as an ace on a par 5. An albatross (-3) is an ace on a par 4 or a 2 on a par 5. An eagle (-2) is an ace on a par 3, a 2 on a par 4 or a 3 on a par 5.
- **History:** the card came from #13 (`d934ba2`). #39 (`f270098`) added the percentages in the UI only. This is the first change to the shape of the distribution data since #13.
- **Tests:**
  - `app/test/features/stats/stat_format_test.dart:61-99` has three cases: central buckets, folding of extreme scores, and empty input.
  - `app/test/features/dashboard/dashboard_screen_test.dart:111-121, 139-157` checks the `dist_*` and `dist_*_pct` keys. It runs on an in-memory DB via `TestFixtures.upsertHole(rid, n, par:, score:)` from `app/test/dao/_fixtures.dart`.
  - `app/test/dao/dashboard_dao_test.dart:174-178, 300-318` checks `ScoreBucket` lists. None of those fixtures has `score = 1`.
  - The `dist_*` keys are used only in the screen and its test.

## Proposed design

### 1. Data: holes-in-one per bucket

```sql
SELECT (score - par) AS bucket,
       COUNT(*) AS c,
       SUM(CASE WHEN score = 1 THEN 1 ELSE 0 END) AS aces
FROM hole_results GROUP BY bucket ORDER BY bucket
```

```dart
class ScoreBucket {
  const ScoreBucket({required this.scoreVsPar, required this.count, this.aces = 0});
  final int scoreVsPar;
  final int count;
  /// Holes-in-one (`score == 1`) within this bucket; always ≤ [count].
  final int aces;   // added to ==, hashCode, toString
}
```

**Why this approach:**
- It stays one query and one consistent snapshot.
- `groupScoreDistribution` keeps its single input and stays pure.
- The overlap is visible in the data: an ace's bucket says which row it also counts in.
- Defaulting `aces = 0` keeps every existing `ScoreBucket(...)` call in the tests compiling and correct.

**Rejected:** a scalar `DashboardStats.holesInOne` taken from `_scalarSql`. It's equally simple, but it adds a second argument to `groupScoreDistribution` and leaves the ace-to-bucket link implied.

### 2. Bucketing: 10 fixed rows

`List<ScoreCategoryCount> groupScoreDistribution(List<ScoreBucket>)` keeps its signature and returns rows in this order:

| Row | Rule |
|---|---|
| Ace | Σ `b.aces` |
| Condor | `≤ -4` |
| Albatross | `-3` |
| Eagle | `-2` |
| Birdie | `-1` |
| Par | `0` |
| Bogey | `+1` |
| Double bogey | `+2` |
| Triple bogey | `+3` |
| Quadruple+ bogey | `≥ +4` |

- Condor uses `≤ -4`, not `== -4`, so the mapping stays complete and no bucket is ever dropped, as today.
- `ScoreCategoryCount` gains `final bool isAce` (default `false`, included in `==`). The UI needs to treat this row differently in two ways, and a typed flag avoids matching on the label:
  - it is left out of the percentage total;
  - it is highlighted.

  A record return `({int aces, List<ScoreCategoryCount> byPar})` was considered and rejected. It would split the UI's single loop for the sake of one row.

### 3. Overlap rule (criterion 3)

- An ace counts **both** in the Ace row and in its Eagle, Albatross or Condor row, as the issue recommends.
- **`total` excludes the Ace row.** It is the sum of the nine par-relative rows, which equals the number of holes. So the nine percentages still add up to 100%, and Ace % means "share of all holes that were aces".
- **`maxCount` includes the Ace row.** If it didn't, an ace count above every other row would give `widthFactor > 1` and the bar would overflow.
- Documented in three places: the `groupScoreDistribution` doc comment, the `ScoreBucket.aces` comment, and an on-card note (Open question 2).

### 4. UI (`dashboard_screen.dart`)

**Labels and keys.** Labels move to the issue's singular names, and `_countKeys` gets 10 entries:

`dist_ace`, `dist_condor`, `dist_albatross`, `dist_eagle`, `dist_birdie`, `dist_par`, `dist_bogey`, `dist_double_bogey`, `dist_triple_bogey`, `dist_quadruple_plus`

The `_pct` suffix pattern is kept.

**Totals.** `total` is now the sum over rows where `!c.isAce`. `maxCount` is still taken over all rows.

**Label width.** At `bodyMedium` size, "Double bogey" already fills the 84 px label box and "Quadruple+ bogey" is about 115 px, so the box grows to **120 px**. On a 360 dp phone the bar track then gets about 110 px.

**Ace highlight.** The Ace row is the first row and its bar fill uses `colorScheme.tertiary`. `_DistributionBar` gets an optional `Color? barColor` that defaults to `primary`. A `Divider` separates the Ace row from the nine par-relative rows, and a `bodySmall` `onSurfaceVariant` note under the rows reads "Aces also count in their Eagle, Albatross or Condor row." It carries the key `dist_ace_note`.

**Compatibility.** Nothing on disk changes: no schema bump and no migration. Both new fields have defaults, so the API changes are additive.

## Implementation steps

All work is on the standing `test` branch as one PR to `master`. The steps are in order because each depends on the one before; none can run in parallel.

1. **Data layer: holes-in-one per bucket.**
   - Files: `dashboard_dao.dart` (SQL plus `aces: r.read<int>('aces')`) and `dashboard_stats.dart` (field, `==`/`hashCode`/`toString`, and fixing the stale comment at `:60-62`).
   - New test in `dashboard_dao_test.dart`. Seed:
     - an ace on par 3, an ace on par 4 and an ace on par 5;
     - a par-5 eagle that isn't an ace (score 3);
     - a par-4 albatross can't happen without an ace, so use a par-5 score of 2 as the non-ace albatross.

     Expect `-4 {count 1, aces 1}`, `-3 {count 2, aces 1}` and `-2 {count 2, aces 1}`.
   - Existing assertions stay as they are thanks to the `aces = 0` default.
   - Depends on nothing.
2. **Bucketing: 10 rows.**
   - Files: `stat_format.dart` (`ScoreCategoryCount.isAce` and the new `groupScoreDistribution`) and `stat_format_test.dart`, with the existing three tests rewritten and new ones added (see Testing).
   - Depends on step 1.
3. **Dashboard card.**
   - Files: `dashboard_screen.dart` (keys, total and max, 120 px label box, `barColor`, divider, note) and `dashboard_screen_test.dart` (key renames, new widget cases).
   - Depends on step 2.
4. **Release bookkeeping.**
   - Add a `### Changed` entry under `## [Unreleased]` in `CHANGELOG.md`.
   - Bump `app/pubspec.yaml` `+build` from `0.8.0+45` to `+46`. The semver stays until a milestone is chosen (Open question 4).
   - Save this plan as `docs/plans/issue-59-score-distribution.md`, following the existing convention (`issue-69-…`, `issue-70-…`).
   - Do not run `dart format` (the repo isn't format-clean).

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Percentages stop adding up to 100%, or Ace makes the totals look wrong | `total` leaves the Ace row out, the on-card note explains it, and a widget test checks that the nine row percentages sum to the hole count. |
| Ace count is the highest row, so `widthFactor > 1` overflows | `maxCount` covers every row; there's a unit test for a fixture made only of aces. |
| A label with no key crashes through `_countKeys[...]!` | A widget test renders all 10 rows. A small unit test checks every `groupScoreDistribution` label has a key. The key map can't be reached from tests since it's private, so the screen test covers it by rendering. |
| Long labels wrap or overflow on narrow phones or with large text | The 120 px box plus `maxLines: 1, overflow: ellipsis` on the label. Smoke-test at 360 dp in the Windows build at a narrow window width. |
| A row is impossible today (score -5 can't happen) | Condor uses `≤ -4`, so the mapping stays complete if the par range ever widens. |
| Bad data, such as `score 1` with penalties above 0 | The issue says to count by `score` only. It's documented, not validated. |
| Performance | One extra `SUM(CASE…)` in a grouped query that already scans `hole_results`, so the cost is negligible. |
| Rollback | No data or schema change, so reverting the PR fully restores the old card. |

## Testing strategy

**Unit tests (`stat_format_test.dart`):**
- Empty input gives 10 rows at zero, in the expected label order, with only Ace marked `isAce`.
- Each `score - par` value from -4 to +6 maps to its row; +4, +5 and +6 all land in Quadruple+.
- Aces are summed from `b.aces` across buckets and are *also* in Condor, Albatross and Eagle. For example, `-2 {count 3, aces 1}` gives Ace 1 and Eagle 3.
- An extra check that a `-5` bucket lands in Condor.

**DAO test (`dashboard_dao_test.dart`):** the step 1 fixture runs through real SQL, so `score = 1` detection is tested against SQLite, not just in Dart. The empty-database case keeps `scoreDistribution` empty.

**Widget tests (`dashboard_screen_test.dart`), on the existing in-memory DB with `resizeTall`:**
- The "renders every stat" test is updated to the new keys, and all 10 `dist_*` and `_pct` keys are found.
- A new aces test seeds:
  - an ace on par 3, which counts as Ace and Eagle;
  - an ace on par 5, which counts as Ace and Condor;
  - a par-4 score of 8, which is Quadruple+;
  - a par-4 score of 4, which is Par.

  It then checks:
  - `dist_ace` is 2 and `dist_ace_pct` is `50.0%` (2 of 4 holes, not 2 of 6);
  - `dist_eagle` is 1, `dist_condor` is 1 and `dist_quadruple_plus` is 1;
  - the note is present.
- The "folds eagles and double-plus" test is replaced by one that checks Double, Triple and Quadruple+ are separate rows.
- Following the drift reactivity memory, these tests only check the first emission, not live `.watch()` updates.

**Regression:** other dashboard stats (Scoring, Accuracy, Around the green) are covered by the existing tests, unchanged. Run targeted commands rather than the full suite, because of the Windows dll-lock problem:
- `flutter test test/features/stats/stat_format_test.dart`
- `flutter test test/dao/dashboard_dao_test.dart`
- `flutter test test/features/dashboard/dashboard_screen_test.dart`

**Manual end-to-end:**
1. Run the Windows build.
2. Enter a round with an ace on a par 3, a 2 on a par 5 and a +4 hole.
3. Check the card's 10 rows, the ace highlight and note, that the percentages add up, and that there's no overflow in a narrow window.
4. Take a screenshot via PowerShell, as in the smoke-test memory.

| Criterion | Verified by |
|---|---|
| 1 Ten labels shown | Widget test finds all 10 keys; empty-input unit test checks label order |
| 2 `score - par` rules, Quadruple+ for +4 or worse | Unit test from -4 to +6; widget test for Quadruple+ |
| 3 Ace by stroke count, overlap documented | DAO test (`score = 1` in SQL); unit and widget overlap tests; doc comments plus on-card note |
| 4 `groupScoreDistribution` and its tests | `stat_format_test.dart` rewritten |
| 5 `_countKeys` and widget tests | `dashboard_screen_test.dart` updated with the new keys |
| 6 Zero rows and stable order | Empty-input unit test; widget test with sparse data still renders all 10 |

## Documentation and handoff

- **Developer:** doc comments on `ScoreBucket.aces`, `ScoreCategoryCount.isAce` and `groupScoreDistribution` (the overlap rule and why `total` excludes Ace). Fix the stale comment at `dashboard_stats.dart:60-62`. Add the CHANGELOG `[Unreleased]` entry. There are no config or environment changes, and `BACKUP_FORMAT.md` is unaffected.
- **End user:** Golfy has no user guide or help screen. The README mentions the score-distribution card only in release-status prose (`README.md:133`), which doesn't list categories, so nothing becomes inaccurate. The on-card note is the user-facing explanation of the overlap. No new material is proposed. When the release is cut, the CHANGELOG and README status get the usual update.
- **Maintainer:** to add or rename a row, change three things together:
  - the rule and order in `groupScoreDistribution`;
  - the label-to-key entry in `_countKeys`, which crashes at runtime if missing;
  - the widget test.

  The Condor row is effectively "aces on par 5" while `par BETWEEN 3 AND 5` holds.

## Open questions

**Resolved (2026-10-24):** you picked the recommended option on all four questions: 1 singular labels, 2 note always shown, 3 all holes, 4 bump `+build` only. The questions are kept below for the record.

1. **Label wording: singular, as the issue says, or plural, as today ("Eagles")?** The issue's table and criterion 1 use singular. *Recommend singular, exactly as the issue lists them.* Not blocking.
2. **How should the ace row be highlighted and the overlap explained?** *Recommend:* first row, `tertiary` bar colour, a divider below it, and a one-line note under the rows that is always shown. The alternative is to show the note only when aces are above 0, which saves space but makes the layout change with the data. Not blocking; it's easy to change in review.
3. **Should Ace % use all holes as its denominator, as recommended, or only holes on which an ace was possible?** Every hole has `score ≥ 1`, so every hole could be an ace, and all holes is the right denominator. *Recommend all holes, the same total as the other rows.* Not blocking.
4. **What version and milestone does this ship in?** It is user-visible and adds labels, so I'd treat it as `### Changed` in a v0.8.x patch, unless you group it into a minor milestone. *Recommend: leave the semver at 0.8.0, bump only `+build`, and decide at release time.* Not blocking.

## What was built, and where it departed from this plan

All four steps landed. The open questions were taken at their recommendations: singular labels (Q1), an always-shown note under the rows (Q2), Ace % over all holes (Q3), and only `+build` bumped (Q4).

Departures, all small:

- **Steps 2 and 3 are one commit.** On its own, step 2's relabelling would have made the dashboard crash on `_countKeys[c.label]!` until step 3 landed, so the two go together to keep every commit runnable.
- **The par-relative rows come from a const `score - par → label` map** (`_parRelativeLabels` in `stat_format.dart`), and each bucket is clamped to its first and last keys. This replaces a nine-arm if/else. It keeps both ends open (Condor at -4 or better, Quadruple+ at +4 or worse) as designed.
- **There is no "every label has a key" unit test.** `_countKeys` is private, so the widget test that renders all ten rows is the guard.
- **The label column is measured, not fixed at 120 px.** The Windows smoke test showed "Quadruple+ bog…" cut off: Segoe UI is wider than the widget-test font and Roboto, so 120 px wasn't enough. The label column is now the widest label as `TextPainter` lays it out in the ambient font and text scale, plus an 8 px gap, so every row shares one width. It is capped at 45% of the row, so a narrow phone at a large text size still leaves the bars room. Past the cap, a label ellipsises.
- **Two layout widget tests replace the planned manual narrow-window check.**
  - At desktop width, no label's `RenderParagraph` exceeds its line. This test fails against the old 120 px column.
  - At 360 dp and 2× text size, nothing overflows.
