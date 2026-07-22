import 'dart:math';

import 'package:file_selector/file_selector.dart';

import '../../application/migration/migration_coordinator.dart';
import '../../application/migration/migration_models.dart';
import 'cashew_staging_service.dart';

/// Keeps picker paths out of widget state, routes, and logs. A token is
/// single-use and is consumed when the source is copied into private staging.
class CashewSourceRegistry {
  CashewSourceRegistry({Random? random}) : _random = random ?? Random.secure();

  final Random _random;
  final Map<String, XFile> _pending = {};

  MigrationSourceSelection register(XFile file) {
    final token = List<int>.generate(
      16,
      (_) => _random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    _pending[token] = file;
    return MigrationSourceSelection(opaqueToken: token);
  }

  XFile consume(String token) {
    final file = _pending.remove(token);
    if (file == null) throw const StagingFailure('selection_expired');
    return file;
  }

  void discard(String token) {
    _pending.remove(token);
  }
}

class FileSelectorMigrationSourcePicker implements MigrationSourcePicker {
  const FileSelectorMigrationSourcePicker({
    required this.staging,
    required this.registry,
  });

  final CashewStagingService staging;
  final CashewSourceRegistry registry;

  @override
  Future<MigrationPickerResult> chooseCashewFile() async {
    final selected = await staging.chooseSource();
    if (selected == null) return const MigrationPickerResult.cancelled();
    return MigrationPickerResult.selected(registry.register(selected));
  }
}
