import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_version.dart';
import 'about_links.dart';
import 'platform_label.dart';

/// The legal line on the licence page (#72). Golfy's own code carries no
/// licence (README § License) until #76 decides otherwise, so this says only
/// what is true of every build.
const licensePageLegalese =
    "Golfy's own code is not open source; the packages listed here are, "
    'under the licenses shown.';

/// The **Version** row on the Settings screen (#72): the installed build, read
/// from the platform rather than written into the code.
class AppVersionTile extends ConsumerWidget {
  const AppVersionTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appVersionProvider);
    return ListTile(
      key: const ValueKey('settings_version_tile'),
      leading: const Icon(Icons.info_outline),
      title: const Text('Version'),
      subtitle: Text(version.when(
        data: (version) => version.label,
        error: (_, _) => 'Unavailable',
        loading: () => '…',
      )),
    );
  }
}

/// The **Open-source licenses** row (#72): Flutter's own licence page, listing
/// every package Golfy is built with and the licence each comes under. The
/// list is gathered from the packages themselves when the app is built, so
/// there is nothing here to keep up to date.
///
/// "Licenses", spelled as Flutter titles the page it opens.
class LicensesTile extends ConsumerWidget {
  const LicensesTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appVersionProvider).value;
    return ListTile(
      key: const ValueKey('settings_licenses_tile'),
      leading: const Icon(Icons.description_outlined),
      title: const Text('Open-source licenses'),
      subtitle: const Text('The packages Golfy is built with'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showLicensePage(
        context: context,
        applicationName: 'Golfy',
        applicationVersion: version?.label,
        applicationLegalese: licensePageLegalese,
      ),
    );
  }
}

/// The **Privacy policy** row (#72): `PRIVACY.md`, opened in the browser.
class PrivacyPolicyTile extends ConsumerWidget {
  const PrivacyPolicyTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      key: const ValueKey('settings_privacy_tile'),
      leading: const Icon(Icons.privacy_tip_outlined),
      title: const Text('Privacy policy'),
      subtitle: const Text(
        'Nothing you enter leaves this device unless you send it',
      ),
      trailing: const Icon(Icons.open_in_new),
      onTap: () => _openLink(context, ref, privacyPolicyUrl),
    );
  }
}

/// The **Help & feedback** row (#72): a new problem report, already holding
/// the version and platform a reply would otherwise ask for first.
class HelpFeedbackTile extends ConsumerWidget {
  const HelpFeedbackTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appVersionProvider).value;
    return ListTile(
      key: const ValueKey('settings_help_tile'),
      leading: const Icon(Icons.help_outline),
      title: const Text('Help & feedback'),
      subtitle: const Text('Report a problem or suggest an idea'),
      trailing: const Icon(Icons.open_in_new),
      onTap: () => _openLink(
        context,
        ref,
        supportUri(
          version: version,
          platform: platformLabel(Platform.operatingSystem),
        ),
      ),
    );
  }
}

/// Opens [uri] in another app. When nothing on the device can, says so and
/// offers the link to copy instead, so a tap is never silently lost.
Future<void> _openLink(BuildContext context, WidgetRef ref, Uri uri) async {
  final messenger = ScaffoldMessenger.of(context);
  if (await ref.read(linkOpenerProvider).open(uri)) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: const Text('Nothing on this device can open that link'),
    action: SnackBarAction(
      label: 'Copy link',
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: uri.toString()));
        messenger.showSnackBar(const SnackBar(content: Text('Link copied')));
      },
    ),
    duration: const Duration(seconds: 8),
  ));
}
