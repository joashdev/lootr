import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../security/secure_file_lifecycle.dart';

class CashewStagingService {
  CashewStagingService({
    Future<Directory> Function()? supportDirectory,
    this.secureFiles = const SecureFileLifecycle(),
    Random? random,
  }) : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       _random = random ?? Random.secure();

  static const sqliteFileTypes = XTypeGroup(
    label: 'Cashew data file',
    extensions: <String>['sql', 'sqlite', 'db'],
    uniformTypeIdentifiers: <String>['public.database'],
  );

  final Future<Directory> Function() _supportDirectory;
  final SecureFileLifecycle secureFiles;
  final Random _random;

  Future<XFile?> chooseSource() {
    return openFile(acceptedTypeGroups: const <XTypeGroup>[sqliteFileTypes]);
  }

  Future<StagedCashewSource> stage(
    XFile selected, {
    bool Function()? isCancelled,
  }) async {
    final root = await _supportDirectory();
    final token = List<int>.generate(
      16,
      (_) => _random.nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    final directory = Directory(p.join(root.path, 'cashew-import', token));
    await directory.create(recursive: true);
    final staged = File(p.join(directory.path, 'source.sqlite'));

    try {
      final before = await _digest(selected.openRead);
      final sink = staged.openWrite(mode: FileMode.writeOnly);
      var size = 0;
      try {
        await for (final chunk in selected.openRead()) {
          if (isCancelled?.call() ?? false) {
            throw const StagingFailure('cancelled');
          }
          size += chunk.length;
          sink.add(chunk);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      final copied = await _digest(staged.openRead);
      final after = await _digest(selected.openRead);
      if (before != copied || before != after) {
        throw const StagingFailure('source_changed_during_copy');
      }
      if (!await _hasSqliteHeader(staged)) {
        throw const StagingFailure('invalid_sqlite_header');
      }

      return StagedCashewSource(
        file: staged,
        stagingToken: token,
        sourceFingerprint: before,
        byteLength: size,
        originalFilename: p.basename(selected.name),
      );
    } catch (_) {
      await secureFiles.bestEffortDelete(staged);
      try {
        await directory.delete(recursive: true);
      } on FileSystemException {
        // Persisted import cleanup state handles a later retry.
      }
      rethrow;
    }
  }

  Future<void> cleanup(StagedCashewSource source) async {
    await secureFiles.bestEffortDelete(source.file);
    try {
      await source.file.parent.delete(recursive: true);
    } on FileSystemException {
      // Best effort, disclosed in the migration UI.
    }
  }

  Future<StagedCashewSource> resolve({
    required String stagingToken,
    required String sourceFingerprint,
  }) async {
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(stagingToken)) {
      throw const StagingFailure('invalid_staging_token');
    }
    final root = await _supportDirectory();
    final file = File(
      p.join(root.path, 'cashew-import', stagingToken, 'source.sqlite'),
    );
    if (!await file.exists()) {
      throw const StagingFailure('staged_source_missing');
    }
    final fingerprint = await _digest(file.openRead);
    if (fingerprint != sourceFingerprint) {
      throw const StagingFailure('staged_source_changed');
    }
    return StagedCashewSource(
      file: file,
      stagingToken: stagingToken,
      sourceFingerprint: fingerprint,
      byteLength: await file.length(),
      originalFilename: '',
    );
  }

  Future<String> _digest(Stream<List<int>> Function() openRead) async {
    final digest = await sha256.bind(openRead()).first;
    return digest.toString();
  }

  Future<bool> _hasSqliteHeader(File file) async {
    final handle = await file.open();
    try {
      final header = await handle.read(16);
      return utf8.decode(header, allowMalformed: true) ==
          'SQLite format 3\u0000';
    } finally {
      await handle.close();
    }
  }
}

class StagedCashewSource {
  const StagedCashewSource({
    required this.file,
    required this.stagingToken,
    required this.sourceFingerprint,
    required this.byteLength,
    required this.originalFilename,
  });

  final File file;
  final String stagingToken;
  final String sourceFingerprint;
  final int byteLength;

  /// Kept only in the encrypted import run. Never include in diagnostics.
  final String originalFilename;
}

class StagingFailure implements Exception {
  const StagingFailure(this.code);

  final String code;

  @override
  String toString() => 'StagingFailure($code)';
}
