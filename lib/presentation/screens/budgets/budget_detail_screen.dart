import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../application/providers/accounts_provider.dart';
import '../../../application/providers/budget_detail_provider.dart';
import '../../../application/providers/budgets_tab_provider.dart';
import '../../../application/providers/categories_provider.dart';
import '../../../application/providers/payees_provider.dart';
import '../../../application/providers/repo_providers.dart';
import '../../../core/extensions/async_value_x.dart';
import '../../../core/format/money_format.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/entities/account.dart';
import '../../../domain/entities/budget.dart';
import '../../../domain/entities/category.dart';
import '../../../domain/entities/transaction.dart';
import '../../shared/category_visuals.dart';
import '../../shared/components/progress/budget_progress_bar.dart';
import '../../shared/components/buttons/ghost_button.dart';
import '../../shared/components/buttons/secondary_button.dart';
import '../transactions/widgets/transaction_row.dart';
import '../../sheets/budget_create_sheet.dart';

class BudgetDetailScreen extends ConsumerWidget {
  const BudgetDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(budgetDetailProvider(id));
    final categoriesAsync = ref.watch(categoriesProvider);
    final payeesAsync = ref.watch(payeesProvider);
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(centerTitle: false, title: const Text('Budget')),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.alertCircle, size: 48, color: Colors.red),
              const SizedBox(height: AppSpacing.space3),
              Text(
                'Failed to load budget',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Budget not found'));
          }

          final budget = data.budget;
          final transactions = data.transactions;
          final categories = categoriesAsync.valueOrNull ?? [];
          final category = categories
              .where((c) => c.id == budget.categoryId)
              .firstOrNull;
          final payees = payeesAsync.valueOrNull ?? [];
          final payeeNames = {
            for (final p in payees)
              p.id: (p.displayName?.isNotEmpty ?? false)
                  ? p.displayName!
                  : p.normalizedName,
          };
          final accounts = accountsAsync.valueOrNull ?? const <Account>[];
          final accountNames = {for (final a in accounts) a.id: a.name};
          final categoryMap = {for (final c in categories) c.id: c};
          final isReadOnly = isPastBudgetPeriod(budget.month, budget.year);

          final progress = budget.amount > 0
              ? (budget.spent / budget.amount).clamp(0.0, 1.5)
              : 0.0;

          final exactSpent = budget.exactSpentAmount;
          final exactRemaining = budget.exactAmount - exactSpent;
          final isOver = exactRemaining.isNegative;

          final colorScheme = Theme.of(context).colorScheme;
          final lootrColors = context.lootrColors;

          Color progressColor() {
            if (progress >= 1.0) return lootrColors.danger;
            if (progress >= 0.8) return lootrColors.warning;
            return lootrColors.success;
          }

          final iconValue = resolveBudgetIconValue(budget, category);
          final budgetColor = resolveBudgetColor(budget, category);

          return ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.pagePaddingMobile,
              AppSpacing.pagePaddingMobile,
              AppSpacing.pagePaddingMobile,
              AppSpacing.bottomNavClearance +
                  MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              _DetailCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: budgetColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: buildCategoryVisual(
                            iconValue,
                            size: 24,
                            color: budgetColor,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.space3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category?.name ?? 'Uncategorized',
                                style: AppTypography.h2.copyWith(
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Budget: ',
                                      style: TextStyle(
                                        color: lootrColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                    TextSpan(
                                      text: MoneyFormat.exactMoney(
                                        budget.exactAmount,
                                      ),
                                      style: AppTypography.mono.copyWith(
                                        color: lootrColors.textSecondary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.space3),
              _DetailCard(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress',
                          style: AppTypography.captionMedium.copyWith(
                            color: lootrColors.textSecondary,
                          ),
                        ),
                        Text(
                          '${(progress * 100).round()}%',
                          style: AppTypography.h3Mono.copyWith(
                            color: progressColor(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space2),
                    BudgetProgressBar(
                      progress: progress.clamp(0.0, 1.0),
                      color: progressColor(),
                      height: 12,
                    ),
                    const SizedBox(height: AppSpacing.space3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatItem(
                          label: 'Spent',
                          value: MoneyFormat.exactMoney(exactSpent),
                          color: isOver ? lootrColors.danger : null,
                        ),
                        _StatItem(
                          label: 'Budgeted',
                          value: MoneyFormat.exactMoney(budget.exactAmount),
                        ),
                        _StatItem(
                          label: isOver ? 'Over' : 'Left',
                          value: MoneyFormat.exactMoney(exactRemaining.abs()),
                          color: isOver
                              ? lootrColors.danger
                              : lootrColors.success,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.space3),
              _DetailCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Related Transactions',
                      style: AppTypography.captionMedium.copyWith(
                        color: lootrColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space2),
                    if (transactions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.space4,
                        ),
                        child: Center(
                          child: Text(
                            'No transactions this month',
                            style: TextStyle(color: lootrColors.textTertiary),
                          ),
                        ),
                      )
                    else
                      ...transactions.map((tx) {
                        final txCategory = tx.categoryId == null
                            ? null
                            : categoryMap[tx.categoryId];
                        final accountName =
                            accountNames[tx.accountId] ?? 'Account';
                        return TransactionRowWidget(
                          transaction: tx,
                          accountName: accountName,
                          categoryName: txCategory?.name,
                          payeeName: tx.payeeId == null
                              ? null
                              : payeeNames[tx.payeeId],
                          showDate: true,
                          leading: _BudgetTransactionLeading(
                            transaction: tx,
                            category: txCategory,
                          ),
                          onTap: () => context.push('/transactions/${tx.id}'),
                        );
                      }),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.space6),
              if (isReadOnly)
                Center(
                  child: Text(
                    'Past months are read-only',
                    style: TextStyle(color: lootrColors.textTertiary),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: 'Edit',
                        onPressed: () => _showEditSheet(context, data.budget),
                        icon: const Icon(LucideIcons.pencil, size: 18),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space3),
                    Expanded(
                      child: SecondaryButton(
                        label: 'Delete',
                        onPressed: () => _confirmDelete(context, ref, budget),
                        icon: const Icon(LucideIcons.trash2, size: 18),
                        isDanger: true,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: AppSpacing.space8),
            ],
          );
        },
      ),
    );
  }

  void _showEditSheet(BuildContext context, Budget budget) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => BudgetCreateSheet(budget: budget),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Budget budget) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Budget?'),
        content: const Text(
          'This budget will be permanently removed. This action cannot be undone.',
        ),
        actions: [
          GhostButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(ctx).pop(),
            isExpanded: false,
          ),
          GhostButton(
            label: 'Delete',
            onPressed: () async {
              final repo = ref.read(budgetRepoProvider);
              await repo.softDelete(budget.id);
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                if (context.mounted) Navigator.of(context).pop();
              }
            },
            isDanger: true,
            isExpanded: false,
          ),
        ],
      ),
    );
  }
}

