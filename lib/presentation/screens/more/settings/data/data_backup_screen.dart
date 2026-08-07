import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../application/migration/migration_models.dart';
import '../../../../../application/migration/migration_coordinator.dart';
import '../../../../../application/providers/migration_providers.dart';
import '../../../../../application/providers/demo_data_provider.dart';
import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/typography.dart';
import 'migration_ui.dart';

class DataBackupScreen extends ConsumerWidget {
  const DataBackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runs = ref.watch(migrationRunsProvider);
    final demoData = ref.watch(demoDataProvider);
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
            child: Text('Sample data', style: AppTypography.h2),
          ),
          const SizedBox(height: AppSpacing.space3),
          demoData.when(
            data: (value) => _sampleDataAction(context, ref, value),
            loading: () => const _SampleDataStatusCard(
              message: 'Checking sample data…',
              showProgress: true,
            ),
            error: (_, _) => _DataActionTile(
              key: const ValueKey('sample-data-retry'),
              icon: LucideIcons.refreshCw,
              title: 'Check sample data again',
              subtitle: 'The sample-data status could not be read.',
              onTap: () => ref.invalidate(demoDataProvider),
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

  Widget _sampleDataAction(
    BuildContext context,
    WidgetRef ref,
    DemoDataState state,
  ) {
    return switch (state.status) {
      DemoDataStatus.loading => const _SampleDataStatusCard(
        message: 'Updating sample data…',
        showProgress: true,
      ),
      DemoDataStatus.present => _DataActionTile(
        key: const ValueKey('sample-data-clear'),
        icon: LucideIcons.trash2,
        title: 'Clear sample data',
        subtitle: 'Remove sample records while keeping your personal data.',
        onTap: () => _confirmClearSampleData(context, ref),
      ),
      DemoDataStatus.unverified when state.recordCount > 0 => _DataActionTile(
        key: const ValueKey('sample-data-review'),
        icon: LucideIcons.shieldQuestion,
        title: 'Review old sample data',
        subtitle:
            'Remove only records that match Lootr’s known sample-data set.',
        onTap: () => _confirmClearLegacySampleData(context, ref, state),
      ),
      DemoDataStatus.unverified => const _SampleDataStatusCard(
        key: ValueKey('sample-data-unverified'),
        message:
            'Lootr found an old sample-data flag, but it cannot verify which '
            'records are samples. No records will be removed automatically.',
      ),
      DemoDataStatus.absent when state.canSeed => _DataActionTile(
        key: const ValueKey('sample-data-load'),
        icon: LucideIcons.flaskConical,
        title: 'Load sample data',
        subtitle: 'Add sample accounts and transactions to this empty ledger.',
        onTap: () => _loadSampleData(context, ref),
      ),
      DemoDataStatus.absent => const _SampleDataStatusCard(
        key: ValueKey('sample-data-unavailable'),
        message:
            'Sample data is available only before you add financial records.',
      ),
    };
  }

  Future<void> _loadSampleData(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(demoDataProvider.notifier).seed();
      if (!context.mounted) return;
      showSafeMessage(context, 'Sample data loaded.');
    } catch (_) {
      if (!context.mounted) return;
      showSafeMessage(
        context,
        'Sample data could not be loaded. No data was changed.',
        warning: true,
      );
    }
  }

  Future<void> _confirmClearSampleData(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final analysis = await ref.read(demoDataProvider.notifier).analyzeClear();
    if (!context.mounted) return;
    final requiresRecovery = analysis.requiresRecovery;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          requiresRecovery
              ? 'Keep personal records and clear samples?'
              : 'Clear sample data?',
        ),
        content: Text(
          requiresRecovery
              ? '${analysis.personalDependencyCount} personal '
                    '${analysis.personalDependencyCount == 1 ? 'record uses' : 'records use'} '
                    'sample data. Lootr will keep the required sample records '
                    'as personal records and remove the other samples.'
              : 'This removes sample data only. Your personal data will stay.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('sample-data-clear-cancel'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('sample-data-clear-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(requiresRecovery ? 'Keep and clear' : 'Clear samples'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(demoDataProvider.notifier).clear();
      if (!context.mounted) return;
      showSafeMessage(context, 'Sample data cleared.');
    } catch (_) {
      if (!context.mounted) return;
      showSafeMessage(
        context,
        'Sample data could not be cleared. No data was changed.',
        warning: true,
      );
    }
  }

  Future<void> _confirmClearLegacySampleData(
    BuildContext context,
    WidgetRef ref,
    DemoDataState state,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear known sample records?'),
        content: Text(
          'Lootr found ${state.recordCount} ${state.recordCount == 1 ? 'record' : 'records'} '
          'that match its built-in sample set. Only these records and their '
          'derived data will be removed. Other records will stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('sample-data-review-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear known samples'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(demoDataProvider.notifier).clearReviewedLegacy();
      if (!context.mounted) return;
      showSafeMessage(context, 'Known sample data cleared.');
    } catch (_) {
      if (!context.mounted) return;
      showSafeMessage(
        context,
        'Known sample data could not be cleared. No data was changed.',
        warning: true,
      );
    }
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

class _SampleDataStatusCard extends StatelessWidget {
  const _SampleDataStatusCard({
    super.key,
    required this.message,
    this.showProgress = false,
  });

  final String message;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return MigrationSectionCard(
      child: Row(
        children: [
          if (showProgress) ...[
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.space3),
          ] else ...[
            Icon(LucideIcons.info, color: context.lootrColors.textSecondary),
            const SizedBox(width: AppSpacing.space3),
          ],
          Expanded(
            child: Text(
              message,
              style: AppTypography.body.copyWith(
                color: context.lootrColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
