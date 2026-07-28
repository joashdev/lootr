import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'diagnostic_logger.dart';

const lootrRepositoryUrl = 'https://github.com/joashdev/lootr';
const lootrPrivateVulnerabilityUrl =
    '$lootrRepositoryUrl/security/advisories/new';

enum FeedbackType { bug, feature, layout }

extension FeedbackTypeDetails on FeedbackType {
  String get label => switch (this) {
    FeedbackType.bug => 'Bug',
    FeedbackType.feature => 'Feature',
    FeedbackType.layout => 'Layout',
  };

  String get titlePrefix => '[$label]';

  String get githubLabel => switch (this) {
    FeedbackType.bug => 'bug',
    FeedbackType.feature || FeedbackType.layout => 'enhancement',
  };

  bool get diagnosticsByDefault => this == FeedbackType.bug;
}

class BugReportDetails {
  const BugReportDetails({
    required this.version,
    required this.buildNumber,
    required this.platform,
  });

  final String version;
  final String buildNumber;
  final String platform;
}

class PublicFeedbackReport {
  const PublicFeedbackReport({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.app,
    required this.diagnostics,
    required this.publicReportConsent,
    required this.persistenceConsent,
    required this.publicScreenshotConsent,
  });

  final String id;
  final FeedbackType type;
  final String title;
  final String description;
  final BugReportDetails app;
  final List<DiagnosticEvent> diagnostics;
  final bool publicReportConsent;
  final bool persistenceConsent;
  final bool publicScreenshotConsent;

  String get issueTitle => '${type.titlePrefix} ${title.trim()}';

  String issueBody({String? screenshotUrl}) {
    final diagnosticsMarkdown = diagnostics.isEmpty
        ? '_No diagnostics included._'
        : [
            '<details>',
            '<summary>Sanitized diagnostics (${diagnostics.length})</summary>',
            '',
            '```json',
            const JsonEncoder.withIndent(
              '  ',
            ).convert(diagnostics.map((event) => event.toJson()).toList()),
            '```',
            '</details>',
          ].join('\n');
    final screenshotMarkdown = screenshotUrl == null
        ? '_No screenshot included._'
        : '![User-approved public screenshot]($screenshotUrl)\n\n'
              '_The screenshot is scheduled for deletion after 30 days._';

    return [
      '> This issue was submitted from Lootr after the reporter reviewed the exact public payload and confirmed that private financial and personal information was removed.',
      '',
      '**Report ID:** `$id`',
      '**Type:** ${type.name}',
      '',
      '## Request',
      '',
      description.trim(),
      '',
      '## App context',
      '',
      '- Version: ${app.version}',
      '- Build: ${app.buildNumber}',
      '- Platform: ${app.platform}',
      '',
      '## Screenshot',
      '',
      screenshotMarkdown,
      '',
      '## Diagnostics',
      '',
      diagnosticsMarkdown,
      '',
      '## Public disclosure',
      '',
      '- [x] The reporter reviewed this issue and removed private financial and personal information.',
      '- [x] The reporter understands public content may remain in caches or notifications after editing or deletion.',
    ].join('\n');
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title.trim(),
    'description': description.trim(),
    'app': {
      'version': app.version,
      'build': app.buildNumber,
      'platform': app.platform,
    },
    'diagnostics': diagnostics.map((event) => event.toJson()).toList(),
    'consent': {
      'publicReport': publicReportConsent,
      'persistence': persistenceConsent,
      'publicScreenshot': publicScreenshotConsent,
    },
  };
}

String bugReportPlatform(TargetPlatform platform) => switch (platform) {
  TargetPlatform.android => 'Android',
  TargetPlatform.iOS => 'iOS',
  TargetPlatform.macOS => 'macOS',
  TargetPlatform.windows => 'Windows',
  TargetPlatform.linux => 'Linux',
  TargetPlatform.fuchsia => 'Fuchsia',
};

String createReportId({DateTime? now, Random? random}) {
  final timestamp = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
  final source = random ?? Random.secure();
  final suffix = List.generate(
    12,
    (_) => source.nextInt(16).toRadixString(16),
  ).join();
  return 'report-$timestamp-$suffix';
}

Uri buildBugReportUri(
  BugReportDetails details, {
  FeedbackType type = FeedbackType.bug,
}) {
  final body =
      '''
> GitHub issues are public. Remove names, balances, transaction details, account numbers, receipt images, and other private financial data.

## Request

<!-- Describe the bug, feature, or layout change. -->

## App context

- Version: ${details.version}
- Build: ${details.buildNumber}
- Platform: ${details.platform}

## Privacy check

- [ ] I removed private financial and personal information from this report.
- [ ] I understand public content may remain cached after editing or deletion.
''';

  return Uri.https('github.com', '/joashdev/lootr/issues/new', {
    'title': '${type.titlePrefix} ',
    'labels': type.githubLabel,
    'body': body,
  });
}

Uri buildFeedbackFallbackUri(PublicFeedbackReport report) {
  return Uri.https('github.com', '/joashdev/lootr/issues/new', {
    'title': report.issueTitle,
    'labels': report.type.githubLabel,
    'body': report.issueBody(),
  });
}
