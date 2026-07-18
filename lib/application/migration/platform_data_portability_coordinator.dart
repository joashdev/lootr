import 'dart:io';

import 'package:file_selector/file_selector.dart';

import '../../data/backup/lootr_backup_service.dart';
import '../../data/backup/transaction_csv_export_service.dart';
import '../../data/database/app_database.dart';
import 'migration_coordinator.dart';
import 'migration_models.dart';

class PlatformDataPortabilityCoordinator implements DataPortabilityCoordinator {
  const PlatformDataPortabilityCoordinator({
    required this.database,
    required this.liveDatabaseFile,
    required this.restoreVerifiedBackup,
    required this.backups,
    this.csv = const TransactionCsvExportService(),
  });

  static const backupType = XTypeGroup(
    label: 'Encrypted Lootr backup',
    extensions: ['lootr'],
    uniformTypeIdentifiers: ['public.data'],
  );
  static const csvType = XTypeGroup(
    label: 'Transaction CSV',
    extensions: ['csv'],
    uniformTypeIdentifiers: ['public.comma-separated-values-text'],
  );

  final AppDatabase Function() database;
  final Future<File> Function() liveDatabaseFile;
  final Future<void> Function(File backup) restoreVerifiedBackup;
  final LootrBackupService backups;
  final TransactionCsvExportService csv;

  @override
  Future<DataPortabilityResult> createBackup() async {
    final destination = await getSaveLocation(
      acceptedTypeGroups: const [backupType],
      suggestedName: 'lootr-backup-${_dateStamp()}.lootr',
      confirmButtonText: 'Create backup',
    );
    if (destination == null) {
      return const DataPortabilityResult(
        succeeded: false,
        message: 'Backup creation cancelled. No data was changed.',
      );
    }
    try {
      await database().customSelect('SELECT 1').getSingle();
      await database().customStatement('PRAGMA wal_checkpoint(FULL)');
      await backups.create(
        liveDatabase: await liveDatabaseFile(),
        destination: File(destination.path),
      );
      return const DataPortabilityResult(
        succeeded: true,
        message: 'Encrypted Lootr backup created and verified.',
      );
    } catch (_) {
      return const DataPortabilityResult(
        succeeded: false,
        message: 'The backup could not be created. No data was changed.',
      );
    }
  }

  @override
  Future<DataPortabilityResult> restoreBackup() async {
    final selected = await openFile(
      acceptedTypeGroups: const [backupType],
      confirmButtonText: 'Choose backup',
    );
    if (selected == null) {
      return const DataPortabilityResult(
        succeeded: false,
        message: 'Restore cancelled. No data was changed.',
      );
    }
    try {
      final file = File(selected.path);
      await backups.verify(file);
      await restoreVerifiedBackup(file);
      return const DataPortabilityResult(
        succeeded: true,
        message: 'The verified Lootr backup was restored.',
      );
    } catch (_) {
      return const DataPortabilityResult(
        succeeded: false,
        message: 'The backup was not restored. Your current data is unchanged.',
      );
    }
  }

  @override
  Future<DataPortabilityResult> exportTransactionsCsv() async {
    final destination = await getSaveLocation(
      acceptedTypeGroups: const [csvType],
      suggestedName: 'lootr-transactions-${_dateStamp()}.csv',
      confirmButtonText: 'Export CSV',
    );
    if (destination == null) {
      return const DataPortabilityResult(
        succeeded: false,
        message: 'CSV export cancelled. No file was created.',
      );
    }
    try {
      await csv.export(
        database: database(),
        destination: File(destination.path),
      );
      return const DataPortabilityResult(
        succeeded: true,
        message: 'Currency-aware transaction CSV created.',
      );
    } catch (_) {
      return const DataPortabilityResult(
        succeeded: false,
        message: 'The CSV could not be created. Your data is unchanged.',
      );
    }
  }
}

String _dateStamp() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}'
      '${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}';
}
