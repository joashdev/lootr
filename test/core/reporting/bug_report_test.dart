import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/core/reporting/bug_report.dart';

void main() {
  test('builds a privacy-safe GitHub bug report URL with app context', () {
    final uri = buildBugReportUri(
      const BugReportDetails(
        version: '0.1.0-alpha.1',
        buildNumber: '42',
        platform: 'Android',
      ),
    );

    expect(uri.origin, 'https://github.com');
    expect(uri.path, '/joashdev/lootr/issues/new');
    expect(uri.queryParameters['template'], 'bug_report.md');
    expect(uri.queryParameters['title'], '[Bug] ');
    expect(uri.queryParameters['labels'], 'bug');
    expect(uri.queryParameters['body'], contains('Version: 0.1.0-alpha.1'));
    expect(uri.queryParameters['body'], contains('Build: 42'));
    expect(uri.queryParameters['body'], contains('Platform: Android'));
    expect(uri.queryParameters['body'], contains('GitHub issues are public'));
  });

  test('maps Flutter platforms to report labels', () {
    expect(bugReportPlatform(TargetPlatform.android), 'Android');
    expect(bugReportPlatform(TargetPlatform.iOS), 'iOS');
    expect(bugReportPlatform(TargetPlatform.linux), 'Linux');
  });
}
