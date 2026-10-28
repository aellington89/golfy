// PRIVACY.md stays where the app says it is, and stays true (#72).
//
// Every installed build links to the policy and can't be given a new address,
// and the policy makes claims about the app that a later change could quietly
// break. These read the repo's own files, so they fail here rather than in
// front of a user. Plugins' permissions are merged in at build time, so CI
// checks the built APKs too (tool/assert_permissions.sh).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/features/settings/about_links.dart';

void main() {
  late Directory root;

  setUpAll(() {
    root = findRepoRoot();
  });

  test('PRIVACY.md is where every installed build links to it', () {
    expect(
      privacyPolicyUrl.path,
      endsWith('/blob/master/PRIVACY.md'),
    );
    expect(
      File('${root.path}/PRIVACY.md').existsSync(),
      isTrue,
      reason: 'every build links to PRIVACY.md at the repo root on master; '
          'moving or renaming it breaks the privacy policy link in all of them',
    );
  });

  test("the policy's contact is where Help & feedback goes", () {
    final policy = File('${root.path}/PRIVACY.md').readAsStringSync();
    final support = supportUri(platform: 'Android');
    final tracker = 'https://${support.host}'
        '${support.path.substring(0, support.path.lastIndexOf('/'))}';

    expect(
      policy,
      contains(tracker),
      reason: 'PRIVACY.md names a contact, and it should be the place '
          'Help & feedback sends people ($tracker)',
    );
  });

  test('the app asks for no Android permissions of its own', () {
    final manifest = File('${root.path}/app/android/app/src/main/'
            'AndroidManifest.xml')
        .readAsStringSync();

    expect(
      manifest,
      isNot(contains('<uses-permission')),
      reason: 'PRIVACY.md says Golfy has no permission to use the internet '
          'and asks for no other access; INTERNET belongs only in the debug '
          'and profile manifests, for the flutter tool',
    );
  });
}

/// Walks up from the test's working directory (`app/` under `flutter test`)
/// until the repo root — the directory holding CHANGELOG.md — is found.
Directory findRepoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 4; i++) {
    if (File('${dir.path}/CHANGELOG.md').existsSync()) return dir;
    dir = dir.parent;
  }
  throw StateError('could not find the repo root above ${Directory.current}');
}
