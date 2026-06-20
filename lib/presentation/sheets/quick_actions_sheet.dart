import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../shared/components/sheet_handle.dart';

class QuickActionsSheet extends StatelessWidget {
  const QuickActionsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sheetPaddingHorizontal,
          AppSpacing.space2,
          AppSpacing.sheetPaddingHorizontal,
          AppSpacing.space8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            const SizedBox(height: AppSpacing.space3),
            Text(
              'Add Transaction',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: AppSpacing.space4),
            Row(
              children: [
                Expanded(
                  child: _QuickActionCard(
                    icon: PhosphorIconsRegular.keyboard,
                    label: 'Quick Add',
                    subtitle: 'Natural language',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/transactions/new');
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.space3),
                Expanded(
                  child: _QuickActionCard(
                    icon: PhosphorIconsRegular.pencil,
                    label: 'Manual',
                    subtitle: 'Full form entry',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/transactions/new');
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.space3),
                Expanded(
                  child: _QuickActionCard(
                    icon: PhosphorIconsRegular.camera,
                    label: 'Scan',
                    subtitle: 'Receipt OCR',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/scan');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space6),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lootrColors = Theme.of(context).extension<LootrColorScheme>()!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.space4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary50,
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Icon(icon, color: AppColors.primary600, size: 24),
            ),
            const SizedBox(height: AppSpacing.space2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: lootrColors.textTertiary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
