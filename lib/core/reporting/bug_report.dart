import 'package:flutter/foundation.dart';

const lootrRepositoryUrl = 'https://github.com/joashdev/lootr';

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

String bugReportPlatform(TargetPlatform platform) => switch (platform) {
  TargetPlatform.android => 'Android',
  TargetPlatform.iOS => 'iOS',
  TargetPlatform.macOS => 'macOS',
  TargetPlatform.windows => 'Windows',
  TargetPlatform.linux => 'Linux',
  TargetPlatform.fuchsia => 'Fuchsia',
};

Uri buildBugReportUri(BugReportDetails details) {
  final body =
      '''
> GitHub issues are public. Remove names, balances, transaction details, account numbers, receipt images, and other private financial data.

## What happened?

<!-- Describe the problem. -->

## What did you expect?

<!-- Describe the expected behavior. -->

## Steps to reproduce

1.
2.
3.

## App context

- Version: ${details.version}
- Build: ${details.buildNumber}
- Platform: ${details.platform}

## Privacy check

- [ ] I removed private financial and personal information from this report.
''';

  return Uri.https('github.com', '/joashdev/lootr/issues/new', {
    'title': '[Bug] ',
    'labels': 'bug',
    'body': body,
  });
}
