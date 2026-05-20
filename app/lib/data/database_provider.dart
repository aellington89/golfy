import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';

final databaseProvider = Provider<GolfyDatabase>((ref) {
  final db = GolfyDatabase();
  ref.onDispose(db.close);
  return db;
});
