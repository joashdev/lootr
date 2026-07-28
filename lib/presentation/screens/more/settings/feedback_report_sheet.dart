import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../application/providers/app_info_provider.dart';
import '../../../../application/providers/feedback_report_provider.dart';
import '../../../../core/reporting/bug_report.dart';
import '../../../../core/reporting/diagnostic_logger.dart';
import '../../../../core/reporting/feedback_report_client.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../shared/components/buttons/ghost_button.dart';
import '../../../shared/components/buttons/primary_button.dart';
import '../../../shared/components/buttons/secondary_button.dart';
import 'turnstile_challenge_sheet.dart';

enum _ReportStage { compose, preview, submitted }

typedef TurnstileTokenRequester =
    Future<String?> Function(BuildContext context);

final turnstileTokenRequesterProvider = Provider<TurnstileTokenRequester>((
  ref,
) {
  final challengeUri = ref.watch(feedbackChallengeUriProvider);
  return (context) {
    if (challengeUri == null) {
      throw const FeedbackSubmissionException(
        'not_configured',
        'In-app reporting is not configured in this build.',
      );
    }
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TurnstileChallengeSheet(challengeUri: challengeUri),
    );
  };
});

class FeedbackReportSheet extends ConsumerStatefulWidget {
  const FeedbackReportSheet({
    super.key,
    required this.version,
    required this.buildNumber,
  });

  final String version;
  final String buildNumber;

  @override
  ConsumerState<FeedbackReportSheet> createState() =>
      _FeedbackReportSheetState();
}

