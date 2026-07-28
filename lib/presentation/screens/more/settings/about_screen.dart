import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../application/providers/app_info_provider.dart';
import '../../../../core/reporting/bug_report.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../shared/components/buttons/ghost_button.dart';
import '../../../shared/components/buttons/secondary_button.dart';
import 'feedback_report_sheet.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lootrColors = context.lootrColors;
    final colorScheme = Theme.of(context).colorScheme;
    final packageInfo = ref.watch(packageInfoProvider);
    final version = packageInfo.when(
      data: (value) => value.version,
      error: (error, stackTrace) => 'Unknown',
      loading: () => 'Loading…',
    );
    final buildNumber = packageInfo.when(
      data: (value) => value.buildNumber,
      error: (error, stackTrace) => '—',
      loading: () => '—',
    );

    return Scaffold(
      appBar: AppBar(centerTitle: false, title: const Text('About')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.space8),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    LucideIcons.coins,
                    size: 40,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space6),
                Text(
                  'Lootr',
                  style: AppTypography.h1.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.space1),
                Text(
                  'Version $version (Build $buildNumber)',
                  style: AppTypography.body.copyWith(
                    color: lootrColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space6),
                _DetailRow(label: 'Version', value: version),
                const SizedBox(height: AppSpacing.space2),
                _DetailRow(label: 'Build', value: buildNumber),
                const SizedBox(height: AppSpacing.space6),
                SizedBox(
                  width: double.infinity,
                  child: SecondaryButton(
                    label: 'Send feedback',
                    onPressed: () =>
                        _showFeedback(context, version, buildNumber),
                    icon: const Icon(LucideIcons.messageSquarePlus, size: 18),
                  ),
                ),
                const SizedBox(height: AppSpacing.space3),
                SizedBox(
                  width: double.infinity,
                  child: SecondaryButton(
                    label: 'License & source · AGPL-3.0',
                    onPressed: () => _showProjectLicense(context, ref),
                    icon: const Icon(LucideIcons.code2, size: 18),
                  ),
                ),
                const SizedBox(height: AppSpacing.space3),
                SizedBox(
                  width: double.infinity,
                  child: SecondaryButton(
                    label: 'Third-party licenses',
                    onPressed: () => showLicensePage(
                      context: context,
                      applicationName: 'Lootr',
                      applicationVersion: version,
                    ),
                    icon: const Icon(LucideIcons.scrollText, size: 18),
                  ),
                ),
                const SizedBox(height: AppSpacing.space3),
                SizedBox(
                  width: double.infinity,
                  child: SecondaryButton(
                    label: 'Privacy Policy',
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Privacy Policy'),
                        content: const Text(
                          'Lootr keeps your data on-device in V1. Sync, backup, and data sharing stay opt-in as future features.',
                        ),
                        actions: [
                          GhostButton(
                            label: 'Close',
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            isExpanded: false,
                          ),
                        ],
                      ),
                    ),
                    icon: const Icon(LucideIcons.shield, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showFeedback(
    BuildContext context,
    String version,
    String buildNumber,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.92,
        child: FeedbackReportSheet(version: version, buildNumber: buildNumber),
      ),
    );
  }

  Future<void> _showProjectLicense(BuildContext context, WidgetRef ref) async {
    final openSource = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lootr license'),
        content: const Text(
          'Copyright © 2026 Joashdev and Lootr contributors.\n\n'
          'Lootr is free software under the GNU Affero General Public License, '
          'version 3 or later. It comes without any warranty, including '
          'merchantability or fitness for a particular purpose.',
        ),
        actions: [
          GhostButton(
            label: 'Close',
            onPressed: () => Navigator.of(dialogContext).pop(false),
            isExpanded: false,
          ),
          GhostButton(
            label: 'View license & source',
            onPressed: () => Navigator.of(dialogContext).pop(true),
            isExpanded: false,
          ),
        ],
      ),
    );
    if (openSource == true && context.mounted) {
      await _openUrl(
        context,
        ref,
        Uri.parse('$lootrRepositoryUrl/blob/main/LICENSE'),
      );
    }
  }

  Future<void> _openUrl(BuildContext context, WidgetRef ref, Uri uri) async {
    var opened = false;
    try {
      opened = await ref.read(externalUrlLauncherProvider)(uri);
    } on Exception {
      // The same neutral message covers missing browsers and platform errors.
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open GitHub. Try again later.'),
        ),
      );
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final lootrColors = context.lootrColors;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.body.copyWith(color: lootrColors.textSecondary),
        ),
        Text(
          value,
          style: AppTypography.bodyMedium.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
