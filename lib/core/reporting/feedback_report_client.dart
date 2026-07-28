import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'bug_report.dart';

class FeedbackSubmissionResult {
  const FeedbackSubmissionResult({
    required this.reportId,
    required this.issueNumber,
    required this.issueUrl,
  });

  final String reportId;
  final int issueNumber;
  final Uri issueUrl;
}

class FeedbackSubmissionException implements Exception {
  const FeedbackSubmissionException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'FeedbackSubmissionException($code)';
}

abstract interface class FeedbackSubmitter {
  Future<FeedbackSubmissionResult> submit(
    PublicFeedbackReport report, {
    required String turnstileToken,
    Uint8List? screenshot,
  });
}

class CloudflareFeedbackSubmitter implements FeedbackSubmitter {
  const CloudflareFeedbackSubmitter({
    required this.endpoint,
    required this.client,
  });

  final Uri? endpoint;
  final http.Client client;

  @override
  Future<FeedbackSubmissionResult> submit(
    PublicFeedbackReport report, {
    required String turnstileToken,
    Uint8List? screenshot,
  }) async {
    final target = endpoint;
    if (target == null) {
      throw const FeedbackSubmissionException(
        'not_configured',
        'In-app reporting is not configured in this build.',
      );
    }
    if (!report.publicReportConsent || !report.persistenceConsent) {
      throw const FeedbackSubmissionException(
        'consent_required',
        'Confirm both public disclosure statements before sending.',
      );
    }
    if (screenshot != null && !report.publicScreenshotConsent) {
      throw const FeedbackSubmissionException(
        'screenshot_consent_required',
        'Confirm that the screenshot may be published.',
      );
    }
    if (turnstileToken.isEmpty ||
        utf8.encode(turnstileToken).lengthInBytes > 2048) {
      throw const FeedbackSubmissionException(
        'turnstile_required',
        'Complete the anti-abuse check before sending.',
      );
    }

    final request = http.MultipartRequest('POST', target)
      ..fields['report'] = jsonEncode(report.toJson())
      ..fields['turnstileToken'] = turnstileToken;
    if (screenshot != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'screenshot',
          screenshot,
          filename: '${report.id}.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      );
    }

    final streamed = await client.send(request);
    final response = await http.Response.fromStream(streamed);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 201) {
      throw FeedbackSubmissionException(
        decoded['error'] as String? ?? 'submission_failed',
        decoded['message'] as String? ?? 'Could not send the report.',
      );
    }

    return FeedbackSubmissionResult(
      reportId: decoded['reportId'] as String,
      issueNumber: decoded['issueNumber'] as int,
      issueUrl: Uri.parse(decoded['issueUrl'] as String),
    );
  }
}
