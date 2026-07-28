import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

enum DiagnosticSeverity { debug, info, warning, error }

enum DiagnosticFeature { app, reporting, database, migration, notifications }

enum DiagnosticCode {
  appStarted,
  flutterError,
  asynchronousError,
  reportOpened,
  reportSubmitStarted,
  reportSubmitSucceeded,
  reportSubmitFailed,
}

enum DiagnosticOutcome { started, succeeded, failed, cancelled }

class DiagnosticEvent {
  const DiagnosticEvent({
    required this.timestamp,
    required this.severity,
    required this.feature,
    required this.eventCode,
    required this.outcome,
    this.durationMs,
    this.exceptionType,
    this.stack,
  });

  factory DiagnosticEvent.fromJson(Map<String, dynamic> json) {
    return DiagnosticEvent(
      timestamp: DateTime.parse(json['timestamp'] as String).toUtc(),
      severity: DiagnosticSeverity.values.byName(json['severity'] as String),
      feature: DiagnosticFeature.values.byName(json['feature'] as String),
      eventCode: DiagnosticCode.values.singleWhere(
        (code) => _eventCodeName(code) == json['eventCode'],
      ),
      outcome: DiagnosticOutcome.values.byName(json['outcome'] as String),
      durationMs: json['durationMs'] as int?,
      exceptionType: json['exceptionType'] as String?,
      stack: (json['stack'] as List<dynamic>?)?.cast<String>(),
    );
  }

  final DateTime timestamp;
  final DiagnosticSeverity severity;
  final DiagnosticFeature feature;
  final DiagnosticCode eventCode;
  final DiagnosticOutcome outcome;
  final int? durationMs;
  final String? exceptionType;
  final List<String>? stack;

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toUtc().toIso8601String(),
    'severity': severity.name,
    'feature': feature.name,
    'eventCode': _eventCodeName(eventCode),
    'outcome': outcome.name,
    'durationMs': ?durationMs,
    'exceptionType': ?exceptionType,
    'stack': ?stack,
  };

  static String _eventCodeName(DiagnosticCode code) {
    final name = code.name;
    final buffer = StringBuffer();
    for (var index = 0; index < name.length; index++) {
      final character = name[index];
      if (character.toUpperCase() == character && index > 0) {
        buffer.write('.');
      }
      buffer.write(character.toLowerCase());
    }
    return buffer.toString();
  }
}

class DiagnosticLogger {
  DiagnosticLogger({
    Directory? directory,
    DateTime Function()? clock,
    this.maxFileBytes = 256 * 1024,
    this.retention = const Duration(days: 7),
  }) : _clock = clock ?? DateTime.now {
    _directory = directory;
  }

  static final instance = DiagnosticLogger();

  final int maxFileBytes;
  final Duration retention;
  final DateTime Function() _clock;
  Directory? _directory;
  Future<void> _pendingWrite = Future.value();
  bool _initialized = false;

