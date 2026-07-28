import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/core/reporting/bug_report.dart';
import 'package:lootr/core/reporting/diagnostic_logger.dart';

void main() {
  test('renders the exact public GitHub issue payload', () {
    final report = PublicFeedbackReport(
      id: 'report-123-abc',
      type: FeedbackType.layout,
      title: 'Move the add button',
      description: 'The add button should sit above the transaction list.',
      app: const BugReportDetails(
        version: '0.1.0-alpha.1',
        buildNumber: '42',
        platform: 'Android',
      ),
      diagnostics: [
        DiagnosticEvent(
          timestamp: DateTime.utc(2026, 7, 27),
          severity: DiagnosticSeverity.info,
          feature: DiagnosticFeature.reporting,
          eventCode: DiagnosticCode.reportOpened,
          outcome: DiagnosticOutcome.succeeded,
        ),
      ],
      publicReportConsent: true,
      persistenceConsent: true,
      publicScreenshotConsent: false,
    );

    expect(report.issueTitle, '[Layout] Move the add button');
    expect(report.type.githubLabel, 'enhancement');
    expect(report.issueBody(), contains('report-123-abc'));
    expect(report.issueBody(), contains('Version: 0.1.0-alpha.1'));
    expect(report.issueBody(), contains('"eventCode": "report.opened"'));
    expect(report.issueBody(), contains('_No screenshot included._'));
    expect(report.toJson()['type'], 'layout');
  });

  test('builds a privacy-safe GitHub fallback URL with app context', () {
    final uri = buildBugReportUri(
      const BugReportDetails(
        version: '0.1.0-alpha.1',
        buildNumber: '42',
        platform: 'Android',
      ),
    );

    expect(uri.origin, 'https://github.com');
    expect(uri.path, '/joashdev/lootr/issues/new');
    expect(uri.queryParameters['title'], '[Bug] ');
    expect(uri.queryParameters['labels'], 'bug');
    expect(uri.queryParameters['body'], contains('Version: 0.1.0-alpha.1'));
    expect(uri.queryParameters['body'], contains('Build: 42'));
    expect(uri.queryParameters['body'], contains('Platform: Android'));
    expect(uri.queryParameters['body'], contains('GitHub issues are public'));
  });

  test('diagnostic defaults match report type', () {
    expect(FeedbackType.bug.diagnosticsByDefault, isTrue);
    expect(FeedbackType.feature.diagnosticsByDefault, isFalse);
    expect(FeedbackType.layout.diagnosticsByDefault, isFalse);
  });

  test('builds an in-memory GitHub fallback from reviewed content', () {
    final report = PublicFeedbackReport(
      id: 'report-123',
      type: FeedbackType.feature,
      title: 'Add split rules',
      description: 'Let me reuse a split across future transactions.',
      app: const BugReportDetails(
        version: '0.1.0-alpha.1',
        buildNumber: '42',
        platform: 'Android',
      ),
      diagnostics: const [],
      publicReportConsent: true,
      persistenceConsent: true,
      publicScreenshotConsent: false,
    );

    final uri = buildFeedbackFallbackUri(report);

    expect(uri.path, '/joashdev/lootr/issues/new');
    expect(uri.queryParameters['title'], '[Feature] Add split rules');
    expect(uri.queryParameters['labels'], 'enhancement');
    expect(
      uri.queryParameters['body'],
      contains('Let me reuse a split across future transactions.'),
    );
  });

  test('maps Flutter platforms to report labels', () {
    expect(bugReportPlatform(TargetPlatform.android), 'Android');
    expect(bugReportPlatform(TargetPlatform.iOS), 'iOS');
    expect(bugReportPlatform(TargetPlatform.linux), 'Linux');
  });
}
