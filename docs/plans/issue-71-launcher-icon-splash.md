# Implementation plan — #71 Custom adaptive launcher icon + branded splash screen

## Context

Golfy still ships the stock Flutter launcher icon in every Android density
and the stock Windows `app_icon.ico`. None of these files has changed since
the scaffold commit `572b981`. The Android launch window is also the template's
plain `?android:colorBackground`. Anyone installing the APK sees the Flutter
logo instead of Golfy, Play's review flags a default icon, and the store
screenshots planned in #78 must be taken from a branded build. The fix is a
Golfy icon in the existing golf palette, generated for every Android density
plus an adaptive and themed (monochrome) icon and the Windows `.ico`, and a
splash screen that follows light/dark mode.

**Size:** S in code (there is almost no Dart), M overall. The artwork needs a
review round and the result has to be checked on a real device.

### Acceptance criteria (from the issue; amendments marked)
1. A Golfy icon designed in the golf palette: fairway green `#2E7D32`, flag yellow `#FBC02D`, sky blue `#1565C0` (`app/lib/app.dart:9-11`).
2. All Android legacy densities, plus an adaptive icon and an Android 13+ monochrome (themed) icon, generated with `flutter_launcher_icons`.
3. `windows/runner/resources/app_icon.ico` replaced.
4. A branded splash made with `flutter_native_splash` that matches the light and dark themes. *(Amended: Android only. That package has no Windows support, and Windows needs no splash, because `windows/runner/flutter_window.cpp:30` keeps the window hidden until Flutter draws its first frame.)*
5. No default Flutter icon left in any variant. *(Proposed: enforced by a permanent test, not a one-time check.)*

### Changes from the issue text
- **The target version in the issue is out of date.** It says v0.4.0, but v0.8.0 is already out. Since #86, the version is worked out at release time (`RELEASING.md`, `app/tool/next_version.dart`). This is a MINOR change, so it lands in the next minor release (probably v0.9.0) with the `semver:minor` label.
- **The milestone the issue names doesn't exist.** There is no "App identity & about" milestone. That theme exists only as a row in epic #80, and #72 (the About screen) is its sibling.

## Scope

**In scope:** icon master artwork; Android legacy, adaptive and monochrome icons; the Windows `.ico`; the Android splash for both pre-12 and the Android 12+ SplashScreen API, in light and dark; a guard test; documentation.