class _FeedbackReportSheetState extends ConsumerState<FeedbackReportSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _reportId = createReportId();
  FeedbackType _type = FeedbackType.bug;
  _ReportStage _stage = _ReportStage.compose;
  bool _includeDiagnostics = true;
  bool _publicConsent = false;
  bool _persistenceConsent = false;
  bool _screenshotConsent = false;
  bool _busy = false;
  String? _error;
  Uint8List? _screenshot;
  List<DiagnosticEvent> _diagnostics = const [];
  FeedbackSubmissionResult? _result;

  @override
  void initState() {
    super.initState();
    unawaited(
      ref
          .read(diagnosticLoggerProvider)
          .log(
            severity: DiagnosticSeverity.info,
            feature: DiagnosticFeature.reporting,
            eventCode: DiagnosticCode.reportOpened,
            outcome: DiagnosticOutcome.succeeded,
          ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  BugReportDetails get _app => BugReportDetails(
    version: widget.version,
    buildNumber: widget.buildNumber,
    platform: bugReportPlatform(defaultTargetPlatform),
  );

  PublicFeedbackReport _report({required bool confirmed}) {
    return PublicFeedbackReport(
      id: _reportId,
      type: _type,
      title: _titleController.text,
      description: _descriptionController.text,
      app: _app,
      diagnostics: _includeDiagnostics ? _diagnostics : const [],
      publicReportConsent: confirmed && _publicConsent,
      persistenceConsent: confirmed && _persistenceConsent,
      publicScreenshotConsent:
          confirmed && _screenshot != null && _screenshotConsent,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.pagePaddingMobile,
          AppSpacing.space2,
          AppSpacing.pagePaddingMobile,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.space4,
        ),
        child: switch (_stage) {
          _ReportStage.compose => _buildCompose(context),
          _ReportStage.preview => _buildPreview(context),
          _ReportStage.submitted => _buildSubmitted(context),
        },
      ),
    );
  }

  Widget _buildCompose(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Send public feedback', style: AppTypography.h2),
          const SizedBox(height: AppSpacing.space2),
          Text(
            'Create a public GitHub issue without leaving Lootr.',
            style: AppTypography.body.copyWith(
              color: context.lootrColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.space5),
          SegmentedButton<FeedbackType>(
            segments: const [
              ButtonSegment(
                value: FeedbackType.bug,
                label: Text('Bug'),
                icon: Icon(LucideIcons.bug),
              ),
              ButtonSegment(
                value: FeedbackType.feature,
                label: Text('Feature'),
                icon: Icon(LucideIcons.sparkles),
              ),
              ButtonSegment(
                value: FeedbackType.layout,
                label: Text('Layout'),
                icon: Icon(LucideIcons.layoutPanelTop),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (selected) {
              final next = selected.single;
              setState(() {
                _type = next;
                _includeDiagnostics = next.diagnosticsByDefault;
              });
            },
          ),
          const SizedBox(height: AppSpacing.space5),
          TextField(
            controller: _titleController,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Short title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.space3),
          TextField(
            controller: _descriptionController,
            minLines: 5,
            maxLines: 9,
            maxLength: 4000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: switch (_type) {
                FeedbackType.bug => 'What happened and how to reproduce it?',
                FeedbackType.feature => 'What would you like Lootr to do?',
                FeedbackType.layout =>
                  'What should look or behave differently?',
              },
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _includeDiagnostics,
            onChanged: (value) => setState(() => _includeDiagnostics = value),
            title: const Text('Include sanitized diagnostics'),
            subtitle: Text(
              _type == FeedbackType.bug
                  ? 'Recommended for bugs. No financial values are logged.'
                  : 'Off by default for feature and layout requests.',
            ),
          ),
          const SizedBox(height: AppSpacing.space2),
          if (_screenshot == null)
            SecondaryButton(
              label: 'Add screenshot',
              icon: const Icon(LucideIcons.imagePlus, size: 18),
              onPressed: _busy ? null : _pickScreenshot,
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _screenshot!,
                height: 180,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: AppSpacing.space2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${(_screenshot!.lengthInBytes / 1024).ceil()} KiB · JPEG',
                    style: AppTypography.caption.copyWith(
                      color: context.lootrColors.textSecondary,
                    ),
                  ),
                ),
                GhostButton(
                  label: 'Remove',
                  isExpanded: false,
                  onPressed: () => setState(() {
                    _screenshot = null;
                    _screenshotConsent = false;
                  }),
                ),
              ],
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: AppSpacing.space3),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_error case final error?) ...[
            const SizedBox(height: AppSpacing.space3),
            Text(
              error,
              style: AppTypography.body.copyWith(color: colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.space5),
          Container(
            padding: const EdgeInsets.all(AppSpacing.space4),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This report will be public. Do not include balances, '
                  'transactions, account details, receipts, database files, '
                  'tokens, or other private information.',
                ),
                const SizedBox(height: AppSpacing.space2),
                GhostButton(
                  label: 'Report a security vulnerability privately',
                  isExpanded: false,
                  onPressed: () =>
                      _openExternal(Uri.parse(lootrPrivateVulnerabilityUrl)),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.space4),
          PrimaryButton(
            label: 'Review public report',
            icon: const Icon(LucideIcons.eye, size: 18),
            onPressed: _busy ? null : _openPreview,
          ),
          const SizedBox(height: AppSpacing.space2),
          GhostButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    final report = _report(confirmed: false);
    final screenshotPlaceholder = _screenshot == null
        ? null
        : 'https://public-attachment-link-added-after-upload';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: _busy
                  ? null
                  : () => setState(() => _stage = _ReportStage.compose),
              icon: const Icon(LucideIcons.arrowLeft),
            ),
            const SizedBox(width: AppSpacing.space2),
            Expanded(
              child: Text('Review public issue', style: AppTypography.h2),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space2),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Title', style: AppTypography.captionMedium),
                const SizedBox(height: AppSpacing.space1),
                SelectableText(report.issueTitle, style: AppTypography.body),
                const SizedBox(height: AppSpacing.space4),
                Text('Issue body', style: AppTypography.captionMedium),
                const SizedBox(height: AppSpacing.space1),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.space3),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: SelectableText(
                    report.issueBody(screenshotUrl: screenshotPlaceholder),
                    style: AppTypography.mono,
                  ),
                ),
                if (_screenshot case final screenshot?) ...[
                  const SizedBox(height: AppSpacing.space4),
                  Text('Public screenshot', style: AppTypography.captionMedium),
                  const SizedBox(height: AppSpacing.space2),
                  Image.memory(screenshot, height: 180, fit: BoxFit.contain),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _screenshotConsent,
                    onChanged: _busy
                        ? null
                        : (value) => setState(
                            () => _screenshotConsent = value ?? false,
                          ),
                    title: const Text(
                      'Publish this screenshot for up to 30 days.',
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.space3),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _publicConsent,
                  onChanged: _busy
                      ? null
                      : (value) =>
                            setState(() => _publicConsent = value ?? false),
                  title: const Text(
                    'I reviewed this report and removed private financial '
                    'and personal information.',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _persistenceConsent,
                  onChanged: _busy
                      ? null
                      : (value) => setState(
                          () => _persistenceConsent = value ?? false,
                        ),
                  title: const Text(
                    'I understand this public report may remain in caches or '
                    'notifications after editing or deletion.',
                  ),
                ),
                if (_error case final error?) ...[
                  const SizedBox(height: AppSpacing.space2),
                  Text(
                    error,
                    style: AppTypography.body.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  SecondaryButton(
                    label: 'Open GitHub instead',
                    onPressed: _busy ? null : _openGitHubFallback,
                    icon: const Icon(LucideIcons.externalLink, size: 18),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.space3),
        PrimaryButton(
          label: 'Publish public report',
          icon: const Icon(LucideIcons.send, size: 18),
          isLoading: _busy,
          onPressed: _canSubmit ? _submit : null,
        ),
      ],
    );
  }

  Widget _buildSubmitted(BuildContext context) {
    final result = _result!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.space4),
        Icon(
          LucideIcons.circleCheck,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: AppSpacing.space4),
        Text(
          'Report #${result.issueNumber} published',
          style: AppTypography.h2,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.space2),
        Text(
          'Thank you. The report is now public on the Lootr issue tracker.',
          style: AppTypography.body.copyWith(
            color: context.lootrColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.space5),
        SecondaryButton(
          label: 'View public issue',
          onPressed: () => _openExternal(result.issueUrl),
          icon: const Icon(LucideIcons.externalLink, size: 18),
        ),
        const SizedBox(height: AppSpacing.space2),
        PrimaryButton(
          label: 'Done',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  bool get _canSubmit =>
      !_busy &&
      _publicConsent &&
      _persistenceConsent &&
      (_screenshot == null || _screenshotConsent);

  Future<void> _pickScreenshot() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final selected = await ref.read(screenshotSelectorProvider)();
      if (!mounted) return;
      setState(() => _screenshot = selected);
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Exception {
      if (mounted) {
        setState(() => _error = 'Could not prepare that screenshot.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPreview() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    if (title.isEmpty || description.isEmpty) {
      setState(() => _error = 'Add a title and description before reviewing.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final diagnostics = _includeDiagnostics
        ? await ref.read(diagnosticLoggerProvider).readRecent()
        : const <DiagnosticEvent>[];
    if (!mounted) return;
    setState(() {
      _diagnostics = diagnostics;
      _busy = false;
      _stage = _ReportStage.preview;
    });
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final logger = ref.read(diagnosticLoggerProvider);
    final stopwatch = Stopwatch()..start();

    try {
      final turnstileToken = await ref.read(turnstileTokenRequesterProvider)(
        context,
      );
      if (turnstileToken == null || !mounted) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      await logger.log(
        severity: DiagnosticSeverity.info,
        feature: DiagnosticFeature.reporting,
        eventCode: DiagnosticCode.reportSubmitStarted,
        outcome: DiagnosticOutcome.started,
      );
      final result = await ref
          .read(feedbackSubmitterProvider)
          .submit(
            _report(confirmed: true),
            turnstileToken: turnstileToken,
            screenshot: _screenshot,
          );
      await logger.log(
        severity: DiagnosticSeverity.info,
        feature: DiagnosticFeature.reporting,
        eventCode: DiagnosticCode.reportSubmitSucceeded,
        outcome: DiagnosticOutcome.succeeded,
        durationMs: stopwatch.elapsedMilliseconds,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _busy = false;
        _stage = _ReportStage.submitted;
      });
    } on FeedbackSubmissionException catch (error) {
      await logger.log(
        severity: DiagnosticSeverity.warning,
        feature: DiagnosticFeature.reporting,
        eventCode: DiagnosticCode.reportSubmitFailed,
        outcome: DiagnosticOutcome.failed,
        durationMs: stopwatch.elapsedMilliseconds,
      );
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.message;
        });
      }
    } on Exception {
      await logger.log(
        severity: DiagnosticSeverity.warning,
        feature: DiagnosticFeature.reporting,
        eventCode: DiagnosticCode.reportSubmitFailed,
        outcome: DiagnosticOutcome.failed,
        durationMs: stopwatch.elapsedMilliseconds,
      );
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not publish the report. Try again.';
        });
      }
    }
  }

  Future<void> _openGitHubFallback() async {
    await _openExternal(buildFeedbackFallbackUri(_report(confirmed: true)));
  }

  Future<void> _openExternal(Uri uri) async {
    var opened = false;
    try {
      opened = await ref.read(externalUrlLauncherProvider)(uri);
    } on Exception {
      // The same neutral message covers missing browsers and platform errors.
    }
    if (!opened && mounted) {
      setState(() => _error = 'Could not open GitHub. Try again later.');
    }
  }
}
