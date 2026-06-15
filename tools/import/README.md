# golfy_import_tool

One-time converter that turns the historical `golf_stats.xlsx` spreadsheet into
a `golfy_import.json` payload for Golfy's **temporary** in-app importer
(issue [#33]). Standalone Dart CLI — not part of the Flutter app.

## Run

```sh
cd tools/import
dart pub get
dart run bin/main.dart --game-title "PGA 2K25" "/path/to/golf_stats.xlsx"
# → golfy_import.json written to the current directory
```

Options:

| Flag | Default | Meaning |
|---|---|---|
| `--game-title` | _(required)_ | `gameTitle` stored for every imported course. It is part of a course's unique key, so use the same value you use elsewhere in the app. |
| `--out` | `golfy_import.json` | Output path. |
| `--sheet` | `Per Hole Tracker` | Worksheet to read. |

Then transfer `golfy_import.json` to the device and load it from the Dashboard's
upload action (see the issue for the full build-then-strip flow).

## Source sheet

Reads the **"Per Hole Tracker"** worksheet; columns are matched by header name,
so column order does not matter. Rows are grouped into rounds by
`(Date, Course, Round)` — the `Round` column is what separates two 18-hole
rounds played on the same course and date.

| Sheet column | App field | Mapping |
|---|---|---|
| Date | `rounds.date` | datetime → ISO `YYYY-MM-DD` |
| Course | `courses.name` | trimmed |
| _(`--game-title`)_ | `courses.gameTitle` | CLI arg |
| Round | `rounds.roundNumber` | integer |
| Hole | `hole_results.holeNumber` | integer 1–18 |
| Par | `hole_results.par` | integer 3–5 |
| Score | `hole_results.score` | integer ≥ 1 |
| Fairway Hit? | `hole_results.fairwayHit` | Yes→true / No→false / N/A→null; **always null on par 3s** |
| GIR? | `hole_results.gir` | Yes→true / No→false |
| Putts | `hole_results.putts` | integer ≥ 0 |
| Up & Down Attempt? | `hole_results.upDownAttempt` | Yes→true / No→false |
| Up & Down Success? | `hole_results.upDownSuccess` | Yes→true / No→false / N/A→false |
| Penalty Stroke? | `hole_results.penaltyStrokes` | integer ≥ 0 |
| Notes | `hole_results.notes` | text or null |

Columns the app has but the sheet does not (`yards`, `driveDistanceYards`,
`bunkerVisited`, `sandSave`, tee/weather/etc.) are filled with the schema's
defaults by the in-app importer, not by this converter.

## Strict mode

The converter never silently repairs data. It aborts with a non-zero exit and a
message naming the offending row (date / course / round / hole) when it sees:

- an unrecognized Yes/No/N/A token (e.g. a typo like `Yues`),
- a non-integer in a required numeric column,
- "Up & Down Success" set without an attempt (the app rejects this), or
- a duplicate / out-of-range hole number within a round.

**Fix the offending cell in the spreadsheet and re-run** — do not work around it
here.

## Test

```sh
dart test
```

[#33]: https://github.com/aellington89/golfy/issues/33
