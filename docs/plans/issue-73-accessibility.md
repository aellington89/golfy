# Implementation plan — #73 Accessibility pass: semantics, tap targets, text scaling, contrast

## Context

#73 asks for six things:
- the app works with a screen reader;
- every control is at least 48 dp;
- layouts survive the largest font size;
- the score colours meet WCAG AA contrast;
- TalkBack can complete the core flows;
- there are tests for all of this.

Before this work there were 9 tooltips, no `Semantics` widgets outside
Settings (whose section titles became headings in #72), and one place that
adapted to text size: the score-distribution label column from #59. The
light-theme score colours failed AA.

**Approach.** The fixes go in layers, and each layer gets a test so it can't
quietly break later:
1. Fix the colours in one function.
2. Add pure functions that turn scores into spoken text.
3. Add semantics to the widgets that display scores and stats.
4. Add labels to unlabelled controls.
5. Remove the explicit compact density that shrinks tap targets.
6. Size layouts by measuring the text, as #59 did, instead of using fixed sizes.
7. Fix traversal order and announcements.

The guard is flutter_test's built-in accessibility guidelines, run on every
screen in both themes and at 2× text size. There are no schema, data or
dependency changes.

**Size: L.** About 20 files plus tests.

## Acceptance criteria, with corrections

1. Semantics labels on icon-only controls, and on score/stat widgets that mean
   something only through colour or a glyph.
2. Tap targets of at least 48 dp, and a sensible focus order.
3. No clipping or overflow at the largest system font size.
4. Score-to-par colours meet WCAG AA in light and dark.
5. TalkBack can complete: create round → hole entry → finish → scorecard →
   dashboard.
6. Accessibility widget tests.

Corrections:
- **The target version is out of date.** The issue says v0.5.0; v0.9.0 has
  shipped and the app is at `0.9.0+50`. The version is worked out at release
  time from the CHANGELOG headings (`RELEASING.md`). `### Added` and
  `### Changed` mean MINOR, so this ships in the next minor (v0.10.0).
- **Criterion 5 can't be one automated end-to-end widget test.** Widget tests
  here only check the first frame, because driving drift `.watch()` updates
  deadlocks the test binding (`app/README.md`, Testing). So criterion 5 is
  covered in two parts: semantics tests per screen, plus a manual TalkBack
  walkthrough.
- **"Largest font size" means Android's 200%.** The tests use a linear 2.0
  scale on a 360 dp screen. That's at least as strict as Android 14's
  non-linear scaling. Windows goes up to 225%, which gets a manual check.

## Scope

**Out of scope:**
- an in-app text-size or high-contrast setting;
- right-to-left layouts and localisation;
- iOS (no target in the repo);
- an `integration_test` setup;
- full Windows Narrator and keyboard support (smoke-tested only; TalkBack is
  the bar);
- a colour-blind palette beyond AA (the +/E/− text already carries the
  meaning).

## Current state (verified at `00c846d`)

### Contrast

Computed with Material's colour utilities (the algorithm behind
`ColorScheme.fromSeed`) for the app's green seed. "Card" means
`surfaceContainerLow`, the Material 3 card colour. AA for normal text is 4.5:1.

| Light theme | Before | On surface | On card | Now | On surface | On card |
|---|---|---|---|---|---|---|
| Under par | `green.shade700` #388E3C | 3.92 | **3.72 ✗** | #006E1C | 6.17 | 5.85 |
| One over | `amber.shade800` #FF8F00 | 2.18 | **2.07 ✗** | #8F4E00 | 6.15 | 5.83 |
| Two or more over | `error` #BA1A1A | 6.16 | 5.85 ✓ | unchanged | | |
| Text drawn in `outline` | #72796F | 4.28 | **4.06 ✗** | `onSurfaceVariant` | 8.87 | 8.41 |

Dark already passed: green.shade400 is 7.87/7.22, amber.shade400 is
12.16/11.17 and error is 10.96/10.06. The bar fills pass the 3:1 rule for
graphics (primary on its track is 4.98:1).

The `outline` text was the round row's yardage-set caption and the course
editor's yardage intro.

### What TalkBack couldn't read properly

