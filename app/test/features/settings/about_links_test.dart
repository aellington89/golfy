// The About section's links (#72): where they point, and how they are opened.
//
// Every installed build carries these addresses and can't be given new ones,
// so their shape is pinned here; and the opener is driven through its
// injectable launch function, so no platform is involved.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/app_version.dart';
import 'package:golfy_app/features/settings/about_links.dart';
import 'package:golfy_app/features/settings/platform_label.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  group('ExternalLinkOpener', () {
    test('always hands a link to another app, never a view inside Golfy',
        () async {
      final modes = <LaunchMode>[];
      final opener = ExternalLinkOpener(
        launch: (url, {mode = LaunchMode.platformDefault}) async {
          modes.add(mode);
          return true;
        },
      );

      expect(await opener.open(privacyPolicyUrl), isTrue);
      expect(
        await opener.open(supportUri(platform: 'Android')),
        isTrue,
      );
      // Not platformDefault: on Android that opens web links in-app, and its
      // WebView fallback would need the INTERNET permission Golfy lacks.
      expect(modes, [
        LaunchMode.externalApplication,
        LaunchMode.externalApplication,
      ]);
    });

    test('says no, rather than throwing, when no app can take the link',
        () async {
      final opener = ExternalLinkOpener(
        launch: (url, {mode = LaunchMode.platformDefault}) async =>
            throw PlatformException(
              code: 'ACTIVITY_NOT_FOUND',
              message: 'No Activity found to handle intent { $url }',
            ),
      );

      expect(await opener.open(privacyPolicyUrl), isFalse);
    });

    test('passes on a launch that reports it failed', () async {
      final opener = ExternalLinkOpener(
        launch: (url, {mode = LaunchMode.platformDefault}) async => false,
      );

      expect(await opener.open(privacyPolicyUrl), isFalse);
    });
  });

  group('the privacy policy link', () {
    test('is PRIVACY.md on master, as GitHub shows it', () {
      expect(
        privacyPolicyUrl.toString(),
        'https://github.com/aellington89/golfy/blob/master/PRIVACY.md',
      );
    });
  });

  group('the Help & feedback link', () {
    const version = AppVersion(version: '0.10.0', buildNumber: '51');

    test("opens a new issue on Golfy's GitHub", () {
      final uri = supportUri(version: version, platform: 'Android');

      expect(uri.scheme, 'https');
      expect(uri.host, 'github.com');
      expect(uri.path, '/aellington89/golfy/issues/new');
    });

    test('carries the version and the platform, and nothing else', () {
      final uri = supportUri(version: version, platform: 'Android');

      expect(uri.queryParameters.keys, ['body']);
      expect(
        uri.queryParameters['body'],
        '<!-- What happened, and what did you expect instead? -->\n'
        '\n'
        '\n'
        '---\n'
        'Golfy 0.10.0+51 · Android\n',
      );
    });

    test('still works when the version could not be read', () {
      final body = supportUri(platform: 'Windows').queryParameters['body']!;

      expect(body, endsWith('---\nGolfy · Windows\n'));
    });
  });

  group('platformLabel', () {
    test('names the two platforms Golfy ships on', () {
      expect(platformLabel('android'), 'Android');
      expect(platformLabel('windows'), 'Windows');
    });

    test('passes anything else through as it came', () {
      expect(platformLabel('linux'), 'linux');
    });
  });
}
