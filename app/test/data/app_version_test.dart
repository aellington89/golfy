// The installed version (#72): one reader for the About section and for a
// backup's manifest, so the two always agree.
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/app_version.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  group('AppVersion', () {
    test('writes version+build, exactly as a backup manifest records it', () {
      // The string the manifest has always carried (BACKUP_FORMAT.md), which
      // files in the wild already hold — so it must not change shape.
      expect(
        const AppVersion(version: '0.10.0', buildNumber: '51').full,
        '0.10.0+51',
      );
    });

    test('shows people the build in words', () {
      expect(
        const AppVersion(version: '0.10.0', buildNumber: '51').label,
        '0.10.0 (build 51)',
      );
    });

    test('is the version alone when the platform reports no build', () {
      const version = AppVersion(version: '0.10.0', buildNumber: '');

      expect(version.full, '0.10.0');
      expect(version.label, '0.10.0');
    });

    test('keeps what the platform reported, debug suffix and all', () {
      final version = AppVersion.fromPackageInfo(PackageInfo(
        appName: 'Golfy (debug)',
        packageName: 'com.golfy.golfy_app.debug',
        version: '0.10.0-debug',
        buildNumber: '51',
      ));

      expect(
        version,
        const AppVersion(version: '0.10.0-debug', buildNumber: '51'),
      );
      expect(version.label, '0.10.0-debug (build 51)');
      expect(version.full, '0.10.0-debug+51');
    });
  });
}
