import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../application/migration/migration_models.dart';
import '../../../../../application/providers/migration_providers.dart';
import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/typography.dart';
import 'migration_ui.dart';

class CashewMigrationRunScreen extends ConsumerWidget {
  const CashewMigrationRunScreen({super.key, required this.runId});

  final String runId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final run = ref.watch(migrationRunProvider(runId));
    return run.when(
      data: (projection) {
        if (projection == null) {
          return const _MissingRunScreen();
        }
        return _RunScaffold(run: projection);
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const _MissingRunScreen(),
    );
  }
}

class _RunScaffold extends ConsumerWidget {
  const _RunScaffold({required this.run});

  final MigrationRunProjection run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: !run.blocksBackNavigation,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && run.blocksBackNavigation) {
          showSafeMessage(
            context,
            'Lootr is finishing the atomic import. It is safe to leave the '
            'app open.',
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: false,
          title: Text(_appBarTitle(run.phase)),
          actions: [
            if (run.canCancel)
              TextButton(
                key: const ValueKey('cancel-import'),
                onPressed: () => _confirmCancel(context, ref),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: const Text('Cancel'),
              ),
          ],
        ),
        body: switch (run.phase) {
          MigrationRunPhase.selected => _SelectedStep(run: run),
          MigrationRunPhase.analyzing => _ProgressStep(
            run: run,
            title: 'Analyzing privately',
            body:
                'Lootr is reading the staged copy. Your Lootr ledger has not '
                'been changed.',
          ),
          MigrationRunPhase.needsReview => _ReviewStep(run: run),
          MigrationRunPhase.reconciling => _ProgressStep(
            run: run,
            title: 'Reconciling the dry run',
            body:
                'Each account and currency is checked independently at its '
                'source precision.',
          ),
          MigrationRunPhase.ready => _ReadyStep(run: run),
          MigrationRunPhase.applying => _ProgressStep(
            run: run,
            title: 'Publishing your import',
            body:
                'Lootr created a recovery checkpoint and is applying approved '
                'records atomically.',
          ),
          MigrationRunPhase.verifying => _ProgressStep(
            run: run,
            title: 'Verifying the result',
            body:
                'Counts, relationships, and currency partitions are being '
                'checked before the import is marked complete.',
          ),
          MigrationRunPhase.complete => _CompleteStep(run: run),
          MigrationRunPhase.cancelled => _CancelledStep(run: run),
          MigrationRunPhase.rolledBack => _RolledBackStep(run: run),
        },
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this import?'),
        content: const Text(
          'Nothing has been published yet. Lootr will remove its private '
          'staging copy and keep your original file untouched.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('keep-import'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep working'),
          ),
          FilledButton(
            key: const ValueKey('confirm-cancel-import'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel import'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(migrationCoordinatorProvider).cancel(run.id);
    }
  }
}

class _SelectedStep extends ConsumerWidget {
  const _SelectedStep({required this.run});

