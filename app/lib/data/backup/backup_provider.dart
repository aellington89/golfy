import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repository_provider.dart';
import 'backup_destination.dart';
import 'backup_service.dart';
import 'backup_source.dart';
import 'restore_service.dart';

/// Where a finished backup file goes (#69).
///
/// Overridden in tests with a fake, which is what keeps the share sheet and
/// the save dialog out of the widget suite. Constructing the real one touches
/// no plugin — nothing happens until `save` is called.
final backupDestinationProvider = Provider<BackupDestination>((ref) {
  return createPlatformBackupDestination();
});

/// The Export action's service (#69).
final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    repository: ref.watch(repositoryProvider),
    destination: ref.watch(backupDestinationProvider),
  );
});

/// Where a backup to restore comes from (#70). Overridden in tests with a
/// fake, which keeps the platform picker out of the widget suite.
final backupSourceProvider = Provider<BackupSource>((ref) {
  return createPlatformBackupSource();
});

/// The Restore action's service (#70).
final restoreServiceProvider = Provider<RestoreService>((ref) {
  return RestoreService(
    repository: ref.watch(repositoryProvider),
    source: ref.watch(backupSourceProvider),
  );
});