**Out of scope:**
- The launcher label and window title, which still read `golfy_app` (`android/app/build.gradle.kts:43`, `windows/runner/main.cpp:30`, `Runner.rc:93,98`). See Q3.
- A separate icon for the debug build (Q4).
- An in-app logo for the drawer or About screen (#72).
- The Play hi-res 512 icon and feature graphic (#78), though step 1 makes the 512 export a one-liner.
- iOS and web. Neither has a target in the repo.

## Current state (verified)

**Android icon.** `android/app/src/main/res/mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png` are 442–1443 B each and are the stock files. Their SHA-256 values are recorded below for the guard test. There is no `mipmap-anydpi-v26`, so there's no adaptive icon. The manifest uses `android:icon="@mipmap/ic_launcher"` (`AndroidManifest.xml:5`). The `debug/` and `profile/` source sets contain only manifests, so all build types share these icons.

**Android splash.** `LaunchTheme` uses `@drawable/launch_background` (`res/values/styles.xml:5-7`, `values-night/styles.xml`), which is just `?android:colorBackground` with the image item commented out (`drawable-v21/launch_background.xml`). There's no `values-v31`, so Android 12+ shows its default splash with the stock icon.

**Windows.** `windows/runner/resources/app_icon.ico` is 33 772 B, the stock file, referenced at `Runner.rc:55`. The window stays hidden until the first frame (`flutter_window.cpp:30-32`), so there's no startup flash to cover.

**Theme.** `_golfyScheme` builds its surfaces from the green seed only (`app/lib/app.dart:50-72`). The first frame's background is therefore `ColorScheme.fromSeed(seedColor: #2E7D32, brightness).surface`, and that's the colour the splash has to match so there's no colour jump. `themeMode: ThemeMode.system` (`app.dart:23`) means the splash has to follow the system setting too.

**Tooling.** Neither package is in the pub cache yet. `crypto` and `yaml` are already transitive entries in `pubspec.lock`. No SVG rasterizer is on PATH (no ImageMagick, Inkscape or rsvg). The ignored local `.venv` has PySide6 with `QtSvg.pyd`, which can render SVG to PNG.

**CI.** `.github/workflows/flutter-build.yml` runs `flutter analyze`, `flutter test`, `flutter build apk --debug` and `aapt2 dump badging` on Linux, and builds Windows. Nothing in it checks icons.

**Conventions.**
- Generated code is committed (`app/README.md` "Generated files").
- New dependencies are documented under `app/README.md` "New dependencies".
- Design notes are committed to `docs/plans/issue-NN-*.md` with a closing "What was built" section (as #59 and #70 did).
- Every build bumps `+build` in `pubspec.yaml`; current is `0.8.0+46`.

**Stock hashes** (SHA-256 of the current files):
| file | sha256 |
|---|---|
| mipmap-mdpi | `c7c0c0189145e4e32a401c61c9bdc615754b0264e7afae24e834bb81049eaf81` |
| mipmap-hdpi | `6a7c8f0d703e3682108f9662f813302236240d3f8f638bb391e32bfb96055fef` |
| mipmap-xhdpi | `e14aa40904929bf313fded22cf7e7ffcbf1d1aac4263b5ef1be8bfce650397aa` |
| mipmap-xxhdpi | `4d470bf22d5c17d84edc5f82516d1ba8a1c09559cd761cefb792f86d9f52b540` |
| mipmap-xxxhdpi | `3c34e1f298d0c9ea3455d46db6b7759c8211a49e9ec6e44b635fc5c87dfb4180` |
| app_icon.ico | `c098d3fc85cacff98b8e69811b48e9f0d852fcee278132d794411d978869cbf8` |

## Proposed design

### Approach
Keep the artwork as SVG files in the repo, export 1024 px PNGs from them, and
let the two generator packages produce every platform resource from those PNGs.
The generated resources are committed, matching how this repo treats generated
code. Both packages are dev dependencies only: nothing changes at runtime and
APK size doesn't grow.

```
app/branding/                    # build-time inputs only; NOT a Flutter asset (not in pubspec `assets:`)
  README.md                      # palette, safe zones, export + regenerate commands
  icon.svg / icon.png            # full-bleed square: Android <8 legacy + Windows .ico
  icon_foreground.svg / .png     # adaptive foreground, content inside the 66/108 safe circle (~61%)
  icon_monochrome.svg / .png     # single-colour silhouette, same safe zone (Android 13 themed icons)
app/flutter_launcher_icons.yaml  # picked up automatically by `dart run flutter_launcher_icons`
app/flutter_native_splash.yaml   # picked up automatically by `dart run flutter_native_splash:create`
```

### Config sketches

```yaml
# flutter_launcher_icons.yaml
flutter_launcher_icons:
  android: true                      # keep the name ic_launcher, so the manifest doesn't change
  ios: false
  image_path: branding/icon.png
  adaptive_icon_background: "#2E7D32"
  adaptive_icon_foreground: branding/icon_foreground.png
  adaptive_icon_monochrome: branding/icon_monochrome.png
  min_sdk_android: 21                # explicit: the kts file uses flutter.minSdkVersion, which the tool can't read
  windows: { generate: true, image_path: branding/icon.png, icon_size: 256 }

# flutter_native_splash.yaml
flutter_native_splash:
  color: "<light surface>"           # = golfyColorScheme(light).surface
  color_dark: "<dark surface>"       # = golfyColorScheme(dark).surface
  image: branding/icon.png           # pre-Android-12 centred mark (exact size TBD in step 3)
  android_12:
    image: branding/icon_foreground.png   # its safe zone (~626/1024) fits the 12+ circle (768/1152)
    icon_background_color: "#2E7D32"
    color: "<light surface>"
    color_dark: "<dark surface>"
  android: true
  ios: false
  web: false
```

One small Dart change, made so the splash colours can be tested against the theme:

```dart
// app/lib/app.dart: rename the private _golfyScheme, behaviour unchanged
@visibleForTesting
ColorScheme golfyColorScheme(Brightness brightness);
```

### Key decisions
- **SVG masters plus committed PNG exports.** The SVG is the editable source and diffs as text. The PNGs are what the generators read, so CI and a fresh clone never need a rasterizer. For this work I'll rasterize locally with PySide6 `QSvgRenderer` from the existing `.venv`. That's a one-off tool, not a repo dependency, and `branding/README.md` will also give the equivalent Inkscape command.
- **The splash uses the theme's surface colour, not white or green.** The launch window's colour then equals the first Flutter frame's, so light and dark both hand over without a visible change. A test enforces it, because a later change to the seed colour would otherwise drift apart without anyone noticing.
- **The Android 12+ splash reuses the adaptive foreground on a green circle,** so the splash and the launcher show the same mark.
- **Windows `icon_size: 256`,** the largest the tool allows. If the generated `.ico` turns out to hold a single size and looks soft at 16/32 px in Explorer or the taskbar, replace it with a multi-size `.ico` built in the same export step. That's checked in step 2.
- **Generated Android resources are never hand-edited.** You change the art by editing the SVG, re-exporting and re-running the generators, as documented.

### Alternatives rejected
- **Drawing the icon in code (a CustomPainter rendered by a `flutter test` harness).** That would give one Dart source, reusable in-app later, but turning a test runner into an asset pipeline is unusual. #72 can render the same SVG through `flutter_svg` if it ever needs a logo.
- **Hand-writing `mipmap-anydpi-v26` XML and the v31 styles.** It's error-prone, and the issue asks for the two packages.
- **Splash background = brand green (a full-bleed green splash).** It clashes with the light-mode surface at handover and doesn't "match light/dark theme".
- **Adding `flutter_native_splash` as a runtime dependency** (its usual install) to use `preserve()`/`remove()`. Golfy has no async startup to hold the splash for (`app/lib/main.dart:6-8`), so a dev dependency is enough.

### Compatibility and migration
- No schema, data or applicationId change.
- The icon is replaced in place under the same resource name.
- Upgrades keep the same signing, so users simply see the new icon. Launchers may cache the old icon until the home screen is restarted.
- Nothing to migrate.

## Implementation steps

All work is on `test`, one PR `test → master` with labels `ui`, `enhancement`, `semver:minor` and `--assignee @me`. The steps run one after another because 2–4 all touch `pubspec.yaml` and `pubspec.lock`.

1. **Artwork** (`app/branding/*`).
   - Draw the three SVGs and export the 1024 px PNGs.
   - Write `branding/README.md` covering the palette, safe-zone geometry and the export and regenerate commands.
   - **Review checkpoint:** send you previews of the full icon, the adaptive foreground under circle and squircle masks, the monochrome version, and the 48 px rendering. Nothing is generated until you approve the art.
2. **Launcher icons** (depends on 1).
   - `flutter pub add --dev flutter_launcher_icons`, add `flutter_launcher_icons.yaml`, run `dart run flutter_launcher_icons`.
   - Commit the regenerated `mipmap-*`, new `mipmap-anydpi-v26/ic_launcher.xml`, `drawable-*/ic_launcher_{foreground,monochrome}.png`, `values/colors.xml`, `windows/runner/resources/app_icon.ico`, plus pubspec/lock and the `+47` build bump.
   - Check the ICO's entries (Windows decision above).
   - Check `git diff` for line-ending-only churn in XML the generator rewrote, and revert any that has no real content change (same caveat as build_runner).
3. **Splash** (depends on 1; after 2 because both edit pubspec).
   - Read the two surface colours by printing `golfyColorScheme(...).surface` from a throwaway test, or from the step-4 test.
   - `flutter pub add --dev flutter_native_splash`, add `flutter_native_splash.yaml`, run `dart run flutter_native_splash:create`.
   - Commit the regenerated `drawable*/launch_background.xml`, `drawable*/{background,splash}.png`, `values{,-night}/styles.xml` and new `values{,-night}-v31/styles.xml`.
   - Do the same line-ending churn check.
4. **Guard tests + scheme exposure** (depends on 2, 3).
   - Rename `_golfyScheme` to `@visibleForTesting golfyColorScheme` in `app.dart`.
   - Add `crypto` as a dev dependency (dart-lang owned, already transitive).
   - Add `test/branding/launcher_icon_test.dart` and `test/branding/splash_test.dart` (detail below).
5. **Docs** (depends on 2–4).
   - `CHANGELOG.md` `[Unreleased]` gets an `### Added` entry.
   - `app/README.md` gets a new "Branding (icon & splash)" section and a line under "New dependencies".
   - The root `README.md` repository layout gets `app/branding/`.
   - Commit this plan as `docs/plans/issue-71-launcher-icon-splash.md`, with "What was built" and "What could not be verified here" sections.
6. **Verify and open the PR** (see Testing). Then use `ccd_pr get_status`/`bind_pr` and offer Auto-fix.

## Risks and mitigations
- **The icon is unreadable at 48 px or gets clipped by a launcher mask.** Mitigation: the step-1 previews include 48 px and both mask shapes, and the content stays inside the 61% safe circle.
- **`flutter_launcher_icons` can't parse the `.kts` Gradle file, or can't infer minSdk.** Mitigation: `min_sdk_android` is set explicitly. If the run still fails, pin a version that supports kts and note it in the README.
- **`flutter_native_splash` rewrites `styles.xml` and drops `NormalTheme` customisations.** There are none today. The diff is reviewed, and the guard test checks that the v31 splash keys exist.
- **CRLF/LF churn in rewritten XML** (as with build_runner): review `git diff -w` and revert files with no content change.
- **The splash colour drifts from the theme later.** Mitigation: `splash_test.dart` fails if it does.
- **Windows `.ico` soft at small sizes.** Mitigation: inspect it in step 2 and fall back to a multi-size `.ico`.
- **Launcher icon caching on the device** can make it look like the change didn't take. Mitigation: uninstall/reinstall or restart the launcher when verifying.
- **Rollback:** revert the PR's commits. The resources go back to stock and there's no data or schema impact.

## Testing strategy

**Unit/structure tests** (run on Linux CI from `app/`; no widgets or DB):
- `test/branding/launcher_icon_test.dart`:
  - Each `mipmap-*/ic_launcher.png` exists, has the right PNG IHDR size (48/72/96/144/192) and has a SHA-256 outside the stock set above.
  - `mipmap-anydpi-v26/ic_launcher.xml` declares `<background>`, `<foreground>` and `<monochrome>`, and the drawables it references exist.
  - `app_icon.ico` is a valid ICO header whose hash isn't the stock one.
- `test/branding/splash_test.dart`:
  - `values-v31/styles.xml` and `values-night-v31/styles.xml` set `android:windowSplashScreenBackground` to `golfyColorScheme(light/dark).surface`, so the generated output that actually ships matches the theme.
  - Both `launch_background.xml` variants reference the splash bitmap.

**Integration / build:**
- `flutter analyze`.
- Targeted runs: `flutter test test/branding/`, then the full suite once (avoiding the dll-lock retry loop).
- `flutter build apk --debug`, then `aapt2 dump badging` shows `application-icon-*` pointing at `mipmap-anydpi-v26`.
- `flutter build windows --debug`, then a PowerShell screenshot of the taskbar and window icon.

**Manual on device:**
- A cold launch in light and in dark mode shows the splash with no colour jump into the app.
- The Android 13+ home screen with Themed icons on shows the monochrome icon.
- Circle and squircle launcher masks don't clip the mark.
- Pre-12 behaviour on an emulator if one is available. Otherwise it's listed as not verified.

**Regression:** startup behaviour, the `NormalTheme` window background behind Flutter, and debug/release coexistence (#23: same icon, different label).

| AC | Verified by |
|---|---|
| 1 Palette design | Step-1 preview review (your approval) |
| 2 Densities + adaptive + monochrome | `launcher_icon_test.dart`; aapt2 badging; Android 13 themed-icon check |
| 3 Windows ico | `launcher_icon_test.dart` hash/header; Windows build screenshot |
| 4 Splash light/dark | `splash_test.dart`; device cold-launch in both modes |
| 5 No stock icon remains | Stock-hash assertions in `launcher_icon_test.dart` (permanent; also catches a future `flutter create .` reverting them) |

## Documentation and handoff

**Developer-facing:**
- `app/branding/README.md` covers the palette, safe zones, how to export from the SVG, the two regenerate commands, and a warning not to hand-edit generated resources.
- `app/README.md` gets a Branding section and a "New dependencies" line (dev only, no runtime or permission change).
- The root README repository layout gets `app/branding/`.
- `CHANGELOG.md` gets the `[Unreleased] ### Added` entry.
- The plan is committed to `docs/plans/`.
- Build bumps `+47` onward.

**End-user:**
- No user guide covers app appearance, and no current material becomes wrong: the READMEs contain no screenshots of the old icon.
- The user-facing channel is the CHANGELOG entry and release notes ("Golfy has its own icon and launch screen; on Android 13+ it follows your themed-icon colours").
- No new guide is needed.

**Maintainer:**
- #78 can export its 512×512 Play icon straight from `branding/icon.svg`.
- #72 can reuse the SVG for an in-app logo.
- If the theme's seed colours change, `splash_test.dart` will fail until the splash is regenerated with the new surface colours, which is intended.

## Open questions

1. **Icon motif.** This sets the identity for the store listing.
   - **Recommended:** a white flagstick with a flag-yellow pennant planted in the cup, with a white ball on a fairway-green ground and a sky-blue band behind for the horizon. The monochrome version is the flag, pin and ball silhouette.
   - Alternative: a "G" monogram whose crossbar is a flag.
   - **Blocks step 1.** I'll draft the recommended motif unless you choose otherwise. You approve it at the step-1 checkpoint either way.
2. **Do you have artwork of your own** that should be the master instead of mine?
   - **Recommended:** no; I draw the SVG.
   - **Blocks step 1** only if you do.
3. **Change the launcher label and window title from `golfy_app` to `Golfy` here?** A new icon labelled `golfy_app` still looks unfinished, and it affects the #78 screenshots. It's a three-line change and doesn't touch the applicationId.
   - **Recommended:** file it as its own small issue (the identity theme, alongside #76's naming decision) rather than widen this PR.
   - Doesn't block.
4. **Give the debug build a visibly different icon** (for example a "DEV" badge), since debug and release can be installed side by side (#23)?
   - **Recommended:** defer to a follow-up. The label already says "(debug)".
   - Doesn't block.
5. **Keep the permanent stock-hash guard test** (adds `crypto` as a dev dependency) instead of a one-time manual check?
   - **Recommended:** yes.
   - Doesn't block.

## What was built, and where it departed from this plan

Steps 1–5 landed as five commits on `test`. The open questions went to their recommendations:
- Q1: the flag-in-cup motif, approved at the step-1 preview.
- Q2: the artwork drawn here.
- Q3 and Q4: the `golfy_app` label and a debug-build icon left for follow-ups.
- Q5: the stock-hash guard test kept.

Departures:

- **The adaptive background is a picture, not a flat colour.** `branding/icon_background.svg` (sky over two fairways) is a fourth source file, so the launcher icon shows the same scene as the Windows tile. That means there's no `values/colors.xml`.
- **The legacy and Windows icon is a rounded tile, not a full-bleed square.** Qt's SVG renderer ignores `clipPath`, so `icon.svg` draws the rounding into its shapes. Its fairway curves run exactly from x = 171 to 853 in `icon_background.svg`, which makes that possible.
- **The mark grew after the first draft.** At 16–48 px the first pin and flag were too thin. The pin went from 24 to 32 units wide and the pennant roughly doubled in area, all still inside the 66dp safe zone.
- **`flutter_launcher_icons` is pinned to `^0.14.4`.** A plain `flutter pub add` resolved 0.9.3, which has no Windows or monochrome support.
- **`adaptive_icon_foreground_inset: 0`.** By default the tool insets the foreground and monochrome layers by 16%. The art is already drawn to the 108dp canvas, so that would have shrunk it a second time and pulled the flag off its fairways.
- **The Windows `.ico` isn't generated by `flutter_launcher_icons`.** The tool wrote a single 256 px image, the case the plan anticipated, so `windows.generate` is false. `app_icon.ico` holds 16, 20, 24, 32, 40, 48, 64, 96, 128 and 256 px images, each rendered from `icon.svg` on its own: BMP entries below 256 and PNG at 256. The script was a one-off; `branding/README.md` gives an ImageMagick equivalent.
- **The pre-Android-12 splash image is its own file, `branding/splash.svg`.** It's the foreground on a fairway-green circle, exported at 640 px (160dp at xxxhdpi), so before Android 12 the splash looks the same as the 12+ SplashScreen does.
- **The splash colours are `#F7FBF1` (light) and `#10140F` (dark):** `ColorScheme.fromSeed(#2E7D32).surface` for each brightness.
- **The generator added four standard items to `LaunchTheme`** (`forceDarkAllowed=false`, not fullscreen, no system-bar backgrounds, `shortEdges` cutout mode). `NormalTheme` is untouched.
- **The splash test also decodes the pre-12 `background.png` pixels.** It does this with `dart:io` zlib in `test/branding/_png.dart`, so the colour old devices actually show is checked as well as the config and the v31 styles. The helper first rejected PNG filter type 4 (Paeth). For a 1×1 image every filter leaves the pixel unchanged, so it now accepts all five.
- **No "New dependencies" line in `app/README.md`.** That subsection belongs to the #69 backup section. The dev dependencies are described in the new "Branding (launcher icon & splash)" section instead.
- **No `+build` bump for the test and docs steps,** which produced no build. The build number is `+48`.

### What could not be verified here, and by what it will be

No Android device or emulator was connected, so nothing has been seen on a phone. What did run:
- `aapt2 dump badging` on the debug APK, which shows every density's icon resolving to `mipmap-anydpi-v26/ic_launcher.xml`.
- The two debug APK builds.
- Mock-ups composed from the generated drawables.
- `test/branding/` (12 tests), plus the full suite of 885.
- A mutation check: putting the stock `.ico` back and changing a splash colour each failed the tests.

These still need a device:
- A cold launch in light and in dark mode, checking that there's no colour change into the app.
- The Android 13+ themed icon with "Themed icons" turned on.
- How real launchers mask the icon.
- The splash on Android below 12.
