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

class MigrationRunSummaryScreen extends ConsumerWidget {
  const MigrationRunSummaryScreen({super.key, required this.runId});

  final String runId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final run = ref.watch(migrationRunProvider(runId));
    return Scaffold(
      appBar: AppBar(centerTitle: false, title: const Text('Import summary')),
      body: run.when(
        data: (projection) {
          if (projection == null) return _missing(context);
          return _summary(context, ref, projection);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _missing(context),
      ),
    );
  }

  Widget _summary(
    BuildContext context,
    WidgetRef ref,
    MigrationRunProjection run,
  ) {
    return MigrationPageBody(
      children: [
        MigrationHeading(
          title: migrationPhaseLabel(run.phase),
          body:
              'This redacted summary explains what Lootr imported, '
              'transformed, and preserved.',
        ),
        const SizedBox(height: AppSpacing.space5),
        MigrationSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryLine(label: 'Source', value: run.sourceLabel),
              _SummaryLine(
                label: 'Schema',
                value: '${run.schemaVersion ?? 'Not available'}',
              ),
              _SummaryLine(label: 'Timezone', value: run.timezoneLabel),
              _SummaryLine(label: 'Title policy', value: run.titlePolicy.label),
              _SummaryLine(
                label: 'Currency partitions',
                value: '${run.partitions.length}',
                isLast: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space4),
        Wrap(
          spacing: AppSpacing.space2,
          runSpacing: AppSpacing.space2,
          children: [
            Chip(label: Text('Exact ${run.dispositions.exact}')),
            Chip(label: Text('Transformed ${run.dispositions.transformed}')),
            Chip(label: Text('Preserved ${run.dispositions.preserved}')),
            Chip(label: Text('Review ${run.dispositions.review}')),
            Chip(label: Text('Blocking ${run.dispositions.blocking}')),
          ],
        ),
        const SizedBox(height: AppSpacing.space5),
        MigrationSecondaryAction(
          key: const ValueKey('view-import-provenance'),
          label: 'View provenance',
          icon: LucideIcons.link,
          onPressed: () => _showProvenance(context, run),
        ),
        const SizedBox(height: AppSpacing.space2),
        MigrationSecondaryAction(
          key: const ValueKey('view-preserved-records'),
          label: 'View preserved records',
          icon: LucideIcons.archive,
          onPressed: () => _showPreserved(context, run),
        ),
        const SizedBox(height: AppSpacing.space2),
        MigrationSecondaryAction(
          key: const ValueKey('summary-create-backup'),
          label: 'Create Lootr backup',
          icon: LucideIcons.databaseBackup,
          onPressed: () => _createBackup(context, ref),
        ),
        if (run.phase == MigrationRunPhase.complete) ...[
          const SizedBox(height: AppSpacing.space2),
          MigrationSecondaryAction(
            key: const ValueKey('rollback-import'),
            label: 'Roll back this import',
            icon: LucideIcons.rotateCcw,
            isDanger: true,
            onPressed: () => _confirmRollback(context, ref, run),
          ),
        ],
      ],
    );
  }

  Widget _missing(BuildContext context) {
    return MigrationPageBody(
      children: [
        const MigrationHeading(
          title: 'Summary unavailable',
          body: 'This import summary could not be opened. No data was changed.',
        ),
        const SizedBox(height: AppSpacing.space4),
        MigrationPrimaryAction(
          label: 'Return to Data & backup',
          icon: LucideIcons.arrowLeft,
          onPressed: () => context.go('/more/settings/data'),
        ),
      ],
    );
  }

  void _showProvenance(BuildContext context, MigrationRunProjection run) {
    final mapped = run.dispositions.exact + run.dispositions.transformed;
    _showDetails(
      context,
      title: 'Source provenance',
      icon: LucideIcons.link,
      body:
          '$mapped mapped source records retain a source-to-Lootr link. '
          'Private source identifiers are intentionally hidden from this '
          'summary.',
      key: const ValueKey('provenance-dialog'),
    );
  }

  void _showPreserved(BuildContext context, MigrationRunProjection run) {
    final inventory = run.preservedGroups
        .map((group) => '${group.sourceKind}: ${group.count}')
        .join('\n');
    _showDetails(
      context,
      title: 'Preserved for later',
      icon: LucideIcons.archive,
      body:
          'The encrypted source archive retains every classified source row. '
          '${run.dispositions.preserved} are preserved-only rather than '
          'presented as normal Lootr ledger entries.'
          '${inventory.isEmpty ? '' : '\n\n$inventory'}',
      key: const ValueKey('preserved-dialog'),
    );
  }

  void _showDetails(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String body,
    required Key key,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          key: key,
          padding: const EdgeInsets.all(AppSpacing.space5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Row(
                  children: [
                    Icon(icon),
                    const SizedBox(width: AppSpacing.space2),
                    Expanded(child: Text(title, style: AppTypography.h2)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.space3),
              Text(body, style: AppTypography.body),
              const SizedBox(height: AppSpacing.space4),
              MigrationPrimaryAction(
                label: 'Done',
                icon: LucideIcons.check,
                onPressed: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createBackup(BuildContext context, WidgetRef ref) async {
    DataPortabilityResult result;
    try {
      result = await ref
          .read(dataPortabilityCoordinatorProvider)
          .createBackup();
    } catch (_) {
      result = const DataPortabilityResult(
        succeeded: false,
        message: 'The backup could not be created. No data was changed.',
      );
    }
    if (!context.mounted) return;
    showSafeMessage(context, result.message, warning: !result.succeeded);
  }

  Future<void> _confirmRollback(
    BuildContext context,
    WidgetRef ref,
    MigrationRunProjection run,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Roll back this import?'),
        content: const Text(
          'Lootr will restore the verified pre-import state. The redacted '
          'summary remains available unless you remove it separately.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('rollback-cancel'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep import'),
          ),
          FilledButton(
            key: const ValueKey('rollback-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Restore previous state'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      unawaited(ref.read(migrationCoordinatorProvider).rollback(run.id));
    }
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
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