  File get _currentFile => File('${_directory!.path}/diagnostics.jsonl');
  File get _previousFile =>
      File('${_directory!.path}/diagnostics.previous.jsonl');

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      _directory ??= Directory(
        '${(await getApplicationSupportDirectory()).path}/diagnostics',
      );
      await _directory!.create(recursive: true);
      await _pruneFile(_previousFile);
      await _pruneFile(_currentFile);
      _initialized = true;
    } on FileSystemException {
      // Diagnostics are best-effort and must never prevent app startup.
    }
  }

  Future<void> log({
    required DiagnosticSeverity severity,
    required DiagnosticFeature feature,
    required DiagnosticCode eventCode,
    required DiagnosticOutcome outcome,
    int? durationMs,
  }) {
    return _enqueue(
      DiagnosticEvent(
        timestamp: _clock().toUtc(),
        severity: severity,
        feature: feature,
        eventCode: eventCode,
        outcome: outcome,
        durationMs: durationMs,
      ),
    );
  }

  Future<void> recordError({
    required DiagnosticFeature feature,
    required DiagnosticCode eventCode,
    required Object error,
    StackTrace? stackTrace,
  }) {
    return _enqueue(
      DiagnosticEvent(
        timestamp: _clock().toUtc(),
        severity: DiagnosticSeverity.error,
        feature: feature,
        eventCode: eventCode,
        outcome: DiagnosticOutcome.failed,
        exceptionType: _safeToken(error.runtimeType.toString()),
        stack: _sanitizeStack(stackTrace),
      ),
    );
  }

  Future<List<DiagnosticEvent>> readRecent({int limit = 100}) async {
    await _pendingWrite;
    if (!_initialized) return const [];
    final cutoff = _clock().toUtc().subtract(retention);
    final events = <DiagnosticEvent>[];
    for (final file in [_previousFile, _currentFile]) {
      if (!await file.exists()) continue;
      final lines = await file.readAsLines();
      for (final line in lines) {
        try {
          final json = jsonDecode(line) as Map<String, dynamic>;
          final event = DiagnosticEvent.fromJson(json);
          if (!event.timestamp.isBefore(cutoff)) events.add(event);
        } on FormatException {
          // Ignore a partial final line after an interrupted write.
        } on TypeError {
          // Ignore records from an incompatible older schema.
        } on ArgumentError {
          // Ignore unknown enum values from an incompatible older schema.
        }
      }
    }
    events.sort((left, right) => left.timestamp.compareTo(right.timestamp));
    if (events.length <= limit) return events;
    return events.sublist(events.length - limit);
  }

  Future<void> clear() async {
    await _pendingWrite;
    if (!_initialized) return;
    for (final file in [_currentFile, _previousFile]) {
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> _enqueue(DiagnosticEvent event) {
    _pendingWrite = _pendingWrite.then((_) => _write(event));
    return _pendingWrite;
  }

  Future<void> _write(DiagnosticEvent event) async {
    if (!_initialized) return;
    final encoded = '${jsonEncode(event.toJson())}\n';
    try {
      if (await _currentFile.exists() &&
          await _currentFile.length() + utf8.encode(encoded).length >
              maxFileBytes) {
        if (await _previousFile.exists()) await _previousFile.delete();
        await _currentFile.rename(_previousFile.path);
      }
      await _currentFile.writeAsString(encoded, mode: FileMode.append);
    } on FileSystemException {
      // A full or temporarily unavailable disk must not affect app behavior.
    }
  }

  Future<void> _pruneFile(File file) async {
    if (!await file.exists()) return;
    final cutoff = _clock().toUtc().subtract(retention);
    final retained = <String>[];
    for (final line in await file.readAsLines()) {
      try {
        final json = jsonDecode(line) as Map<String, dynamic>;
        final timestamp = DateTime.parse(json['timestamp'] as String).toUtc();
        if (!timestamp.isBefore(cutoff)) retained.add(line);
      } on Object {
        // Drop malformed or incompatible records during maintenance.
      }
    }
    if (retained.isEmpty) {
      await file.delete();
    } else {
      await file.writeAsString('${retained.join('\n')}\n');
    }
  }

  static String _safeToken(String value) {
    final sanitized = value.replaceAll(RegExp('[^A-Za-z0-9_.-]'), '_');
    return sanitized.length <= 64 ? sanitized : sanitized.substring(0, 64);
  }

  static List<String>? _sanitizeStack(StackTrace? stackTrace) {
    if (stackTrace == null) return null;
    final frames = stackTrace
        .toString()
        .split('\n')
        .where(
          (line) =>
              line.contains('package:lootr/') ||
              line.contains('package:flutter/') ||
              line.contains('dart:'),
        )
        .take(12)
        .map(
          (line) => line
              .replaceAll(RegExp(r'https?://[^ )]+'), '<url>')
              .replaceAll(RegExp(r'0x[0-9a-fA-F]+'), '<address>')
              .trim(),
        )
        .where((line) => line.isNotEmpty)
        .map((line) => line.length <= 240 ? line : line.substring(0, 240))
        .toList(growable: false);
    return frames.isEmpty ? null : frames;
  }
}
