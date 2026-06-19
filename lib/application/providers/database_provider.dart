import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../../data/database/app_database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase(
    driftDatabase(name: 'lootr'),
  );
});
