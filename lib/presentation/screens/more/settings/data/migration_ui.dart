import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/radius.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/typography.dart';
import '../../../../../application/migration/migration_models.dart';

class MigrationPageBody extends StatelessWidget {
  const MigrationPageBody({super.key, required this.children, this.bottom});

  final List<Widget> children;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pagePaddingMobile,
                AppSpacing.space4,
                AppSpacing.pagePaddingMobile,
                AppSpacing.space8,
              ),
              children: children,
            ),
          ),
          if (bottom != null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                AppSpacing.pagePaddingMobile,
                AppSpacing.space3,
                AppSpacing.pagePaddingMobile,
                AppSpacing.space3 + bottomPadding,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: bottom,
            ),
        ],
      ),
    );
  }
}

class MigrationSectionCard extends StatelessWidget {
  const MigrationSectionCard({
    super.key,
    required this.child,
    this.semanticLabel,
  });

  final Widget child;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: child,
    );
    if (semanticLabel == null) return card;
    return Semantics(container: true, label: semanticLabel, child: card);
  }
}

class MigrationHeading extends StatelessWidget {
  const MigrationHeading({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(title, style: AppTypography.h1)),
        const SizedBox(height: AppSpacing.space2),
        Text(
          body,
          style: AppTypography.body.copyWith(
            color: context.lootrColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class MigrationPrimaryAction extends StatelessWidget {
  const MigrationPrimaryAction({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon ?? LucideIcons.arrowRight, size: 18),
          label: Text(label),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ),
    );
  }
}

class MigrationSecondaryAction extends StatelessWidget {
  const MigrationSecondaryAction({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isDanger = false,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isDanger;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final danger = context.lootrColors.danger;
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon ?? LucideIcons.arrowRight, size: 18),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            foregroundColor: isDanger ? danger : null,
            side: isDanger ? BorderSide(color: danger) : null,
          ),
        ),
      ),
    );
  }
}

class MigrationProgressPanel extends StatelessWidget {
  const MigrationProgressPanel({
    super.key,
    required this.label,
    required this.progress,
    required this.detail,
  });

  final String label;
  final double progress;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final percent = (progress.clamp(0, 1) * 100).round();
    return MigrationSectionCard(
      child: Semantics(
        liveRegion: true,
        label: '$label, $percent percent',
        value: '$percent%',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTypography.h3),
            const SizedBox(height: AppSpacing.space2),
            LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 8,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            const SizedBox(height: AppSpacing.space3),
            Text(
              detail,
              style: AppTypography.body.copyWith(
                color: context.lootrColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MigrationStatusMark extends StatelessWidget {
  const MigrationStatusMark({super.key, required this.status, this.size = 20});

  final MigrationPartitionStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (status) {
      MigrationPartitionStatus.reconciled => (
        LucideIcons.circleCheck,
        context.lootrColors.success,
        'Reconciled',
      ),
      MigrationPartitionStatus.needsReview => (
        LucideIcons.circleAlert,
        context.lootrColors.warning,
        'Needs review',
      ),
      MigrationPartitionStatus.blocking => (
        LucideIcons.octagonAlert,
        context.lootrColors.danger,
        'Blocking problem',
      ),
    };
    return Semantics(
      label: label,
      child: Icon(icon, color: color, size: size),
    );
  }
}

String migrationPhaseLabel(MigrationRunPhase phase) => switch (phase) {
  MigrationRunPhase.selected => 'Ready to analyze',
  MigrationRunPhase.analyzing => 'Analyzing',
  MigrationRunPhase.needsReview => 'Needs review',
  MigrationRunPhase.reconciling => 'Reconciling',
  MigrationRunPhase.ready => 'Ready to import',
  MigrationRunPhase.applying => 'Importing',
  MigrationRunPhase.verifying => 'Verifying',
  MigrationRunPhase.interrupted => 'Recovery available',
  MigrationRunPhase.failed => 'Needs attention',
  MigrationRunPhase.complete => 'Complete',
  MigrationRunPhase.cancelled => 'Cancelled',
  MigrationRunPhase.rolledBack => 'Rolled back',
};

void showSafeMessage(
  BuildContext context,
  String message, {
  bool warning = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: warning ? context.lootrColors.warning : null,
      ),
    );
}
