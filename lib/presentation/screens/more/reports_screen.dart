import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';

class _ReportType {
  final String type;
  final String label;
  final String description;
  final IconData icon;

  const _ReportType({
    required this.type,
    required this.label,
    required this.description,
    required this.icon,
  });
}

const _reportTypes = [
  _ReportType(
    type: 'spending-category',
    label: 'Spending by Category',
    description: 'See where your money goes',
    icon: LucideIcons.pieChart,
  ),
  _ReportType(
    type: 'income-vs-expenses',
    label: 'Income vs Expenses',
    description: 'Compare your earnings and spending',
    icon: LucideIcons.barChart3,
  ),
  _ReportType(
    type: 'net-worth',
    label: 'Net Worth Over Time',
    description: 'Track your wealth growth',
    icon: LucideIcons.trendingUp,
  ),
  _ReportType(
    type: 'budget-performance',
    label: 'Budget Performance',
    description: 'See how well you stick to budgets',
    icon: LucideIcons.target,
  ),
  _ReportType(
    type: 'cash-flow',
    label: 'Cash Flow',
    description: 'Track money coming in and going out',
    icon: LucideIcons.arrowLeftRight,
  ),
];

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lootrColors = context.lootrColors;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(centerTitle: false, title: const Text('Reports')),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePaddingMobile,
          vertical: AppSpacing.space4,
        ),
        itemCount: _reportTypes.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.space3),
        itemBuilder: (context, index) {
          final report = _reportTypes[index];
          return Material(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () =>
                  context.push('/more/reports/${report.type}?period=month'),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.space4),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        report.icon,
                        color: colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.label,
                            style: AppTypography.bodyMedium.copyWith(
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            report.description,
                            style: AppTypography.caption.copyWith(
                              color: lootrColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: lootrColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
