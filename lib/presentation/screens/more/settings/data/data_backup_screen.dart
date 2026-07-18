import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../application/migration/migration_models.dart';
import '../../../../../application/migration/migration_coordinator.dart';
import '../../../../../application/providers/migration_providers.dart';
import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/typography.dart';
import 'migration_ui.dart';

class DataBackupScreen extends ConsumerWidget {
  const DataBackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runs = ref.watch(migrationRunsProvider);
    return Scaffold(
      appBar: AppBar(centerTitle: false, title: const Text('Data & backup')),
      body: MigrationPageBody(
        children: [
          const MigrationHeading(
            title: 'Your data stays yours',
            body:
                'Import, back up, restore, and export without sending your '
                'financial data to a server.',
          ),
          const SizedBox(height: AppSpacing.space5),
          ...runs.when(
            data: (items) {
              final resumable = items.where((run) => !run.isTerminal).toList();
              if (resumable.isEmpty) return const <Widget>[];
              final run = resumable.first;
              return [
                _ResumeCard(run: run),
                const SizedBox(height: AppSpacing.space4),
              ];
            },
            loading: () => const <Widget>[],
            error: (_, _) => const <Widget>[],
          ),
          _DataActionTile(
            key: const ValueKey('data-import-cashew'),
            icon: LucideIcons.import,
            title: 'Import from Cashew',
            subtitle:
                'Analyze a Cashew data file privately before anything is added.',
            onTap: () => context.push('/more/settings/data/import-cashew'),
          ),
          const SizedBox(height: AppSpacing.space3),
          _DataActionTile(
            key: const ValueKey('data-create-backup'),
            icon: LucideIcons.archive,
            title: 'Create Lootr backup',
            subtitle: 'Create a complete encrypted copy of your Lootr data.',
            onTap: () => _runPortabilityAction(
              context,
              ref,
              (service) => service.createBackup(),
            ),
          ),
          const SizedBox(height: AppSpacing.space3),
          _DataActionTile(
            key: const ValueKey('data-restore-backup'),
            icon: LucideIcons.rotateCcw,
            title: 'Restore Lootr backup',
            subtitle:
                'Replace this workspace only after the backup is verified.',
            onTap: () => _confirmRestore(context, ref),
          ),
          const SizedBox(height: AppSpacing.space3),
          _DataActionTile(
            key: const ValueKey('data-export-csv'),
            icon: LucideIcons.fileSpreadsheet,
            title: 'Export transaction CSV',
            subtitle: 'Create a readable, currency-aware transaction export.',
            onTap: () => _runPortabilityAction(
              context,
              ref,
              (service) => service.exportTransactionsCsv(),
            ),
          ),
          const SizedBox(height: AppSpacing.space6),
          Semantics(
            header: true,
            child: Text('Previous imports', style: AppTypography.h2),
          ),
          const SizedBox(height: AppSpacing.space3),
          runs.when(
            data: (items) {
              final completed = items.where((run) => run.isTerminal).toList();
              if (completed.isEmpty) {
                return Text(
                  'No previous imports yet.',
                  style: AppTypography.body.copyWith(
                    color: context.lootrColors.textSecondary,
                  ),
                );
              }
              return Column(
                children: [
                  for (final run in completed) ...[
                    _PreviousRunTile(run: run),
                    const SizedBox(height: AppSpacing.space2),
                  ],
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) =>
                const Text('Import history is temporarily unavailable.'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRestore(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore a Lootr backup?'),
        content: const Text(
          'Lootr will verify the backup before replacing this workspace. '
          'You can cancel before publication.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('restore-cancel'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('restore-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Choose backup'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _runPortabilityAction(
      context,
      ref,
      (service) => service.restoreBackup(),
    );
  }

  Future<void> _runPortabilityAction(
    BuildContext context,
    WidgetRef ref,
    Future<DataPortabilityResult> Function(DataPortabilityCoordinator service)
    action,
  ) async {
    final service = ref.read(dataPortabilityCoordinatorProvider);
    DataPortabilityResult result;
    try {
      result = await action(service);
    } catch (_) {
      result = const DataPortabilityResult(
        succeeded: false,
        message: 'The action could not be completed. No data was changed.',
      );
    }
    if (!context.mounted) return;
    showSafeMessage(context, result.message, warning: !result.succeeded);
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.run});

  final MigrationRunProjection run;

  @override
  Widget build(BuildContext context) {
    return MigrationSectionCard(
      semanticLabel:
          'Import ready to resume. ${migrationPhaseLabel(run.phase)}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                LucideIcons.history,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Continue your import', style: AppTypography.h3),
                    const SizedBox(height: AppSpacing.space1),
                    Text(
                      migrationPhaseLabel(run.phase),
                      style: AppTypography.caption.copyWith(
                        color: context.lootrColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space3),
          MigrationPrimaryAction(
            key: const ValueKey('resume-import'),
            label: 'Resume import',
            icon: LucideIcons.arrowRight,
            onPressed: () =>
                context.push('/more/settings/data/import-cashew/${run.id}'),
          ),
        ],
      ),
    );
  }
}

class _PreviousRunTile extends StatelessWidget {
  const _PreviousRunTile({required this.run});

  final MigrationRunProjection run;

  @override
  Widget build(BuildContext context) {
    return _DataActionTile(
      key: ValueKey('previous-import-${run.id}'),
      icon: run.phase == MigrationRunPhase.rolledBack
          ? LucideIcons.rotateCcw
          : LucideIcons.circleCheck,
      title: run.sourceLabel,
      subtitle: migrationPhaseLabel(run.phase),
      onTap: () => context.push('/more/settings/data/imports/${run.id}'),
    );
  }
}

class _DataActionTile extends StatelessWidget {
  const _DataActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.space4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(icon, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: AppSpacing.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppTypography.bodyMedium),
                        const SizedBox(height: AppSpacing.space1),
                        Text(
                          subtitle,
                          style: AppTypography.caption.copyWith(
                            color: context.lootrColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  const Icon(LucideIcons.chevronRight, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
