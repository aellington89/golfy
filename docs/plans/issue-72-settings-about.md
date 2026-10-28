# Implementation plan — #72 Settings / About: version, licences, privacy policy and help

> **Status: implemented** on `ccr-6b3b6657-pbrxus`, 2026-10-28. The plan was
> written the same day against `master` at `9426b23` (v0.9.0, `0.9.0+50`,
> schema v9, 885 tests), before any toolchain was installed. Repo facts came
> from reading the code at that commit, and outside facts are cited in §1.3.
> The plan text is left as written; "What was built" at the end records where
> the work departed from it.
>
> Issue: [#72](https://github.com/aellington89/golfy/issues/72) ·
> Depends on [#77](https://github.com/aellington89/golfy/issues/77) (privacy
> policy) · Part of epic [#80](https://github.com/aellington89/golfy/issues/80).

## Context

Golfy has a Settings screen, but it only does one job. #69 built it as the home
for Export, and #70 added Restore beside it, so the issue's last two criteria
are already met. The screen still can't answer the questions a user or a store
reviewer asks: which version is installed, what open-source code is inside the
app, where the privacy policy is, and who to contact. Google Play requires the
privacy-policy link (or text) inside the app itself, not just on the listing
(§1.3), so this screen is also on the path to #79.

**Summary.** Add an **About** section under **Data**, with four rows:

- the installed version, read at runtime;
- **Open-source licenses**, opening Flutter's licence page;
- **Privacy policy** and **Help & feedback**, opening in the browser or email
  app, never inside Golfy.

The policy itself doesn't exist yet, because #77 is open. This plan proposes
writing it here as `PRIVACY.md`, the way #69 built #72's screen to break the
same kind of deadlock. It also fixes one bug found while researching: on
Windows, Settings has no way back (§1.2).

**Size: S–M.** One new runtime dependency (`url_launcher`). No schema, format
or permission change.

### Acceptance criteria (from the issue and its comment; amendments marked)

1. The app's **version and build number** are shown, read at runtime, not
   hard-coded. `package_info_plus` is already a dependency (#69).
2. **Open-source licences** open through Flutter's `showLicensePage()`.
3. A link to the **hosted privacy policy**. *Amended:* there's no hosted policy
   to link to, because #77 hasn't published one. Proposed: publish it in this
   work as `PRIVACY.md` at the repo root, and link to the copy GitHub renders
   (Q1).
4. A **support / contact** link, either email or GitHub Issues (Q2).
5. ~~Hosts Export and Import / restore~~ **Done:** #69 and #70.
6. Reachable from the navigation drawer, with a widget test for the screen.
   **Done** for the shell (#69: `drawer_settings`, `settings_screen_test.dart`);
   the new rows extend the tests. *Proposed addition:* the screen can also be
   **left** on every platform (§1.2, finding 1).
7. *(Proposed)* Opening a link never shows web content inside Golfy and never
   needs a permission. The release build stays permission-free, which is what
   the privacy policy promises.

### Changes from the issue text

- **The target version is out of date.** The issue says v0.4.0, but v0.9.0 is
  out. This work adds an `### Added` entry, so `tool/next_version.dart` will
  make the next release a MINOR, probably **v0.10.0+51**. That's decided when
  the release is cut, not here.
- **"Hosts the Export and Import / restore actions" is already met** (v0.4.0
  and v0.8.0).
- **The privacy-policy row depends on #77**, which is targeted at v1.0.0, while
  #77's last criterion links the policy from this screen. Each issue waits on
  the other. This is the same deadlock #69 and #72 had, and it can be broken the
  same way (Q1).

## Scope

**In scope:**

- The About section and its four rows.
- One shared reader for the app version.
- A seam for opening links, using `url_launcher`.
- `PRIVACY.md` (Q1).
- The Settings back button (Q3).
- The drawer subtitle.
- Unit, widget and guard tests, and a CI permission check (Q5).
- Docs: the CHANGELOG, both READMEs, this plan, and issue comments.

**Out of scope:**

- **Play Console declarations** (Data Safety, the IARC rating, target audience,
  ads). Those are #77's.
- **The store listing** (#78).
- **Licence, EULA and trademark naming** (#76). The licence page's legal line
  stays neutral until #76 decides (Q4).
- **An in-app Golfy logo** (Q6).
- **GitHub Pages hosting.** #77 can add it later without breaking this link.
- **Other settings**, such as a theme toggle. None were asked for.
- **An accessibility audit** beyond these rows (#73).
- **Localisation, and iOS, macOS and Linux.**

**Non-goals:**

- Rendering web content in the app.
- Collecting diagnostics or crash reports.
- Any network access by Golfy itself.

## 1. Research

### 1.1 What is in place (verified at `9426b23`)

- **Screen.** `app/lib/features/settings/settings_screen.dart:12-55` is a
  `StatelessWidget` whose body is a `ListView`:
  - a **Data** header (`:23-32`), styled `titleSmall`, primary colour, bold;
  - a sentence of copy;
  - `ExportBackupTile` and `RestoreBackupTile`;
  - a `Divider`;
  - a footnote.

  Its doc comment (`:7-11`) already promises that "App version, open-source
  licences, the privacy policy and a support link … land as further sections
  here".
- **Tiles.** There's one file per tile, each keyed `settings_*_tile`:
  - `export_backup_tile.dart` is a `ConsumerStatefulWidget`, keyed
    `ValueKey('settings_export_tile')`, which reports through
    `showBackupResult` snackbars;
  - `restore_backup_tile.dart` follows the same pattern.

  Platform effects go through seams provided by Riverpod, which tests replace
  with fakes: `backupDestinationProvider` and `backupSourceProvider`
  (`app/lib/data/backup/backup_provider.dart:14-30`).
- **Drawer.** The `drawer_settings` entry pushes `SettingsScreen` on the root
  navigator (`app/lib/shell/app_drawer.dart:51-64`). Its subtitle is "Back up &
  restore" (`:55`), and its doc comment (`:6-9`) says Settings "will grow the
  version / licences / privacy / support rows (#72)".
- **How the version is read today.** `BackupService` already reads the version,
  for the backup manifest. Its default reader is the private
  `_appVersionFromPackageInfo()` (`backup_service.dart:56`, `:155-160`), which
  returns `'${version}+${buildNumber}'`, or `version` alone when the build
  number is empty. Tests inject `readAppVersion: () async => '0.4.0+38'`.

  `BACKUP_FORMAT.md:42` calls `appVersion` "diagnostics only; nothing branches
  on it". The string's format is still worth keeping identical, since files
  already in the wild carry it.
- **Dependencies.** `package_info_plus: ^10.2.2` is a direct dependency
  (`app/pubspec.yaml:50`); `url_launcher` itself is **not**.

  `share_plus` already pulls in `url_launcher_windows 3.1.6`,
  `url_launcher_platform_interface 2.3.2`, `url_launcher_web 2.4.3` and
  `url_launcher_linux 3.2.3` (`pubspec.lock`). The committed Windows plugin glue
  already registers `url_launcher_windows`
  (`app/windows/flutter/generated_plugins.cmake`, `generated_plugin_registrant.cc`).
- **Android manifest.**
  - The main manifest has **no `<uses-permission>`**. Its only `<queries>` entry
    is `PROCESS_TEXT` (`app/android/app/src/main/AndroidManifest.xml:39-44`).
  - `INTERNET` is declared only in `src/debug/` and `src/profile/`, for Flutter
    tooling.
  - Debug builds append `versionNameSuffix = "-debug"`
    (`app/android/app/build.gradle.kts:76`).
- **Windows version resource.** `ProductVersion` is `FLUTTER_VERSION`, i.e.
  `0.9.0+50` (`app/windows/runner/Runner.rc:99`). The resource also still
  carries the template's `LegalCopyright "Copyright (C) 2026 com.golfy. All
  rights reserved."` (`:96`) and `CompanyName "com.golfy"` (`:92`).
- **Licence and contact.** `README.md:364-366` says "Private project — no
  license granted. Reach out before reuse." It gives no way to reach out, and
  there's no contact anywhere in the repo or the app.
- **Tests to extend.**
  - `test/features/settings/settings_screen_test.dart` has 18 tests. Its
    `wrap()` (`:98-133`) overrides the stream providers and the backup seams
    over an in-memory DB.
  - `test/shell/app_drawer_test.dart:69-86` pushes the real `SettingsScreen`.

  The tests already have helpers for layout and for reading repo files:
  - a tall test surface, so a lazy `ListView` builds all its children
    (`resizeTall`, `test/features/dashboard/dashboard_screen_test.dart:26-30`);
  - a 360 dp, 2× text test ending in `expect(tester.takeException(), isNull)`
    (`:245-253`);
  - `findRepoRoot()`, used by tests that read repo files
    (`test/tool/release_rules_test.dart:602`, `drift_trio_test.dart:137`).
- **CI.** `.github/workflows/flutter-build.yml` has two jobs:
  - The Linux job runs `analyze`, `test`, the debug APK build and an
    `aapt2 dump badging` check on the package name (`:60-65`).
  - The Windows job only builds.

  Flutter is pinned at 3.47.6.
- **Release.** `[Unreleased]` is empty on `master`. Version bumps happen on the
  `release/vX.Y.Z` cut, never on a feature branch (`RELEASING.md`, "Cutting the
  release").

### 1.2 Found during research, not in the issue

1. **On Windows, Settings has no way back.**
   - `SettingsScreen` declares `drawer: const AppDrawer()`
     (`settings_screen.dart:20`, since `ccecf47` in #69), even though it's a
     **pushed** route.
   - When a `Scaffold` has a drawer, `AppBar` shows the drawer button *instead
     of* the back button. So Settings shows a hamburger, not a back arrow.
   - `CoursesScreen` is pushed the same way but has no drawer, so it does get a
     back arrow (`courses_screen.dart:28-29`).
   - Android users leave Settings with the system back gesture. Windows has no
     system back, and the drawer only pushes further screens, so a Windows user
     who opens Settings can't get back to the tabs without restarting the app.
   - This comes from reading the code, not from running a build. Step 4 checks
     it on Windows before fixing it (Q3).
2. **The default way of opening a link would put a web page inside Golfy.**
   - With `url_launcher`'s default mode, Android opens `https` links *inside
     the app*, as a Custom Tab, and falls back to the plugin's own
     `WebViewActivity` when a Custom Tab can't launch (§1.3).
   - That WebView runs in Golfy's process. The release build has no `INTERNET`
     permission, so the page would fail to load.
   - Adding `INTERNET` to fix that would break the privacy policy's central
     claim.
   - So every link opens in `LaunchMode.externalApplication`. The browser or
     mail app does the networking, never Golfy.
3. **On Android, `launchUrl` throws when nothing can open a link.** For
   example, `mailto:` on a device with no mail app throws
   `PlatformException(ACTIVITY_NOT_FOUND)` rather than returning `false`, so
   the fallback has to catch it.
4. **The version string differs by platform and build.**
   - On Android it's `versionName` (`0.9.0`, or `0.9.0-debug` in a debug build)
     plus `versionCode` (`50`).
   - On Windows, `package_info_plus` splits `ProductVersion` on `+`, giving
     `0.9.0` and `50`, with no debug marker.

   The backup manifest already records exactly these values, so the About row
   will match any backup made on the same install.
5. **The licence page is empty in widget tests.**
   `TestWidgetsFlutterBinding.initLicenses()` is deliberately a no-op, so a test
   has to register its own licence entry with `LicenseRegistry.addLicense` and
   reset it afterwards.
6. **Riverpod 3 retries a failing provider automatically**, starting at 200 ms
   and doubling to 6.4 s, until it succeeds or is disposed.
   - If the version provider failed (which shouldn't happen on Android or
     Windows), it would retry for nothing.
   - In a widget test it would leave a timer pending.
   - So the provider declares a `retry` callback that returns `null`.

### 1.3 Outside facts relied on

| Fact | Source |
|---|---|
| Play requires a privacy-policy link in the Console **and** "a privacy policy link or text within the app itself", for every app. The policy must include developer contact details and a privacy point of contact. | [Play Console Help 10144311](https://support.google.com/googleplay/android-developer/answer/10144311), as quoted by search results. The page itself couldn't be fetched from this session, so #77 should re-read it at submission. |
| `url_launcher` 6.3.3 needs Dart ^3.11 and Flutter ≥ 3.41, which the 3.47.6 pin meets. It depends on `url_launcher_android ^6.3.0`, `_windows ^3.1.0` and `_platform_interface ^2.3.0`, all compatible with the locked versions. | [`url_launcher/pubspec.yaml`](https://github.com/flutter/packages/blob/main/packages/url_launcher/url_launcher/pubspec.yaml) |
| On Android, `platformDefault` sets `inApp = url.startsWith('http:') \|\| url.startsWith('https:')`. In-app mode tries a Custom Tab, and the native code then "Fall[s] back to a web view if necessary". `externalApplication` starts an external intent instead. A failed launch throws `PlatformException(code: 'ACTIVITY_NOT_FOUND')`. | [`url_launcher_android.dart`](https://github.com/flutter/packages/blob/main/packages/url_launcher/url_launcher_android/lib/url_launcher_android.dart), [`UrlLauncher.java`](https://github.com/flutter/packages/blob/main/packages/url_launcher/url_launcher_android/android/src/main/java/io/flutter/plugins/urllauncher/UrlLauncher.java) |
| `<queries>` entries are needed only for schemes passed to `canLaunchUrl`, and for checking whether an in-app browser is available. `launchUrl` doesn't need them. | [`url_launcher` README](https://pub.dev/packages/url_launcher) |
| For URLs that aren't http(s), such as `mailto:`, the query string must be built with `encodeQueryParameters` and passed as `query:`. `Uri.queryParameters` turns spaces into `+`. | [`url_launcher` README](https://pub.dev/packages/url_launcher) |
| On Windows, `package_info_plus` splits `productVersion` on `+` into `version` and `buildNumber`. | [`package_info_plus_windows.dart`](https://github.com/fluttercommunity/plus_plugins/blob/main/packages/package_info_plus/package_info_plus/lib/src/package_info_plus_windows.dart) |
| `TestWidgetsFlutterBinding.initLicenses()` registers no licences ("the LICENSE file doesn't get generated for tests"). | [`flutter_test/lib/src/binding.dart`](https://github.com/flutter/flutter/blob/master/packages/flutter_test/lib/src/binding.dart) |
| Riverpod 3 retries failed providers by default. A `retry` callback on a provider or container stops it by returning `null`. | [Riverpod "What's new in 3.0"](https://github.com/rrousselGit/riverpod/blob/master/website/docs/whats_new.mdx) |

### 1.4 Still open, and who closes it

- **R1 — owner decisions:** Q1–Q6 below. Q1 and Q2 each block one row, and
  nothing else waits on them.
- **R2 — on a device:** check that both links open in the external browser or
  mail app from a signed release APK, which has no `INTERNET` permission. Also
  check the fallback with no mail app (an emulator), and on Windows with no
  mail client.
- **R3 — on a device:** see what the licence page actually lists, and whether
  dev-only packages appear. This is for information: nothing changes unless
  something odd turns up.
- **R4 — the first CI run:** record the debug APK's actual permission list,
  which becomes the guard's allow-list. Expected: `INTERNET`, and possibly
  AndroidX's app-private `…DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`. That one
  is signature-level and never shown to users.
- **R5 — #77, at Play submission:** confirm that a GitHub-rendered
  `PRIVACY.md` meets Play's URL rules. It needs to be a public page and not a
  PDF, which it is.

## 2. Design

### 2.1 What the user sees

```
←  Settings
────────────────────────────────────────────────────────────
Data
Golfy keeps everything on this device. A backup is a single file, …
 ⤓  Back up your data            3 rounds · 2 courses · 1 event      ›
 ↺  Restore from a backup        Replace what is here with a backup… ›
────────────────────────────────────────────────────────────
Keep the file somewhere off this phone — …

About
Golfy has no account, no ads and no tracking. The links below open
outside the app.
 ⓘ  Version                      0.10.0 (build 51)
 ▤  Open-source licenses         The packages Golfy is built with    ›
 ⛨  Privacy policy               Nothing you enter leaves this device
                                 unless you send it                  ↗
 ?  Help & feedback              Report a problem or suggest an idea ↗
```

**Microcopy.** Most users read nothing but these strings, so they're reviewed
as carefully as the code.

| Element | Text |
|---|---|
| Section header | **About**, styled like **Data** through one shared `_SectionHeader` |
| Line under the header | "Golfy has no account, no ads and no tracking. The links below open outside the app." |
| Version row | Title **Version**. The subtitle is `0.10.0 (build 51)`, `…` while reading, or `Unavailable` if the read fails. Not tappable. |
| Licences row | Title **Open-source licenses**, subtitle "The packages Golfy is built with", trailing chevron |
| Privacy row | Title **Privacy policy**, subtitle "Nothing you enter leaves this device unless you send it", trailing `open_in_new` |
| Support row | Title **Help & feedback**, subtitle "Report a problem or suggest an idea", trailing `open_in_new` |
| A link can't open | Snackbar "Nothing on this device can open that link", with a **Copy link** action that shows "Link copied" |
| Drawer subtitle | "Back up & restore" becomes "Back up, restore & about" |
| Licence page header | The name **Golfy**, the version label, and the Q4 line |

The UI spells it "licenses" (US), although the repo's prose says "licences". It
is the issue's own spelling, and it matches the page the row opens: Flutter's
default (US) localisations title `LicensePage` "Licenses".

### 2.2 Code shape

```
app/lib/data/app_version.dart               NEW  AppVersion, readAppVersion(), appVersionProvider
app/lib/features/settings/about_links.dart  NEW  privacyPolicyUrl, supportUri(), LinkOpener seam + provider
app/lib/features/settings/about_tiles.dart  NEW  AppVersionTile, LicensesTile, LinkTile
app/lib/features/settings/settings_screen.dart   About section, _SectionHeader, no drawer (Q3)
app/lib/shell/app_drawer.dart                    subtitle + doc comment
app/lib/data/backup/backup_service.dart          default version reader -> readAppVersion() (same string)
PRIVACY.md                                  NEW  the policy (Q1)
```

```dart
// app/lib/data/app_version.dart
class AppVersion {
  const AppVersion({required this.version, required this.buildNumber});
  factory AppVersion.fromPackageInfo(PackageInfo info);
  final String version;      // "0.10.0"; Android debug builds: "0.10.0-debug"
  final String buildNumber;  // "51"; may be empty
  String get full;           // "0.10.0+51": backups and reports, the manifest's string today
  String get label;          // "0.10.0 (build 51)": what the About row shows
}
Future<AppVersion> readAppVersion();                    // PackageInfo.fromPlatform()
final appVersionProvider = FutureProvider<AppVersion>(  // read once per run
  (ref) => readAppVersion(),
  retry: (_, _) => null,                                // a failed platform read won't recover
);

// app/lib/features/settings/about_links.dart
/// Shipped inside every APK, so it must keep resolving: never move or rename PRIVACY.md.
final privacyPolicyUrl =
    Uri.https('github.com', '/aellington89/golfy/blob/master/PRIVACY.md');
Uri supportUri(AppVersion? version, String platform);   // Q2: GitHub new issue or mailto:, prefilled

abstract class LinkOpener { Future<bool> open(Uri uri); }
/// Always LaunchMode.externalApplication: a browser or mail app does the
/// networking, never Golfy (whose release build has no INTERNET permission).
class ExternalLinkOpener implements LinkOpener {
  ExternalLinkOpener({Future<bool> Function(Uri, {LaunchMode mode})? launch}); // defaults to launchUrl
  // open() returns false on PlatformException (Android's ACTIVITY_NOT_FOUND) rather than throwing
}
final linkOpenerProvider = Provider<LinkOpener>((ref) => ExternalLinkOpener());
```

**Prefilled support reports.** These carry the version and the platform
(`Golfy 0.10.0+51 · Android`) and nothing else. The user sees and edits the
report before anything is sent.

- **GitHub:** `issues/new?title=&body=`.
- **Email:** `mailto:` with a `subject` and a `body`, built with
  `encodeQueryParameters`.

`RestoreConfirmDialog._platformName` (`restore_confirm_dialog.dart:133-137`)
moves to a shared helper, so "Android" and "Windows" are spelled out in one
place.

### 2.3 Key decisions

- **One version reader for the About row and for backups.**
  - `BackupService`'s default becomes `(await readAppVersion()).full`, and
    `_appVersionFromPackageInfo` goes.
  - The manifest's string doesn't change, and `app_version_test.dart` pins both
    forms.
  - The About row and every backup from the same install now agree by
    construction.
- **Links always leave the app** (`LaunchMode.externalApplication`), because of
  finding 2.
  - The permission-free release build keeps working.
  - The policy's claim that Golfy never goes online stays literally true.
  - Nothing depends on whether Custom Tabs are available.
- **A `LinkOpener` seam**, like `BackupDestination` and `BackupSource`.
  - Widget tests swap in a fake that records URIs and can be told to refuse, so
    no platform channel is mocked.
  - `ExternalLinkOpener` takes a launch function as a parameter, so its mode and
    its exception handling can be unit-tested.
- **Fail visibly, with a way through.** If nothing can open a link (an
  emulator, Windows with no mail client, a phone with no browser), a snackbar
  says so and offers **Copy link**. What this avoids is a tap that does nothing.
- **No `canLaunchUrl`, and no manifest change.** That check needs `<queries>`
  entries and can still disagree with the launch itself. Catching the launch's
  own failure is exact and adds nothing to the manifest.
- **The two URLs are a contract with every installed APK.**
  - They live in one file, with doc comments saying so.
  - A guard test fails if `PRIVACY.md` leaves the repo root, or if the constant
    stops pointing at it.
  - The link points at `master` rather than a tag, so the policy can be
    corrected without a release.
- **`showLicensePage`, called directly**, as the issue asks. `AboutListTile`
  would put a dialog in between.
  - The page gets the name, the version label and the Q4 line.
  - Flutter builds the list from every package's licence, so there's nothing to
    maintain.
- **Different version formats for reading and copying.** People read
  `0.10.0 (build 51)`. Reports and backups carry `0.10.0+51`, the form
  `RELEASING.md` and the release tooling already use.
- **The section starts with one line of copy, like Data does**, as the #72
  comment suggested. With bare tiles, nothing would explain why the links open
  outside the app.
- **The privacy and support rows share one `LinkTile`**, so the can't-open
  fallback is a single code path.

### 2.4 Alternatives rejected

- **Policy text in the app instead of a link.** Play accepts either a link or
  text. But the Console needs a hosted URL anyway, and a second copy inside the
  APK drifts from it and can't be corrected without a release.
- **Copy-to-clipboard only, with no `url_launcher`.** That would avoid a new
  dependency, but a privacy "link" that doesn't open is a poor experience, and
  arguably not a link. `url_launcher` is a Flutter-team package, and its
  Windows half is already compiled in.
- **An in-app browser or WebView.** It needs `INTERNET` in the release build
  (finding 2).
- **A separate About screen, or a second drawer entry.** Four rows don't need a
  screen of their own, and one entry keeps the drawer short. The drawer
  subtitle says "about", so the section can still be found.
- **`PackageInfo.setMockInitialValues` in tests.** That's global static state;
  overriding the provider is how this repo's tests already work.
- **The version as a build-time constant generated from the pubspec.** The
  issue asks for runtime, and a constant would be wrong whenever `--build-name`
  or `--build-number` is passed.
- **GitHub Pages for the policy now.** It needs a repo setting and a source
  folder, and publishing from `/docs` would also publish `docs/plans/`. The
  GitHub file URL works today. If #77 adds Pages later, `PRIVACY.md` stays the
  source and the in-app link stays valid.

### 2.5 Compatibility

- **Data:** no schema, data or backup-format change. `appVersion` keeps the
  same string.
- **New runtime dependency:** `url_launcher ^6.3.3`.
  - The lock gains `url_launcher` and `url_launcher_android`, plus
    `url_launcher_ios` and `url_launcher_macos`, which Golfy doesn't build for.
  - The Windows glue doesn't change, since it already registers
    `url_launcher_windows`.
  - Android's plugin registrant is generated at build time and isn't committed.
- **Permissions and manifest:** neither changes. The APK grows by tens of KB,
  far below the release workflow's 80 MB ceiling.
- **Installed APKs:** older builds have no links. Every build from this one on
  carries two URLs that must keep working, which the guard test and the
  maintainer runbook (§5.4) protect.

## 3. Build

The work goes on one feature branch and into one PR to `master`. This plan is
committed on `ccr-6b3b6657-pbrxus`, and the implementation can carry on there.
The PR takes the issue's `ui` and `feature` labels plus `semver:minor`. **The
version isn't bumped:** that belongs to the release cut.

1. **One version reader** (depends on nothing).
   - Add `app/lib/data/app_version.dart`.
   - Point `BackupService`'s default at it.
   - Add `test/data/app_version_test.dart`.
   - The existing backup tests inject their own reader, so they should pass
     unchanged.
2. **The link seam and `url_launcher`** (depends on nothing; can run alongside
   step 1).
   - Run `cd app && flutter pub add url_launcher`, and check the constraint
     comes out as `^6.3.3`.
   - Add `about_links.dart` and `test/features/settings/about_links_test.dart`,
     covering the opener's mode, how it handles exceptions, and the URL shapes.
   - Commit `pubspec.yaml` and `pubspec.lock`, and check that `git status
     app/windows` is clean.
3. **The privacy policy** (needs Q1, and Q2 for the contact; can run alongside
   steps 1–2).
   - Write `PRIVACY.md` at the repo root (§5.3).
   - Add the URL guard: `PRIVACY.md` exists, found through `findRepoRoot()`,
     and `privacyPolicyUrl` ends `/blob/master/PRIVACY.md`.
   - Add the CI permission check (Q5).
   - You review the policy text before step 4 merges.
4. **The About section** (depends on steps 1–3).
   - Add `about_tiles.dart`. In `settings_screen.dart`, add the About section
     and `_SectionHeader`.
   - Remove `drawer:` from Settings (Q3), after first confirming on the Windows
     debug build that there's no way back.
   - Update the subtitle and doc comment in `app_drawer.dart`, and the doc
     comment in `settings_screen.dart`.
   - Add the widget tests (§4.2) and update the drawer test.
5. **Docs** (depends on step 4, for the final copy). Everything in §5,
   including the CHANGELOG entries.
6. **Verify, then open the PR** (§4.5, §6).

Steps 1, 2 and 3 can run in parallel; steps 4, 5 and 6 run in order. Every
commit should pass on its own. Step 4 is the first to change the UI, so its
tests land in the same commit.

## 4. Testing

### 4.1 Unit

- **`test/data/app_version_test.dart`:**
  - `full` gives `0.10.0+51`, or `0.10.0` when the build number is empty,
    exactly as the old manifest helper did.
  - `label` gives `0.10.0 (build 51)`, or `0.10.0`.
  - `fromPackageInfo` keeps Android's `0.10.0-debug` and `51` as they are.
- **`test/features/settings/about_links_test.dart`:**
  - `ExternalLinkOpener` passes `LaunchMode.externalApplication` for both the
    `https` link and the support link.
  - A launch that throws `PlatformException` returns `false`, and so does one
    that returns `false`.
  - `supportUri` puts `Golfy 0.10.0+51 · Android` in the prefilled body, and
    for `mailto:` the spaces are `%20`, not `+`.
  - Without a version, `supportUri` still produces a working link.
- **The URL guard, in the same file:**
  - `privacyPolicyUrl` is
    `https://github.com/aellington89/golfy/blob/master/PRIVACY.md`.
  - `File('${findRepoRoot().path}/PRIVACY.md')` exists.
  - The failure message says why it matters: "every installed APK links here".

### 4.2 Widget (`settings_screen_test.dart`, a new "about" group)

`wrap()` gains two overrides:

- `appVersionProvider` returns `0.10.0` and `51`.
- `linkOpenerProvider` returns a `FakeLinkOpener`, which records URIs and can
  be told to refuse.

The tests use the `resizeTall` surface, so the lazy `ListView` builds the About
section without scrolling.

1. The About header, its line of copy and all four rows render, and the
   version row reads `0.10.0 (build 51)`.
2. When the version read fails:
   - the row shows `Unavailable`;
   - the other three rows still work;
   - no timer is left pending, which is what the `null` retry is for. If an
     override doesn't keep the provider's `retry`, set it on the test container
     too.
3. **Licences:**
   - Register a fake package with `LicenseRegistry.addLicense`, and call
     `LicenseRegistry.reset` in `addTearDown`.
   - Tapping the row opens a `LicensePage` showing "Golfy", `0.10.0 (build
     51)` and the fake package.
   - Back returns to Settings.
4. **Privacy:** tapping the row opens `privacyPolicyUrl` exactly once, and no
   snackbar appears.
5. **Support:** tapping the row opens `supportUri(...)`, prefilled with
   `0.10.0+51`.
6. **A link that can't open:**
   - When the fake refuses, the snackbar appears.
   - **Copy link** puts the URL on the clipboard, which the test captures with
     a mock handler on `SystemChannels.platform`.
   - "Link copied" then shows.
7. **Layout:** at 360 dp and 2× text (as in the dashboard test), nothing
   overflows (`takeException()` is null) and all four rows exist.
8. **Leaving Settings (Q3):** Settings pushed over a home route shows a
   `BackButton`, not a `DrawerButton`, and tapping it returns to the home
   route.

**`test/shell/app_drawer_test.dart`:**

- Add the same two overrides to its `wrap()`.
- Extend the Settings test to find the About header, either on a tall surface
  or after `scrollUntilVisible`.
- Check the new drawer subtitle.

### 4.3 CI guard (Q5)

Add a step to `flutter-build.yml` after "Assert debug application ID":

- It runs `aapt2 dump permissions` on the debug APK and prints the result.
- It fails on any permission outside an allow-list:
  - `android.permission.INTERNET`, which only debug builds have, for Flutter
    tooling;
  - the app's own `…DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`, if R4 shows it
    is there.

Its comment points at `PRIVACY.md`: a new permission means the policy and
#77's Data Safety answers change in the same PR. Its first run also proves that
`url_launcher` added nothing.

### 4.4 Regression

- The existing 18 Settings tests, the backup service tests and the backup
  goldens must pass unchanged. Together they show that the manifest's
  `appVersion` and the Data section are untouched.
- `widget_test.dart` (the shell smoke test) doesn't open Settings, so it needs
  no change.

### 4.5 Commands

```powershell
cd app
flutter analyze
flutter test test/data/app_version_test.dart test/features/settings test/shell   # targeted first
flutter test                                                                      # whole suite, once
flutter build apk --debug                                                         # then aapt2 dump permissions
flutter build windows --debug                                                     # or the CI Windows job
```

### 4.6 On a device (in the PR checklist)

- **Android, signed release APK** (from the draft Release, installed over
  v0.9.0):
  - The version row reads `0.10.0 (build 51)`.
  - **Privacy policy** opens the browser, not a page inside Golfy.
  - **Help & feedback** opens GitHub or the mail app, prefilled.
  - In airplane mode, the browser says it's offline and Golfy carries on.
- **Android emulator with no mail app** (if Q2 is email): the can't-open
  snackbar appears, and **Copy link** works.
- **Android debug build:** the version reads `…-debug (build N)`. That's
  expected, and it's how a dev build identifies itself.
- **Licence page, on both platforms:**
  - It lists the runtime packages: `drift`, `sqlite3`, `flutter_riverpod`,
    `intl`, `share_plus`, `file_selector`, `package_info_plus`, `url_launcher`
    and the rest.
  - A licence opens, and back returns to Settings.
  - Note whether dev-only packages appear (R3).
- **Windows:**
  - Before the fix, confirm that Settings has no way back (Q3). After it,
    confirm the back arrow returns to the tabs.
  - Links open in the default browser and mail client.
  - The version row matches *Product version* under the exe's Properties →
    Details.
- **Light and dark mode, the largest system font, and TalkBack**, which should
  read each row's title and subtitle.

### 4.7 Acceptance criteria → evidence

| AC | Verified by |
|---|---|
| 1 Version at runtime | `app_version_test`; widget test 1 (the value comes from the provider, not a literal); device check against the installed build |
| 2 Licences via `showLicensePage` | Widget test 3; the licence list on a device |
| 3 Privacy-policy link | Widget test 4; the URL guard; device check that it opens externally |
| 4 Support link | Widget test 5; the `supportUri` unit tests; device check |
| 5 Hosts Export / Restore | Already met; the existing 14 export and restore tests pass unchanged |
| 6 Drawer + widget test (+ leaving) | `app_drawer_test`; widget test 8; Windows device check |
| 7 Links open outside the app, no permissions | Unit test on the opener's mode; the CI permission guard; the airplane-mode check on a release APK |

## 5. Training and documentation

### 5.1 For users

**`README.md`:**

- Add a **Privacy** section after "Back up and restore your data". It takes
  two sentences: Golfy collects nothing and needs no permissions, and the full
  policy is in `PRIVACY.md`.
- Add **Help & feedback**: where to report a problem (Q2). Reports arrive
  prefilled with your version, which is also under **Settings → About →
  Version**.
- Give the **License** section's "Reach out before reuse" the same contact.
- In **Stack**, add `url_launcher` to the plugin line.
- In **Repository layout**, add `PRIVACY.md`.

**Release notes.** The next release's preamble gets one line, written when it's
cut: "Settings now shows which version you have, the open-source software
inside Golfy, its privacy policy, and where to get help."

### 5.2 In-app copy

The §2.1 table becomes the real strings. The other copy that changes:

- the drawer subtitle;
- the doc comments in `settings_screen.dart:7-11` and `app_drawer.dart:6-9`,
  which still describe #72 as future work.

### 5.3 The privacy policy (`PRIVACY.md`, Q1)

It's short, plain and dated, in these sections:

1. **The short version:** Golfy collects nothing.
2. **What it stores and where:** app-private storage on Android, which
   uninstalling removes; `%USERPROFILE%\Documents\golfy.sqlite` on Windows.
3. **What leaves the device:**
   - Nothing, automatically.
   - A backup goes only where you send it.
   - Restoring reads only the file you pick.
   - Links open in your browser or mail app, under that service's own policy.
4. **No analytics, ads, crash reporting or accounts.**
5. **Children.**
6. **Deleting your data.**
7. **Changes:** each version is dated, and the history is in git.
8. **Contact:** from Q2. Play requires a privacy contact.

Each claim rests on something in the code that can be checked:

| Claim | Evidence |
|---|---|
| No permissions, no internet | The main manifest has no `<uses-permission>`; `INTERNET` is only in `src/debug` and `src/profile`; the CI guard (§4.3) |
| No analytics, ads or crash SDKs | The dependencies in `app/pubspec.yaml` |
| A backup goes only where you send it, and carries no device identifiers | `backup_destination.dart` (share sheet or save dialog); `BACKUP_FORMAT.md` rule 7 |
| Links open outside the app | `ExternalLinkOpener` (`externalApplication`) |
| Where the data lives | `README.md`, "Stack" |

#77 keeps the Play Console declarations and can add Pages hosting. It takes
over a policy whose claims have already been checked.

### 5.4 For maintainers (`app/README.md`)

- **Project layout:**
  - add `data/app_version.dart`;
  - describe `features/settings/` as "Settings: Data (export / restore) and
    About (version, licences, privacy, help)";
  - update the matching `test/features/settings/` line.
- **A new architecture bullet, "Links leave the app".** It covers:
  - `externalApplication`, and why;
  - the `LinkOpener` seam;
  - the two URLs being a contract with installed APKs.
- **Dependencies:** add `url_launcher` to the "New dependencies" paragraph, and
  drop the stale "also #72's" note on `package_info_plus`.
- **Runbooks:**
  - **Changing a link.** Never move or rename `PRIVACY.md`, and don't rename
    `master`. If the hosting moves, keep `PRIVACY.md` as the source or as a
    pointer to the new page. A new URL only reaches new builds: old APKs keep
    the old one forever.
  - **When the permission guard fails.** A dependency asked for a permission.
    Decide whether that's acceptable. If it is, update `PRIVACY.md`, #77's
    Data Safety answers and the allow-list in the same PR.
  - **Adding an About row.** Use `LinkTile` for anything that opens outside the
    app, and add a widget test that renders the row on the tall surface.
- **Testing:** add `flutter test test/features/settings` to the list of
  commands.

### 5.5 CHANGELOG (`[Unreleased]`)

- `### Added`: Settings → About shows the installed version, the open-source
  licences, Golfy's privacy policy and a way to get help (#72). Links open in
  the browser or mail app, and Golfy still asks for no permissions. This entry
  makes the release a MINOR.
- `### Fixed` (Q3): Settings now has a back arrow, so it can be left on Windows
  (#72).
- `### Internal` (Q5): CI fails if the Android build asks for a permission the
  privacy policy doesn't mention.

### 5.6 This plan, and issue comments

- When the work lands, add a "What was built" section to this file, as #59,
  #70 and #71 did.
- **#72:** comment with the status of each criterion (5 was already met), the
  stale v0.4.0 target and the Windows back-button finding.
- **#77:** comment that the policy is published as `PRIVACY.md` and linked from
  the app. What remains for #77: Data Safety, IARC, target audience, ads, the
  link from the store listing, and Pages if wanted.
- **#80:** tick #72 once it's merged.

## 6. Review

### 6.1 Before the PR (self-review)

- Run everything in §4.5 and get it green.
- Re-read the diff the way a reviewer would, looking for problems:
  - **No version is hard-coded anywhere,** and every launch goes through
    `ExternalLinkOpener`.
  - **Both URLs are exactly right.** Open them.
  - **The backup manifest's version string hasn't changed.**
  - **No permission or manifest change.**
  - **Every claim in the policy has its evidence row.**
  - **The copy matches §2.1.**
  - **No personal email address,** unless that's what Q2 chose.
  - **No commented-out code.**
- Check the regenerated lock file for line-ending churn, and revert any that
  has no real change, as with build_runner output.

### 6.2 The PR

- **Title:** "Settings → About: version, licences, privacy policy and help
  (#72)".
- **Body:**
  - what changed, with the criteria table from §4.7;
  - the §4.6 device checklist, unticked;
  - screenshots of Android in light and dark mode, and of Windows;
  - `Closes #72`, and "Publishes the privacy policy for #77".
- **Labels:** `ui`, `feature`, `semver:minor`.

### 6.3 Where review should look hardest

1. **The wording of `PRIVACY.md`.** It's the one text here with legal weight,
   and you sign it off.
2. **The two URLs.** Once an APK carries them, they're permanent.
3. **`externalApplication`, and what happens when a launch throws.**
4. **The microcopy.**
5. **The back-button change on Android.** The hamburger becomes a back arrow,
   as on Courses.

### 6.4 Gates

- **The Linux job:** analyze, the full test suite, the debug APK, and the
  package-name and new permission checks.
- **The Windows build job.**
- **Your approval of `PRIVACY.md`.**

### 6.5 After merge

- Comment on #72, #77 and #80 (§5.6).
- At the next release cut, `next_version.dart` should report a MINOR, probably
  `0.10.0+51`.
- Check the draft Release's signed APK on a device, using the release items in
  §4.6.
- Refresh the README status and the test counts (RELEASING.md, steps 6–7).

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| The privacy link breaks in APKs already installed, because the file moved or `master` was renamed | The guard test; a doc comment on the constant; the §5.4 runbook. The `master` file URL keeps working through a later move to Pages, as long as `PRIVACY.md` stays |
| A link opens a broken page inside the app, because the release build has no `INTERNET` | Always `externalApplication`; a unit test pins the mode; device check on a release APK |
| Nothing on the device can open a link (no mail app, no browser, Windows without a mail client) | The exception becomes `false`; a snackbar offers **Copy link**; widget test 6; emulator check |
| The policy claims too much, or goes stale when a dependency adds a permission | The claim-and-evidence table; your review; the CI permission guard ties the policy to the build; #77 re-reads it at submission |
| A published contact address exposes a personal inbox | Q2 recommends a dedicated address, or GitHub Issues until there is one |
| The version reads oddly: `-debug` on Android debug builds, or an empty build number | Expected and documented. `label` handles an empty build number, and a failed read shows `Unavailable`, with no retry |
| The licence page is empty in tests, so its test passes without checking anything | The test registers its own entry and checks it appears; the device check covers the real list |
| A lazy `ListView` doesn't build the About rows in tests | The `resizeTall` surface, or `scrollUntilVisible` |
| A Riverpod retry timer is left pending in tests | `retry: (_, _) => null` on `appVersionProvider`; widget test 2 |
| `url_launcher` changes the Windows glue or adds Android permissions | The glue already registers it (check `git status`); the permission guard checks Android |
| The work spreads into #76, #77 or #78 | The out-of-scope list; Q4 keeps the legal line neutral |
| The change has to be backed out | Revert the PR. Nothing in the data or schema changes, and `PRIVACY.md` can stay, since it's harmless and #77 needs it |

## Open questions

**Resolved (2026-10-28):**
- Q1: `PRIVACY.md` here.
- Q2: GitHub Issues for now.
- Q3: fix the back button.
- Q4: the neutral legal line.
- Q5: add the CI guard.
- Q6: no icon.

All six went to the recommended option. For Q2 that's the interim one: GitHub
Issues until there's a dedicated address. The questions are kept below for the
record.

1. **Publish the privacy policy here?**
   - #77 is open, and this row can't link to a policy that doesn't exist yet.
   - **Recommended:** write `PRIVACY.md` at the repo root in this PR, and link
     to `https://github.com/aellington89/golfy/blob/master/PRIVACY.md`. #77
     keeps the Play declarations and can add Pages later; the link stays valid
     either way.
   - Alternative: do #77's publishing step first, in its own PR. The content
     is the same, in one more PR.
   - **Blocks:** step 3 and the privacy row only.
2. **Should help go to email or to GitHub Issues?**
   - Play requires a privacy contact in the policy, and #78's listing needs a
     developer email. Whatever is chosen here will probably be the contact in
     all three places.
   - **Recommended:** a dedicated email address, not a personal inbox, used for
     all three.
   - Until such an address exists, use GitHub Issues (`issues/new`, prefilled).
     The repo is public, Golfy is currently downloaded from GitHub Releases,
     and switching later only changes `supportUri`.
   - **Blocks:** where the support row points, and the contact line in the
     policy.
3. **Fix the Settings screen that Windows can't leave, as part of this work?**
   - **Recommended:** yes. It's one line (removing `drawer:`) and a widget
     test, and it's on the screen this issue owns.
   - The trade-off: on Android, Settings' hamburger becomes a back arrow, the
     same as Courses.
   - Doesn't block anything.
4. **What legal line goes on the licence page?**
   - **Recommended:** a neutral line that's true today: "Golfy's own code is
     not open source; the packages listed here are, under the licenses shown."
     Revisit it in #76, along with the placeholder `com.golfy` copyright in
     `Runner.rc`.
   - Alternative: a copyright line with your name.
   - Doesn't block anything.
5. **Add the CI permission guard?**
   - **Recommended:** yes. It's about six lines of YAML, and from now on it
     keeps the policy's central claim honest.
   - Doesn't block anything.
6. **Show the Golfy icon at the top of the licence page?**
   - **Recommended:** leave it for later. It needs a PNG exported from
     `branding/icon.svg` and an `assets:` entry, and none of the criteria ask
     for it. The drawer header could use the same asset later.
   - Doesn't block anything.

## Effort

About **a day and a half** of focused work for one developer. That excludes
review, time on devices, and waiting on your decisions.

| Step | Estimate |
|---|---|
| 1 Version reader and tests | 1 h |
| 2 Link seam, `url_launcher`, tests | 1.5 h |
| 3 `PRIVACY.md`, URL guard, CI guard | 2 h, plus your review |
| 4 About section, back button, widget and drawer tests | 3.5 h |
| 5 Docs | 1.5 h |
| 6 Verification and PR | 1.5 h, plus device checks |

The longest step is the policy text. It isn't long, but it needs your sign-off.

---

## What was built, and where it departed from this plan

Steps 1–5 landed as five commits after the plan's: the version reader; the
link seam and `url_launcher`; the policy and its guards; the About section
and back button; and these docs. Q1–Q6 were decided as recorded under Open
questions. Departures:

- **The permission guard runs in both workflows, not only `flutter-build.yml`.**
  The debug APK always has `INTERNET`, from the flutter tool's debug manifest,
  so a check on it alone could never notice `INTERNET` reaching a shipped
  build. The logic is one script, `tool/assert_permissions.sh`:
  - `flutter-build.yml` runs it on the debug APK, allowing `INTERNET`.
  - `release.yml` runs it on the signed release APK, allowing nothing.
  - It was exercised here against simulated `aapt2` output: six cases (debug
    and release, with and without an unexpected permission, including
    `maxSdkVersion` and `uses-permission-sdk-23` forms), plus a missing APK and
    a malformed one.
- **The policy guards are their own file, `test/privacy_policy_test.dart`.**
  It also checks that the policy's contact is the issue tracker Help &
  feedback opens, and that the main manifest has no `<uses-permission>`. That
  catches a permission added by hand, locally, without an Android SDK.
- **`platformLabel` is its own file** (`platform_label.dart`), so the restore
  dialog doesn't import `url_launcher` to name a platform.
- **Four named tiles share one private `_openLink`,** not a generic
  `LinkTile`: Help & feedback needs the version when it's tapped, which a
  plain `Uri` parameter can't carry.
- **Section headers are marked `Semantics(header: true)`,** which costs nothing
  ahead of #73.
- **Tests override the version with `overrideWithValue`,** so no create
  function and no retry is involved. The provider still declares `retry`
  returning `null` for the real read.
- **The prefilled report's prompt is an HTML comment**
  (`<!-- What happened… -->`), which GitHub hides when the issue renders. Only
  the version line shows.
- **`.gitattributes` pins `app/tool/*.sh` to LF,** so Git Bash on Windows can
  run the script.

**Verified here** on Flutter 3.47.6 (the CI pin), installed for this work:

- `flutter analyze` is clean, and the suite is **909 passing**: 885 before,
  plus 24 new.
- `dart run tool/next_version.dart` reports **MINOR, `0.10.0+51`**.
- Mutation checks:
  - Putting `drawer:` back on Settings fails the back-button test.
  - Moving `PRIVACY.md` fails two policy tests.
  - Adding `<uses-permission>` to the main manifest fails the third.
- No plugin in the lock declares an Android permission. That was read from
  each plugin's manifest in the pub cache.
- Settings and the licence page were rendered with real fonts in a throwaway
  test, in light and dark: the back arrow, the four rows, the open-externally
  icons, and the licence header with the version and legal line.

### What could not be verified here, and by what it will be

There's no Android SDK in this container (`dl.google.com` isn't reachable), so
no APK was built, and no device was connected.

| Not verified | Covered by |
|---|---|
| The permission guard on real `aapt2` output, and the debug APK's actual list (R4) | The first CI run on a pull request. If AndroidX's `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` isn't there, nothing changes; if something unexpected is, the step names it |
| The release workflow's new step | The next `workflow_dispatch` dry run, or the tag |
| Links opening in the browser from a signed release APK, and the copy fallback with no browser or mail app | The §4.6 device checklist |
| Windows: the back arrow, links opening in the default browser, the version matching the exe's Product version | The §4.6 device checklist |
| The real licence list, and TalkBack reading the rows | The §4.6 device checklist |
