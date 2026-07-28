import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lootr/core/reporting/bug_report.dart';
import 'package:lootr/core/reporting/feedback_report_client.dart';

void main() {
  test('submits the report to the configured relay', () async {
    late http.MultipartRequest sent;
    final client = _Client((request) async {
      sent = request as http.MultipartRequest;
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            jsonEncode({
              'reportId': 'report-1',
              'issueNumber': 17,
              'issueUrl': 'https://github.com/joashdev/lootr/issues/17',
            }),
          ),
        ),
        201,
      );
    });
    final submitter = CloudflareFeedbackSubmitter(
      endpoint: Uri.parse('https://reports.example.test/reports'),
      client: client,
    );

    final result = await submitter.submit(_report());

    expect(sent.url.path, '/reports');
    expect(
      jsonDecode(sent.fields['report']!)['type'],
      FeedbackType.feature.name,
    );
    expect(result.issueNumber, 17);
    expect(result.reportId, 'report-1');
  });

  test('requires public disclosure consent before sending', () async {
    final submitter = CloudflareFeedbackSubmitter(
      endpoint: Uri.parse('https://reports.example.test/reports'),
      client: _Client((_) async => throw StateError('must not send')),
    );

    expect(
      () => submitter.submit(_report(publicReportConsent: false)),
      throwsA(
        isA<FeedbackSubmissionException>().having(
          (error) => error.code,
          'code',
          'consent_required',
        ),
      ),
    );
  });
}

PublicFeedbackReport _report({bool publicReportConsent = true}) {
  return PublicFeedbackReport(
    id: 'report-1',
    type: FeedbackType.feature,
    title: 'Recurring split rules',
    description: 'Let me reuse a split across future transactions.',
    app: const BugReportDetails(
      version: '0.1.0-alpha.1',
      buildNumber: '42',
      platform: 'Android',
    ),
    diagnostics: const [],
    publicReportConsent: publicReportConsent,
    persistenceConsent: true,
    publicScreenshotConsent: false,
  );
}

class _Client extends http.BaseClient {
  _Client(this._send);

  final Future<http.StreamedResponse> Function(http.BaseRequest request) _send;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _send(request);
}
