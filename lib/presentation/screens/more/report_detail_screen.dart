import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';

class ReportDetailScreen extends ConsumerWidget {
  const ReportDetailScreen({super.key, required this.type});

  final String type;

  String get _title {
    switch (type) {
      case 'spending-category':
        return 'Spending by Category';
      case 'income-vs-expenses':
        return 'Income vs Expenses';
      case 'net-worth':
        return 'Net Worth Over Time';
      case 'budget-performance':
        return 'Budget Performance';
      case 'cash-flow':
        return 'Cash Flow';
      default:
        return 'Report';
    }
  }

  IconData get _icon {
    switch (type) {
      case 'spending-category':
        return LucideIcons.pieChart;
      case 'income-vs-expenses':
        return LucideIcons.barChart3;
      case 'net-worth':
        return LucideIcons.trendingUp;
      case 'budget-performance':
        return LucideIcons.target;
      case 'cash-flow':
        return LucideIcons.arrowLeftRight;
      default:
        return LucideIcons.chartBarBig;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lootrColors = context.lootrColors;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(_title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _icon,
                size: 64,
                color: lootrColors.textTertiary,
              ),
              const SizedBox(height: AppSpacing.space6),
              Text(
                _title,
                style: AppTypography.h2.copyWith(
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.space2),
              Text(
                'Report charts will be available with data.',
                style: AppTypography.body.copyWith(
                  color: lootrColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
