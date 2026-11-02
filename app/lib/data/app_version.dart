import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The installed build's version, read from the platform at run time (#72) —
/// never written into the code, so what Golfy says about itself can't drift
/// from the build that is running.
///
/// On Android it is `versionName` and `versionCode`; a debug build's name
/// carries the `-debug` suffix `build.gradle.kts` adds, which is how a dev
/// build says what it is. On Windows it is the exe's ProductVersion, split at
/// the `+`.
class AppVersion {
  const AppVersion({required this.version, required this.buildNumber});

  AppVersion.fromPackageInfo(PackageInfo info)
      : this(version: info.version, buildNumber: info.buildNumber);

  /// Reads the running build's version from the platform.
  static Future<AppVersion> fromPlatform() async =>
      AppVersion.fromPackageInfo(await PackageInfo.fromPlatform());

  /// `0.10.0`, or `0.10.0-debug` on an Android debug build.
  final String version;

  /// `51`. Empty when the platform reports none.
  final String buildNumber;

  /// `0.10.0+51` — what a backup's manifest records (`BACKUP_FORMAT.md`) and
  /// what a problem report carries.
  String get full => buildNumber.isEmpty ? version : '$version+$buildNumber';

  /// `0.10.0 (build 51)` — what Settings shows.
  String get label =>
      buildNumber.isEmpty ? version : '$version (build $buildNumber)';

  @override
  bool operator ==(Object other) =>
      other is AppVersion &&
      other.version == version &&
      other.buildNumber == buildNumber;

  @override
  int get hashCode => Object.hash(version, buildNumber);

  @override
  String toString() => 'AppVersion($full)';
}

/// The running build's version (#72), read once. Overridden in tests.
///
/// Never retried: a platform that can't say what version is installed won't
/// start to on a second ask, and Riverpod would otherwise keep asking on a
/// backoff for as long as the screen is open.
final appVersionProvider = FutureProvider<AppVersion>(
  (ref) => AppVersion.fromPlatform(),
  retry: (retryCount, error) => null,
);
