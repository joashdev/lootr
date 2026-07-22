import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../application/providers/accounts_provider.dart';
import '../../../application/providers/categories_provider.dart';
import '../../../application/providers/imported_budget_detail_provider.dart';
import '../../../application/providers/payees_provider.dart';
import '../../../core/extensions/async_value_x.dart';
import '../../../core/format/money_format.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/entities/account.dart';
import '../../../domain/value_objects/exact_money.dart';
import '../../shared/components/progress/budget_progress_bar.dart';
import '../transactions/widgets/transaction_row.dart';

class ImportedBudgetDetailScreen extends ConsumerWidget {
  const ImportedBudgetDetailScreen({
    super.key,
    required this.id,
    this.year,
    this.month,
  });

  final String id;
  final int? year;
  final int? month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final detail = ref.watch(
      importedBudgetDetailProvider(
        ImportedBudgetRequest(
          id: id,
          year: year ?? now.year,
          month: month ?? now.month,
        ),
      ),
    );
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final payees = ref.watch(payeesProvider).valueOrNull ?? [];
    final accounts =
        ref.watch(accountsProvider).valueOrNull ?? const <Account>[];
    final categoryById = {for (final row in categories) row.id: row};
    final accountById = {for (final row in accounts) row.id: row.name};
    final payeeById = {
      for (final row in payees)
        row.id: row.displayName?.isNotEmpty == true
            ? row.displayName!
            : row.normalizedName,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Imported budget')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Could not load budget')),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Imported budget not found'));
          }
          final budget = data.overview;
          final lootrColors = context.lootrColors;
          final progress = budget.progress.clamp(0.0, 1.0);
          final progressColor = progress >= 1
              ? lootrColors.danger
              : progress >= 0.8
              ? lootrColors.warning
              : lootrColors.success;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.pagePaddingMobile),
            children: [
              Text(budget.name, style: AppTypography.h2),
              const SizedBox(height: AppSpacing.space1),
              Text(
                '${budget.currencyCode} · Read-only imported definition',
                style: TextStyle(color: lootrColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.space3),
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          budget.needsReview
                              ? LucideIcons.circleAlert
                              : LucideIcons.shieldCheck,
                          size: 20,
                          color: budget.needsReview
                              ? lootrColors.warning
                              : lootrColors.success,
                        ),
                        const SizedBox(width: AppSpacing.space2),
                        Text(
                          budget.needsReview
                              ? 'Needs review'
                              : 'Imported scope preserved',
                          style: AppTypography.bodyMedium,
                        ),
                      ],
                    ),
                    if (budget.missingReferenceCount > 0) ...[
                      const SizedBox(height: AppSpacing.space2),
                      Text(
                        '${budget.missingReferenceCount} missing account, '
                        'category, or transaction reference(s) are preserved '
                        'for review.',
                        style: TextStyle(color: lootrColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.space3),
              _Panel(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_exact(budget.spent), style: AppTypography.h3Mono),
                        Text(
                          'of ${_exact(budget.budgeted)}',
                          style: AppTypography.mono,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space2),
                    BudgetProgressBar(
                      progress: progress,
                      color: progressColor,
                      semanticLabel: '${budget.name} budget usage',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.space4),
              Text('Included transactions', style: AppTypography.h3),
              const SizedBox(height: AppSpacing.space1),
              Text(
                'Each row states why it belongs to this budget.',
                style: TextStyle(color: lootrColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.space2),
              if (data.transactions.isEmpty)
                const _Panel(child: Text('No transactions in this period'))
              else
                for (final match in data.transactions)
                  _Panel(
                    margin: const EdgeInsets.only(bottom: AppSpacing.space2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TransactionRowWidget(
                          transaction: match.transaction,
                          accountName:
                              accountById[match.transaction.accountId] ??
                              'Account',
                          categoryName:
                              categoryById[match.transaction.categoryId]?.name,
                          payeeName: match.transaction.payeeId == null
                              ? null
                              : payeeById[match.transaction.payeeId],
                          showDate: true,
                          onTap: () => context.push(
                            '/transactions/${match.transaction.id}',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.space1),
                        Text(
                          match.inclusionReason,
                          style: TextStyle(
                            fontSize: 12,
                            color: lootrColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  static String _exact(ExactMoney value) => MoneyFormat.exactMoney(value);
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.margin});

  final Widget child;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(AppSpacing.cardPaddingStandard),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}
