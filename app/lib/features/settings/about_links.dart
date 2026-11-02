import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/app_version.dart';

/// Golfy's privacy policy (#72): `PRIVACY.md` at the root of the repo, as
/// GitHub shows it.
///
/// Every build carries this address and can never be told a new one, so it
/// has to keep working for as long as any of them is installed: never move or
/// rename `PRIVACY.md`, and never rename `master`. It points at `master`
/// rather than a tag on purpose, so the policy can be corrected without a
/// release. `test/privacy_policy_test.dart` fails if the file goes.
final Uri privacyPolicyUrl =
    Uri.https('github.com', '/aellington89/golfy/blob/master/PRIVACY.md');

/// Where **Help & feedback** goes (#72): a new issue on Golfy's GitHub,
/// already holding the version and platform a reply would otherwise ask for
/// first. The person sees and edits it before anything is sent, and it carries
/// nothing else.
///
/// GitHub for now: the repo is public, and Golfy is downloaded from its
/// Releases. When Play needs a contact address (#77, #78), this is the one
/// place to change — builds already installed keep this link, which stays
/// valid.
Uri supportUri({AppVersion? version, required String platform}) {
  final build = version == null ? 'Golfy' : 'Golfy ${version.full}';
  return Uri.https('github.com', '/aellington89/golfy/issues/new', {
    'body': '<!-- What happened, and what did you expect instead? -->\n'
        '\n'
        '\n'
        '---\n'
        '$build · $platform\n',
  });
}

/// Opens a link somewhere other than Golfy (#72).
///
/// Overridden in tests with a fake, which keeps the platform out of the widget
/// suite — as `BackupDestination` does for the share sheet.
abstract class LinkOpener {
  /// Whether anything opened [uri]: `false`, not a throw, when nothing on the
  /// device can, so the caller can offer another way through.
  Future<bool> open(Uri uri);
}

/// Hands a link to another app — the browser, or the mail app — and never
/// shows it inside Golfy.
///
/// [LaunchMode.externalApplication] is the point. By default Android opens a
/// web link *in* the app, as a Custom Tab or, when that can't launch, in
/// url_launcher's own WebView — which runs in Golfy's process, and Golfy's
/// release build has no INTERNET permission (`PRIVACY.md` says so). Sent out
/// instead, the browser does the networking and Golfy itself never goes
/// online.
class ExternalLinkOpener implements LinkOpener {
  ExternalLinkOpener({
    Future<bool> Function(Uri url, {LaunchMode mode})? launch,
  }) : _launch = launch ?? launchUrl;

  final Future<bool> Function(Uri url, {LaunchMode mode}) _launch;

  @override
  Future<bool> open(Uri uri) async {
    try {
      return await _launch(uri, mode: LaunchMode.externalApplication);
    } on PlatformException {
      // Android throws ACTIVITY_NOT_FOUND when no installed app takes the link.
      return false;
    }
  }
}

/// How the About section opens its links (#72).
final linkOpenerProvider = Provider<LinkOpener>((ref) {
  return ExternalLinkOpener();
});