  final MigrationRunProjection run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MigrationPageBody(
      bottom: MigrationPrimaryAction(
        key: const ValueKey('analyze-cashew-backup'),
        label: 'Analyze backup',
        icon: LucideIcons.scanSearch,
        onPressed: () {
          unawaited(ref.read(migrationCoordinatorProvider).analyze(run.id));
        },
      ),
      children: [
        const MigrationHeading(
          title: 'Ready for a dry run',
          body:
              'Analysis checks the source structure, every relationship, and '
              'each currency partition without writing to Lootr.',
        ),
        const SizedBox(height: AppSpacing.space5),
        MigrationSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailLine(label: 'Source', value: run.sourceLabel),
              _DetailLine(label: 'Timezone', value: run.timezoneLabel),
              _DetailLine(
                label: 'Title policy',
                value: run.titlePolicy.label,
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({
    required this.run,
    required this.title,
    required this.body,
  });

  final MigrationRunProjection run;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return MigrationPageBody(
      children: [
        MigrationHeading(title: title, body: body),
        const SizedBox(height: AppSpacing.space5),
        MigrationProgressPanel(
          key: const ValueKey('migration-progress'),
          label: run.progressLabel,
          progress: run.progress,
          detail:
              'You can safely return later. Progress is projected from the '
              'saved import run.',
        ),
      ],
    );
  }
}

class _ReviewStep extends ConsumerWidget {
  const _ReviewStep({required this.run});

  final MigrationRunProjection run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MigrationPageBody(
      bottom: MigrationPrimaryAction(
        key: const ValueKey('continue-to-reconcile'),
        label: run.unresolvedReviewCount == 0
            ? 'Reconcile approved records'
            : '${run.unresolvedReviewCount} still need review',
        icon: LucideIcons.scale,
        onPressed: run.unresolvedReviewCount == 0
            ? () {
                unawaited(
                  ref.read(migrationCoordinatorProvider).reconcile(run.id),
                );
              }
            : null,
      ),
      children: [
        MigrationHeading(
          title: 'Review the dry run',
          body:
              '${run.dispositions.total} source records received a '
              'disposition. Valid source data without a direct equivalent is '
              'preserved for later.',
        ),
        const SizedBox(height: AppSpacing.space5),
        _InventoryCard(run: run),
        const SizedBox(height: AppSpacing.space5),
        Semantics(
          header: true,
          child: Text('Review groups', style: AppTypography.h2),
        ),
        const SizedBox(height: AppSpacing.space3),
        for (final group in run.reviewGroups) ...[
          _ReviewGroupCard(runId: run.id, group: group),
          const SizedBox(height: AppSpacing.space3),
        ],
      ],
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({required this.run});

  final MigrationRunProjection run;

  @override
  Widget build(BuildContext context) {
    final counts = run.dispositions;
    return MigrationSectionCard(
      semanticLabel: 'Dry run inventory',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Detected source', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.space3),
          Wrap(
            spacing: AppSpacing.space2,
            runSpacing: AppSpacing.space2,
            children: [
              _CountChip(label: 'Schema', value: '${run.schemaVersion ?? '—'}'),
              _CountChip(label: 'Accounts', value: '${run.accountCount}'),
              _CountChip(
                label: 'Currencies',
                value: '${run.currencyLabels.length}',
              ),
              _CountChip(label: 'Exact', value: '${counts.exact}'),
              _CountChip(label: 'Transformed', value: '${counts.transformed}'),
              _CountChip(label: 'Preserved', value: '${counts.preserved}'),
              _CountChip(label: 'Needs review', value: '${counts.review}'),
              _CountChip(label: 'Blocking', value: '${counts.blocking}'),
            ],
          ),
          const SizedBox(height: AppSpacing.space3),
          Text(
            run.dateRangeLabel,
            style: AppTypography.caption.copyWith(
              color: context.lootrColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewGroupCard extends ConsumerWidget {
  const _ReviewGroupCard({required this.runId, required this.group});

  final String runId;
  final MigrationReviewGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, color, status) = group.resolved
        ? (LucideIcons.circleCheck, context.lootrColors.success, 'Reviewed')
        : switch (group.level) {
            MigrationIssueLevel.info => (
              LucideIcons.archive,
              Theme.of(context).colorScheme.primary,
              'Preserved for later',
            ),
            MigrationIssueLevel.needsReview => (
              LucideIcons.circleAlert,
              context.lootrColors.warning,
              'Needs review',
            ),
            MigrationIssueLevel.blocking => (
              LucideIcons.octagonAlert,
              context.lootrColors.danger,
              'Blocking problem',
            ),
          };

    return MigrationSectionCard(
      semanticLabel:
          '${group.title}. $status. ${group.count} records. '
          '${group.description}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: AppSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.title, style: AppTypography.h3),
                    const SizedBox(height: AppSpacing.space1),
                    Text(
                      '$status · ${group.count}',
                      style: AppTypography.captionMedium.copyWith(color: color),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            group.description,
            style: AppTypography.body.copyWith(
              color: context.lootrColors.textSecondary,
            ),
          ),
          if (!group.resolved) ...[
            const SizedBox(height: AppSpacing.space3),
            MigrationSecondaryAction(
              key: ValueKey('review-${group.id}'),
              label: group.level == MigrationIssueLevel.info
                  ? 'Keep preserved'
                  : 'Approve safe resolution',
              icon: LucideIcons.check,
              onPressed: () {
                unawaited(
                  ref
                      .read(migrationCoordinatorProvider)
                      .resolveReviewGroup(runId, group.id),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _ReadyStep extends ConsumerWidget {
  const _ReadyStep({required this.run});

  final MigrationRunProjection run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MigrationPageBody(
      bottom: MigrationPrimaryAction(
        key: const ValueKey('apply-cashew-import'),
        label: 'Import approved records',
        icon: LucideIcons.databaseZap,
        onPressed: () => _confirmApply(context, ref),
      ),
      children: [
        const MigrationHeading(
          title: 'Reconciliation passed',
          body:
              'Every approved account and currency partition reconciles at '
              'source precision. Unrelated currencies are never combined.',
        ),
        const SizedBox(height: AppSpacing.space5),
        Semantics(
          header: true,
          child: Text('Account partitions', style: AppTypography.h2),
        ),
        const SizedBox(height: AppSpacing.space3),
        for (final partition in run.partitions) ...[
          _PartitionCard(partition: partition),
          const SizedBox(height: AppSpacing.space2),
        ],
        const SizedBox(height: AppSpacing.space3),
        MigrationSectionCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                LucideIcons.shieldCheck,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.space3),
              Expanded(
                child: Text(
                  'Before publication, Lootr creates and verifies a recovery '
                  'checkpoint. The approved records and provenance are then '
                  'published in one atomic step.',
                  style: AppTypography.body,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmApply(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import these records?'),
        content: const Text(
          'Lootr will create a recovery checkpoint, publish the approved '
          'records atomically, and verify the result.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('apply-cancel'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Review again'),
          ),
          FilledButton(
            key: const ValueKey('apply-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      unawaited(ref.read(migrationCoordinatorProvider).apply(run.id));
    }
  }
}

class _PartitionCard extends StatelessWidget {
  const _PartitionCard({required this.partition});

  final MigrationCurrencyPartition partition;

  @override
  Widget build(BuildContext context) {
    return MigrationSectionCard(
      semanticLabel:
          '${partition.accountLabel}, ${partition.currencyLabel}, '
          '${partition.precision} decimal precision. ${partition.explanation}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MigrationStatusMark(status: partition.status),
          const SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(partition.accountLabel, style: AppTypography.bodyMedium),
                const SizedBox(height: AppSpacing.space1),
                Text(
                  '${partition.currencyLabel} · '
                  '${partition.precision} decimal places',
                  style: AppTypography.caption.copyWith(
                    color: context.lootrColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space1),
                Text(partition.explanation, style: AppTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompleteStep extends StatelessWidget {
  const _CompleteStep({required this.run});

  final MigrationRunProjection run;

  @override
  Widget build(BuildContext context) {
    return MigrationPageBody(
      children: [
        const MigrationHeading(
          title: 'Your import is ready',
          body:
              'Publication and post-write reconciliation completed. Preserved '
              'records remain available from the import summary.',
        ),
        const SizedBox(height: AppSpacing.space5),
        MigrationSectionCard(
          semanticLabel: 'Import completed and reconciled',
          child: Column(
            children: [
              Icon(
                LucideIcons.circleCheckBig,
                size: 52,
                color: context.lootrColors.success,
              ),
              const SizedBox(height: AppSpacing.space3),
              Text('Import complete', style: AppTypography.h2),
              const SizedBox(height: AppSpacing.space2),
              Text(
                '${run.dispositions.exact} exact, '
                '${run.dispositions.transformed} transformed, and '
                '${run.dispositions.preserved} preserved for later.',
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  color: context.lootrColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space4),
        MigrationPrimaryAction(
          key: const ValueKey('open-import-summary'),
          label: 'Open import summary',
          icon: LucideIcons.clipboardCheck,
          onPressed: () =>
              context.push('/more/settings/data/imports/${run.id}'),
        ),
        const SizedBox(height: AppSpacing.space2),
        MigrationSecondaryAction(
          key: const ValueKey('open-imported-transactions'),
          label: 'View imported transactions',
          icon: LucideIcons.receiptText,
          onPressed: () => context.go('/transactions'),
        ),
      ],
    );
  }
}

class _CancelledStep extends StatelessWidget {
  const _CancelledStep({required this.run});

  final MigrationRunProjection run;

  @override
  Widget build(BuildContext context) {
    return MigrationPageBody(
      children: [
        const MigrationHeading(
          title: 'Import cancelled',
          body:
              'Nothing was published. Lootr removed its private staging copy '
              'and left the original Cashew file untouched.',
        ),
        const SizedBox(height: AppSpacing.space4),
        MigrationPrimaryAction(
          key: const ValueKey('cancelled-return-data'),
          label: 'Return to Data & backup',
          icon: LucideIcons.arrowLeft,
          onPressed: () => context.go('/more/settings/data'),
        ),
      ],
    );
  }
}

class _RolledBackStep extends StatelessWidget {
  const _RolledBackStep({required this.run});

  final MigrationRunProjection run;

  @override
  Widget build(BuildContext context) {
    return MigrationPageBody(
      children: [
        const MigrationHeading(
          title: 'Pre-import state restored',
          body:
              'The imported publication was rolled back. Its redacted summary '
              'remains available for your records.',
        ),
        const SizedBox(height: AppSpacing.space4),
        MigrationPrimaryAction(
          key: const ValueKey('rollback-return-data'),
          label: 'Return to Data & backup',
          icon: LucideIcons.arrowLeft,
          onPressed: () => context.go('/more/settings/data'),
        ),
      ],
    );
  }
}

class _MissingRunScreen extends StatelessWidget {
  const _MissingRunScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import unavailable')),
      body: MigrationPageBody(
        children: [
          const MigrationHeading(
            title: 'This import is unavailable',
            body:
                'The saved import run could not be opened. No data was '
                'changed.',
          ),
          const SizedBox(height: AppSpacing.space4),
          MigrationPrimaryAction(
            label: 'Return to Data & backup',
            icon: LucideIcons.arrowLeft,
            onPressed: () => context.go('/more/settings/data'),
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: context.lootrColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.space1),
          Text(value, style: AppTypography.bodyMedium),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: Chip(label: Text('$label $value')),
    );
  }
}

String _appBarTitle(MigrationRunPhase phase) => switch (phase) {
  MigrationRunPhase.selected || MigrationRunPhase.analyzing => 'Dry run',
  MigrationRunPhase.needsReview => 'Review',
  MigrationRunPhase.reconciling || MigrationRunPhase.ready => 'Reconcile',
  MigrationRunPhase.applying || MigrationRunPhase.verifying => 'Import',
  MigrationRunPhase.complete => 'Complete',
  MigrationRunPhase.cancelled => 'Cancelled',
  MigrationRunPhase.rolledBack => 'Rolled back',
};
