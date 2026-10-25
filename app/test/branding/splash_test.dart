// Guards the native Android splash (#71) against drifting from the app theme.
// The splash background must be the colour the first Flutter frame paints,
// the theme's ColorScheme.surface, or the handover into the app flashes. A
// change to the theme's seed colours fails here until the splash is
// regenerated (branding/README.md).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/app.dart';

import '_png.dart';

const _res = 'android/app/src/main/res';

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

String _surface(Brightness b) => _hex(golfyColorScheme(b).surface);

String _splashBackground(String valuesDir) {
  final xml = File('$_res/$valuesDir/styles.xml').readAsStringSync();
  final match = RegExp(
    r'<item name="android:windowSplashScreenBackground">(#[0-9A-Fa-f]{6})</item>',
  ).firstMatch(xml);
  expect(match, isNotNull, reason: '$valuesDir has no splash background');
  return match![1]!.toUpperCase();
}

void main() {
  test('the config asks for the theme surface colours', () {
    final yaml = File('flutter_native_splash.yaml').readAsStringSync();
    String values(String key) => RegExp('^\\s*$key: "(#[0-9A-Fa-f]{6})"',
            multiLine: true)
        .allMatches(yaml)
        .map((m) => m[1]!.toUpperCase())
        .toSet()
        .join(',');
    // Top level and android_12 both: one light value, one dark value.
    expect(values('color'), _surface(Brightness.light));
    expect(values('color_dark'), _surface(Brightness.dark));
  });

  group('Android 12+ splash background is the theme surface', () {
    test('light', () {
      expect(_splashBackground('values-v31'), _surface(Brightness.light));
    });
    test('dark', () {
      expect(_splashBackground('values-night-v31'), _surface(Brightness.dark));
    });
  });

  group('pre-Android-12 splash', () {
    for (final (dir, brightness) in [
      ('drawable', Brightness.light),
      ('drawable-v21', Brightness.light),
      ('drawable-night', Brightness.dark),
      ('drawable-night-v21', Brightness.dark),
    ]) {
      test('$dir draws the mark on the theme surface', () {
        final xml =
            File('$_res/$dir/launch_background.xml').readAsStringSync();
        expect(xml, contains('@drawable/background'));
        expect(xml, contains('@drawable/splash'));
        expect(readPng(File('$_res/$dir/background.png')).singlePixelHex,
            _surface(brightness));
      });
    }
  });
}