/// Category-coloured circle leading for budget-detail transaction rows, matching
/// the main Transactions list and account detail.
class _BudgetTransactionLeading extends StatelessWidget {
  const _BudgetTransactionLeading({required this.transaction, this.category});

  final Transaction transaction;
  final Category? category;

  @override
  Widget build(BuildContext context) {
    final lootrColors = context.lootrColors;
    final colorScheme = Theme.of(context).colorScheme;

    final Color foreground;
    switch (transaction.direction) {
      case 'income':
        foreground = lootrColors.income;
      case 'transfer':
        foreground = lootrColors.transfer;
      default:
        foreground = lootrColors.expense;
    }

    final hasCategory = category != null;
    final background = hasCategory
        ? foreground.withValues(alpha: 0.12)
        : colorScheme.surfaceContainerHighest;
    final iconColor = hasCategory ? foreground : colorScheme.onSurfaceVariant;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: hasCategory
          ? buildCategoryVisualFor(category, color: iconColor, size: 18)
          : Icon(Icons.receipt_long_outlined, color: iconColor, size: 18),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPaddingStandard),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Theme.of(context).brightness == Brightness.dark
            ? Border.all(color: colorScheme.outline)
            : null,
      ),
      child: child,
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final lootrColors = context.lootrColors;

    return Column(
      children: [
        Text(
          value,
          style: AppTypography.h3Mono.copyWith(
            color: color ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: lootrColors.textTertiary,
          ),
        ),
      ],
    );
  }
}