| Where | What TalkBack heard | Fix |
|---|---|---|
| New round/event/course buttons | "Button" | Tooltip, e.g. "New round" |
| Round row | "+2", "E", "18/18" | "2 over par", "even par", "18 of 18 holes" |
| Scorecard hole card | "FW", "✓", "GIR", "✗", "U/D", "em dash", one cell at a time | One sentence per hole |
| Totals card, `± Par` | Label and value as separate stops | Merged, spoken forms |
| Dashboard stat rows and best round | Separate stops, "E", "em dash" | Merged label and value, spoken forms |
| Distribution bars | "Eagle", "12.5%", "3"; the bar itself silent | "Eagle: 3 holes, 12.5%" |
| Event tile and result badge | "+1.2", "T-3" | "average 1.2 over par", "tied for 3rd", "missed the cut" |
| Steppers (hole card, new and edit round dialogs) | "Button"; the value without its name | Tooltips, a labelled value, one shared widget |
| Club/lie "none" option | "em dash" | "None" |
| Hole chips | "4"; saved vs unsaved shown only by the icon | "Hole 4, saved" / "Hole 4, unsaved changes"; counter "4 of 18 holes saved" |
| Overflow menus (event detail, course editor) | Generic "Show menu" | "Event options", "Course options" |
| Section titles (hole card, dashboard, rounds event header) | Not headings | `Semantics(header: true)` |
| Renaming a tee/pin set | Only possible with a long press | Custom semantics action "Rename" |
| Course/event pickers and date fields | No button role | `Semantics(button: true)` |
| Swipe to delete a round | Not possible with TalkBack (the scorecard's Delete is the alternative) | Custom action "Delete round" |

### Tap targets

`VisualDensity.compact` on a control shrinks Material's padded tap target from
48 to 40 dp. It was set explicitly on five interactive controls: the hole
chips, the Penalty chip, Remove shot, Remove putt and the issue fix buttons.
The non-interactive status chips and `SwitchListTile` (still 48 dp tall) keep
it. Flutter's default theme already uses compact density and smaller targets on
desktop, so removing the overrides only changes Android.

### Large text (360 dp at 2×)

- Two-line app bar titles (Hole Entry, Scorecard, course editor) in a fixed
  56 dp toolbar.
- The hole chip strip at a fixed 80 dp, and its auto-scroll assuming 52 px
  chips.
- The shot header row: "Shot N", Holed, Penalty and delete in about 280 px.
- The shot and putt distance fields at fixed 96 and 140 px.
- The scorecard hole card: fixed 52 and 68 px columns and four stat cells in
  one row.
- The event tile subtitle, whose segments can't shrink.
- The event detail result header with "Not recorded".
- The round row: score, count and two 48 dp buttons squeezing the title.
- The dashboard's percentage column fixed at 60 px ("100.0%" breaks mid-word).

### Order and announcements

- The scorecard's app bar actions ran Delete, Edit scores, Edit details: the
  destructive action first.
- "Hole N saved" stayed up for 1 second.
- Changing hole announced nothing.

## Design

### 1. Colours

Light-theme constants in `score_color.dart`: under par `#006E1C`, one over
`#8F4E00`; dark unchanged. Both are tone 40, the lightness Material 3 uses for
`error` in light mode, so all three bands sit at about 6:1 and stay at 5:1 or
better even on `surfaceContainerHighest`. The amber keeps its orange hue, so
the yellow accent stays distinct from the one-over band (`app.dart`). The three
light bands share one lightness and differ only in hue; WCAG 1.4.1 still holds
because the text and labels carry the meaning. `avgScoreVsParColor` builds on
`scoreToParColor`, so averages are fixed too. `outline` text becomes
`onSurfaceVariant`. `golfyTheme` becomes public (`@visibleForTesting`) so tests
use the real theme.

### 2. Spoken-text helpers

Pure functions beside the existing formatters:
- `spokenRelativeToPar(int)`: "even par", "1 over par", "3 under par".
- `spokenSignedAverage(double?)`: same rounding as `formatSignedAverage`;
  "no data" for null.
- `spokenEventResult(Event)`: "won", "finished 2nd", "tied for 3rd",
  "missed the cut".
- `scoreName(int)`: the #59 names ("Bogey", "Double bogey", …) for one hole.

### 3. Semantics patterns

- Read-only cards and rows: `Semantics(container: true, label: <sentence>,
  excludeSemantics: true)`. The `Text` widgets and their keys stay, so
  `find.text` / `textOfKey` assertions still work.
- Values inside a tappable tile: `Text(..., semanticsLabel: spoken)`.
- Label + value rows: `MergeSemantics`.
- Section titles: `Semantics(header: true)`.
- Icon-only controls: always a `tooltip`.

A scorecard hole reads: "Hole 4, par 4. Score 5, bogey, 1 over par. Fairway
hit. Green in regulation missed. 2 putts. Up and down not attempted." A hole
with no score reads "Hole 4, not entered".

### 4. Shared stepper

The three − value + steppers become `lib/widgets/stepper_field.dart`: tooltips
"Decrease {label}" / "Increase {label}", the value one node with its label,
`onIncrease`/`onDecrease` for TalkBack's adjust gesture, and a live region so a
tap speaks the new number. Existing keys are passed in.

### 5. Tap targets

Remove the explicit compact density from the five interactive controls.

### 6. Large text: measure, don't fix

As in #59, sizes come from `TextPainter` at the current text scale; text size
is never capped.
- Two-line titles: a shared title widget and a `toolbarHeight` helper.
- `HoleNavBar`: takes a `TextScaler`, works out `preferredSize` from it, and
  scrolls the current chip into view rather than assuming its width.
- Shot header: the label and chips wrap; delete stays at the end.
- Club and distance fields stack above 1.3× text.
- Scorecard hole card: minimum widths, stat cells in a `Wrap`.
- Event tile subtitle and result header: `Wrap`.
- Dashboard percentage column: measured.
- Round row: score and count move into the subtitle above 1.3×.

### 7. Order and announcements

- Scorecard actions: Edit scores, Edit details, Delete.
- "Hole N" on the hole card is a heading and a live region, so changing hole
  announces it.
- The save message stays 4 s while TalkBack is on; 1 s otherwise.

### 8. Test harness (`app/test/a11y/`)

- `_harness.dart`: pumps a screen with the real theme, a brightness, a text
  scale and a size, on a seeded in-memory database.
- `guidelines_test.dart`: every screen in light and dark against
  `androidTapTargetGuideline`, `labeledTapTargetGuideline` and
  `textContrastGuideline`.
- `large_text_test.dart`: the same screens at 360 dp and 2.0.
- Semantics and traversal tests in the existing widget test files.

## Build order

One PR; each commit stays green, and every guideline joins the harness in the
commit that fixes what it checks.

1. Score colours meet AA, with a contrast unit test.
2. Spoken helpers, with unit tests.
3. Accessibility harness plus `textContrastGuideline`.
4. Semantics on score and stat displays.
5. Labels on controls, plus `labeledTapTargetGuideline`.
6. Tap targets, plus `androidTapTargetGuideline`.
7. Large-text layouts, plus `large_text_test.dart`.
8. Order and announcements, with traversal tests.
9. CHANGELOG, README, this plan's "What was built", `+build`.
10. Manual pass before merge.

## Risks

| Risk | Mitigation |
|---|---|
| Existing tests depend on exact colours or text nodes | Colour expectations updated in step 1; semantics wrappers don't move widgets or keys. |
| `textContrastGuideline` flags text dimmed on purpose | The guideline skips disabled controls; anything else wrongly flagged gets a narrower finder, not a dropped check. |
| Taller controls and measured toolbars use space on short phones at 2× | The card body scrolls; scrolling beats clipping. |
| Test fonts are narrower than Roboto or Segoe UI (#59) | Sizes come from the real font at runtime; manual Windows check. |
| The live region on hole change isn't spoken reliably | Device check; `SemanticsService.sendAnnouncement` as the fallback. |
| Android's maximum display size narrows the screen below 360 dp | Manual check at maximum font and display size. |
| Rollback | No data or schema changes; revert the PR. |

## Testing

| Criterion | Verified by |
|---|---|
| 1. Labels | Semantics tests per widget, plus `labeledTapTargetGuideline` on every screen |
| 2. ≥48 dp and order | `androidTapTargetGuideline` on every screen, plus traversal tests |
| 3. Largest font | `large_text_test.dart` at 360 dp and 2.0, plus the manual check |
| 4. AA contrast | Contrast unit test against the real scheme, plus `textContrastGuideline` in both themes |
| 5. TalkBack flows | Semantics tests per screen, plus the manual walkthrough |
| 6. Tests | All of the above |

**Manual checklist** (Android 14+ device or emulator):
1. At maximum font size and display size, open every screen and look for
   clipping.
2. With TalkBack on: New round → fill in the dialog → start; on the hole card
   navigate by headings, use the steppers and save ("Hole 1 saved"); next hole
   ("Hole 2"); finish; the round row reads its score; the scorecard reads one
   sentence per hole; the Dashboard navigates by headings.
3. Google's Accessibility Scanner on each screen in light and dark.
4. Windows: 225% text size, Tab order on the hole card, a Narrator smoke test.

## Open questions

**Resolved (2026-10-30):** you took the recommendation on all four. They are
kept for the record.

1. **Light score colours:** tone 40 (#006E1C / #8F4E00), not
   `green.shade900`.
2. **Fixed-height chrome at large text:** grow it; never cap the text size.
3. **Spoken wording on scorecard holes:** the name plus the number ("bogey, 1
   over par"); totals and averages say "N over par".
4. **One PR,** with ordered commits.

## What was built, and where it departed from this plan

Steps 1–8 landed as eight commits; the manual pass (step 10) is in the PR
checklist. Every guideline and the large-text suite pass on every screen.

**Measured first.** Before fixing anything, a throwaway run put every screen
through all three guidelines and 2× text. Contrast already passed (after step
1); labels failed on seven screens, 48 dp on Hole Entry only, and 2× text
overflowed on seven. Two problems raised no error and were found by
measuring: the two-line app bar titles and the hole chip strip were clipped
silently. The fixes followed those results rather than the predictions, which
is where most departures come from.

Departures:

- **`textContrastGuideline` doesn't guard the score colours.** It skips text
  that a `ListTile` or `Card` merges into one semantics node, which is where
  every score is drawn: with the old colours put back it still passed. The
  unit test against the real scheme is the guard (it fails on the old
  shades); the guideline stays as a backstop for standalone text.
- **Card titles are headings in their own node** (`container: true`). As a
  bare annotation inside a `Card`, a heading took the card's other loose text
  into itself: the dashboard's ace note became part of "Score distribution".
- **The stepper's drawn label is out of the semantics tree.** The value node
  carries the name ("Score, 5"); with the decorator's label read too, TalkBack
  said "Score" twice.
- **Rename lives on the chip's label.** On a wrapper around the chip, the
  custom action became an unlabelled node of its own beside it, which
  TalkBack may not focus.
- **Par options read "Par 4"**, a small addition: a bare "4" was ambiguous in
  the course editor's column of cards.
- **The hole chips kept their compact density.** The guideline measured them
  at 48 dp already; only the Penalty chip, Remove shot / putt, the fix buttons
  and the dense club / lie dropdowns (24 dp) failed.
- **More rows stack past 1.3× than planned:** the scorecard hole card (stats
  under the hole and score) and each score-distribution row (label and share
  above the bar), as well as the shot's club and distance. The test font is
  much wider than Roboto or Segoe UI, so a row that only just fitted on a
  device overflowed in tests; stacking doesn't depend on the font.
- **The chip strip computes its height** from the text scale its screen
  passes in, since an `AppBar` reads `preferredSize` before building it; it
  can't measure itself. It scrolls to the current chip with
  `Scrollable.ensureVisible`, keeping the old estimate only for a chip not yet
  built.
- **No `+build` bump.** Since #86 the version is set when a release is cut
  (`RELEASING.md`), as #72 did; `dart run tool/next_version.dart` reports
  MINOR, 0.10.0.
- **The live region on "Hole N"** passes in tests; whether TalkBack speaks it
  on every hole change is the one thing left for the device check, with
  `SemanticsService.sendAnnouncement` as the fallback.
