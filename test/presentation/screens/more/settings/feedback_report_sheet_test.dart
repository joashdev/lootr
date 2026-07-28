import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/application/providers/app_info_provider.dart';
import 'package:lootr/application/providers/feedback_report_provider.dart';
import 'package:lootr/core/reporting/bug_report.dart';
import 'package:lootr/core/reporting/feedback_report_client.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/presentation/screens/more/settings/feedback_report_sheet.dart';

void main() {
  testWidgets('reviews and publishes a feature request in app', (tester) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final submitter = _Submitter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          feedbackSubmitterProvider.overrideWithValue(submitter),
          turnstileTokenRequesterProvider.overrideWithValue(
            (_) async => 'verified-token',
          ),
          externalUrlLauncherProvider.overrideWithValue((_) async => true),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: FeedbackReportSheet(
              version: '0.1.0-alpha.1',
              buildNumber: '42',
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Feature'));
    await tester.enterText(find.byType(TextField).at(0), 'Add split rules');
    await tester.enterText(
      find.byType(TextField).at(1),
      'Let me reuse a split across future transactions.',
    );

    final diagnosticsSwitch = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(diagnosticsSwitch.value, isFalse);

    await tester.ensureVisible(find.text('Review public report'));
    await tester.tap(find.text('Review public report'));
    await tester.pumpAndSettle();

    expect(find.text('[Feature] Add split rules'), findsOneWidget);
    expect(find.textContaining('## Public disclosure'), findsOneWidget);

    final consents = find.byType(CheckboxListTile);
    expect(consents, findsNWidgets(2));
    await tester.ensureVisible(consents.at(0));
    await tester.pumpAndSettle();
    await tester.tap(consents.at(0));
    await tester.ensureVisible(consents.at(1));
    await tester.pumpAndSettle();
    await tester.tap(consents.at(1));
    await tester.pump();
    await tester.tap(find.text('Publish public report'));
    await tester.pumpAndSettle();

    expect(submitter.report?.type, FeedbackType.feature);
    expect(submitter.report?.diagnostics, isEmpty);
    expect(submitter.report?.publicReportConsent, isTrue);
    expect(submitter.turnstileToken, 'verified-token');
    expect(find.text('Report #17 published'), findsOneWidget);
  });
}

class _Submitter implements FeedbackSubmitter {
  PublicFeedbackReport? report;
  String? turnstileToken;

  @override
  Future<FeedbackSubmissionResult> submit(
    PublicFeedbackReport report, {
    required String turnstileToken,
    Uint8List? screenshot,
  }) async {
    this.report = report;
    this.turnstileToken = turnstileToken;
    return FeedbackSubmissionResult(
      reportId: report.id,
      issueNumber: 17,
      issueUrl: Uri.parse('https://github.com/joashdev/lootr/issues/17'),
    );
  }
}
