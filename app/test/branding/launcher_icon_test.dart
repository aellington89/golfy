// Guards Golfy's launcher icons (#71): no stock Flutter icon may come back
// in any variant (a `flutter create .` would quietly restore them), and the
// generated Android and Windows resources keep the shape branding/README.md
// describes. These read the committed files, so they run from app/ like the
// backup golden tests do.
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '_png.dart';

const _res = 'android/app/src/main/res';
const _ico = 'windows/runner/resources/app_icon.ico';

/// SHA-256 of the Flutter template's icons, as Golfy shipped them up to
/// v0.8.0 (scaffold commit 572b981).
const _stockSha256 = {
  // mipmap-mdpi … mipmap-xxxhdpi/ic_launcher.png
  'c7c0c0189145e4e32a401c61c9bdc615754b0264e7afae24e834bb81049eaf81',
  '6a7c8f0d703e3682108f9662f813302236240d3f8f638bb391e32bfb96055fef',
  'e14aa40904929bf313fded22cf7e7ffcbf1d1aac4263b5ef1be8bfce650397aa',
  '4d470bf22d5c17d84edc5f82516d1ba8a1c09559cd761cefb792f86d9f52b540',
  '3c34e1f298d0c9ea3455d46db6b7759c8211a49e9ec6e44b635fc5c87dfb4180',
  // windows/runner/resources/app_icon.ico
  'c098d3fc85cacff98b8e69811b48e9f0d852fcee278132d794411d978869cbf8',
};

/// Legacy launcher icon: 48dp at each density.
const _mipmapSizes = {
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
};

String _sha256(File f) => sha256.convert(f.readAsBytesSync()).toString();

void main() {
  test('no stock Flutter icon remains in any Android source set', () {
    // main, debug and profile: every variant the build can pick an icon from.
    final icons = Directory('android/app/src')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.uri.pathSegments.last.startsWith('ic_launcher'))
        .toList();
    expect(icons, isNotEmpty);
    for (final f in icons) {
      expect(_stockSha256, isNot(contains(_sha256(f))),
          reason: '${f.path} is the stock Flutter icon');
    }
  });

  test('the Windows icon is not the stock Flutter icon', () {
    expect(_stockSha256, isNot(contains(_sha256(File(_ico)))));
  });

  test('every density has a legacy icon of the right size', () {
    _mipmapSizes.forEach((density, size) {
      final png = readPng(File('$_res/mipmap-$density/ic_launcher.png'));
      expect((png.width, png.height), (size, size), reason: density);
    });
  });

  test('the adaptive icon has background, foreground and monochrome layers',
      () {
    final xml =
        File('$_res/mipmap-anydpi-v26/ic_launcher.xml').readAsStringSync();
    expect(xml, contains('<background android:drawable="@drawable/ic_launcher_background"'));
    expect(xml, contains('@drawable/ic_launcher_foreground'));
    expect(xml, contains('<monochrome>'));
    expect(xml, contains('@drawable/ic_launcher_monochrome'));
    // The art is drawn to the full 108dp canvas; any inset shrinks it twice.
    expect(RegExp(r'android:inset="(\d+)%"').allMatches(xml).map((m) => m[1]),
        everyElement('0'));

    // Each referenced layer exists at 108dp in every density.
    _mipmapSizes.forEach((density, legacySize) {
      final size = legacySize * 108 ~/ 48;
      for (final layer in ['background', 'foreground', 'monochrome']) {
        final png =
            readPng(File('$_res/drawable-$density/ic_launcher_$layer.png'));
        expect((png.width, png.height), (size, size),
            reason: '$density $layer');
      }
    });
  });

  test('the Windows icon carries every size from 16 to 256 px', () {
    final bytes = File(_ico).readAsBytesSync();
    final data = ByteData.sublistView(bytes);
    expect(data.getUint16(0, Endian.little), 0, reason: 'ICO reserved');
    expect(data.getUint16(2, Endian.little), 1, reason: 'ICO type: icon');
    final count = data.getUint16(4, Endian.little);
    // A directory entry's width byte is 0 for 256.
    final sizes = {
      for (var i = 0; i < count; i++)
        bytes[6 + 16 * i] == 0 ? 256 : bytes[6 + 16 * i],
    };
    expect(sizes, containsAll([16, 24, 32, 48, 64, 128, 256]));
  });
}
