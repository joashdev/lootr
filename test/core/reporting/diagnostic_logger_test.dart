import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/core/reporting/diagnostic_logger.dart';

void main() {
  late Directory directory;
  late DateTime now;
  late DiagnosticLogger logger;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('lootr-diagnostics-');
    now = DateTime.utc(2026, 7, 27, 1);
    logger = DiagnosticLogger(
      directory: directory,
      clock: () => now,
      maxFileBytes: 320,
    );
    await logger.initialize();
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('persists only the closed diagnostic event schema', () async {
    await logger.log(
      severity: DiagnosticSeverity.info,
      feature: DiagnosticFeature.reporting,
      eventCode: DiagnosticCode.reportOpened,
      outcome: DiagnosticOutcome.succeeded,
    );

    final events = await logger.readRecent();

    expect(events, hasLength(1));
    expect(events.single.toJson(), {
      'timestamp': '2026-07-27T01:00:00.000Z',
      'severity': 'info',
      'feature': 'reporting',
      'eventCode': 'report.opened',
      'outcome': 'succeeded',
    });
  });

  test('records exception type without error message content', () async {
    await logger.recordError(
      feature: DiagnosticFeature.app,
      eventCode: DiagnosticCode.flutterError,
      error: StateError('Balance is 1234'),
      stackTrace: StackTrace.fromString(
        '#0 package:lootr/main.dart 1:1\n'
        '#1 https://private.example/account/123\n',
      ),
    );

    final json = (await logger.readRecent()).single.toJson().toString();

    expect(json, contains('StateError'));
    expect(json, isNot(contains('Balance is 1234')));
    expect(json, isNot(contains('private.example')));
  });

  test('rotates at the configured size and retains recent events', () async {
    for (var index = 0; index < 8; index++) {
      now = now.add(const Duration(minutes: 1));
      await logger.log(
        severity: DiagnosticSeverity.info,
        feature: DiagnosticFeature.reporting,
        eventCode: DiagnosticCode.reportSubmitStarted,
        outcome: DiagnosticOutcome.started,
      );
    }

    expect(
      File('${directory.path}/diagnostics.previous.jsonl').existsSync(),
      isTrue,
    );
    expect(await logger.readRecent(), isNotEmpty);
  });

  test('prunes events older than seven days during initialization', () async {
    await logger.log(
      severity: DiagnosticSeverity.info,
      feature: DiagnosticFeature.app,
      eventCode: DiagnosticCode.appStarted,
      outcome: DiagnosticOutcome.succeeded,
    );
    now = now.add(const Duration(days: 8));
    final restarted = DiagnosticLogger(directory: directory, clock: () => now);

    await restarted.initialize();

    expect(await restarted.readRecent(), isEmpty);
  });

  test('physically prunes expired events during ongoing writes', () async {
    await logger.log(
      severity: DiagnosticSeverity.info,
      feature: DiagnosticFeature.app,
      eventCode: DiagnosticCode.appStarted,
      outcome: DiagnosticOutcome.succeeded,
    );
    now = now.add(const Duration(days: 8));

    await logger.log(
      severity: DiagnosticSeverity.info,
      feature: DiagnosticFeature.reporting,
      eventCode: DiagnosticCode.reportOpened,
      outcome: DiagnosticOutcome.succeeded,
    );

    final persisted = await File(
      '${directory.path}/diagnostics.jsonl',
    ).readAsString();
    expect(persisted, isNot(contains('app.started')));
    expect(persisted, contains('report.opened'));
  });
}
