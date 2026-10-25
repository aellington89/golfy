# Golfy branding: launcher icon and splash

The source artwork for Golfy's launcher icon and splash screen
([#71](https://github.com/aellington89/golfy/issues/71)). These files are
**build-time inputs only**: nothing here is bundled into the app (it isn't in
`pubspec.yaml`'s `assets:`). Two generators turn the PNGs into the platform
resources under `android/` and `windows/`, and those generated files are
committed.

| File | What it is | Used by |
|---|---|---|
| `icon_background.svg` / `.png` | Adaptive-icon background layer: sky over two fairways, full bleed | `flutter_launcher_icons` (`adaptive_icon_background`) |
| `icon_foreground.svg` / `.png` | Adaptive-icon foreground layer: green, flag, cup, ball, on transparency | `flutter_launcher_icons` (`adaptive_icon_foreground`), `flutter_native_splash` (Android 12+ splash) |
| `icon_monochrome.svg` / `.png` | One-colour silhouette for Android 13+ themed icons | `flutter_launcher_icons` (`adaptive_icon_monochrome`) |
| `icon.svg` / `.png` | The two layers composed into a rounded tile | `flutter_launcher_icons` (legacy Android icon) and the Windows `.ico` (built separately, below) |
| `splash.svg` / `.png` | The foreground on a fairway-green circle, which is what Android 12+ draws from `icon_foreground.png` | `flutter_native_splash` (pre-Android-12 splash) |

The SVGs are the source. The PNGs are exports of them, committed so that a
fresh clone and CI never need an SVG renderer. They're 1024 × 1024, except
`splash.png`, which is 640 × 640: `flutter_native_splash` treats its image as
xxxhdpi, and 640 px there is 160 dp, the size of the Android 12+ splash
circle.

## Palette

The colours anchoring the app theme in [`lib/app.dart`](../lib/app.dart):

| Role | Colour |
|---|---|
| Fairway green (near fairway, splash circle) | `#2E7D32` |
| Flag yellow (pennant) | `#FBC02D` |
| Sky blue (sky, gradient from `#1E88E5` at the top) | `#1565C0` |

Supporting tones: far fairway `#43A047`, putting green `#66BB6A`, ball shadow
`#388E3C`, cup `#1B3A1E`, ball and flagstick white.

## Geometry

All four SVGs share one coordinate system: **1024 units = the 108 dp adaptive
icon canvas**.

- **Safe zone:** a launcher may mask the icon to any shape inside a 66 dp
  circle, which is radius 313 around (512, 512). Everything in the foreground
  and monochrome layers stays inside it. The flag tip at (760, 330), about 308
  from the centre, is the tightest point.
- **Visible area:** launchers show the central 72 dp, which is x and y from 171
  to 853. `icon.svg` uses exactly that as its `viewBox`, so the legacy icon,
  the Windows icon and the adaptive icon all frame the scene the same way.
- **Android 12+ splash:** the system draws the foreground image at 240 dp under
  a 160 dp circle, which keeps the middle two thirds. That's wider than the
  66/108 safe zone, so nothing gets clipped. `splash.svg` is that same picture,
  for Android versions before 12: a circle of radius 341 (two thirds of the
  canvas) cropped to its own bounds, `viewBox` 171..853.

`icon.svg` repeats the shapes of the two layer files instead of referencing
them, and it draws its rounded corners into the shapes because Qt's SVG
renderer ignores `clipPath`. **If you edit a layer, make the same edit in
`icon.svg`.** If the edit touches the foreground, make it in
`icon_monochrome.svg` and `splash.svg` too.

## Changing the artwork

1. Edit the SVGs.
2. Export each one to a PNG beside it, keeping transparency: 1024 × 1024, or
   640 × 640 for `splash`. For example, with Inkscape:

   ```powershell
   foreach ($n in 'icon','icon_background','icon_foreground','icon_monochrome') {
     inkscape "$n.svg" --export-type=png --export-width=1024 --export-height=1024 --export-filename="$n.png"
   }
   inkscape splash.svg --export-type=png --export-width=640 --export-height=640 --export-filename=splash.png
   ```

   Any renderer that honours the `viewBox` works. The committed PNGs were
   exported with Qt's `QSvgRenderer` (PySide6).
3. From `app/`, regenerate the platform resources:

   ```powershell
   dart run flutter_launcher_icons          # reads flutter_launcher_icons.yaml
   dart run flutter_native_splash:create    # reads flutter_native_splash.yaml
   ```

4. Rebuild the Windows icon, `windows/runner/resources/app_icon.ico`.
   `flutter_launcher_icons` would write only a single 256 px image, which
   Windows then has to scale down for the 16–48 px taskbar, title-bar and
   Explorer icons. So its Windows output is turned off, and the `.ico` holds
   16, 20, 24, 32, 40, 48, 64, 96, 128 and 256 px images: BMP entries below
   256 and a PNG entry at 256. The committed file renders each size from
   `icon.svg` on its own, with Qt. ImageMagick gets close by scaling down from
   one large render:

   ```powershell
   magick -background none -density 384 branding/icon.svg -define icon:auto-resize=256,128,96,64,48,40,32,24,20,16 windows/runner/resources/app_icon.ico
   ```

5. Review the diff. The generators rewrite some XML files, and Git can show a
   line-ending-only change on Windows. Revert any file whose `git diff -w` is
   empty.
6. Run `flutter test test/branding/`.

**Don't hand-edit the generated files** (`android/app/src/main/res/mipmap-*`,
`drawable*/`, `values*/styles.xml`, `windows/runner/resources/app_icon.ico`).
The next regeneration overwrites them.
