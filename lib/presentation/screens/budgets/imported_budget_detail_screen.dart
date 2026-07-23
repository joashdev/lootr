import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../application/providers/accounts_provider.dart';
import '../../../application/providers/categories_provider.dart';
import '../../../application/providers/budget_projection.dart';
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
import '../../sheets/composite_budget_sheet.dart';

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
      appBar: AppBar(title: const Text('Composite budget')),
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
                budget.isReadOnly
                    ? '${budget.currencyCode} · Read-only imported definition'
                    : '${budget.currencyCode} · Editable composite definition',
                style: TextStyle(color: lootrColors.textSecondary),
              ),
              if (!budget.isReadOnly) ...[
                const SizedBox(height: AppSpacing.space2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      useRootNavigator: true,
                      isScrollControlled: true,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      builder: (_) => CompositeBudgetSheet(budgetId: id),
                    ),
                    icon: const Icon(LucideIcons.pencil, size: 18),
                    label: const Text('Edit scope and period'),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.space3),
              Text('Scope and membership', style: AppTypography.h3),
              const SizedBox(height: AppSpacing.space2),
              _ScopePanel(scope: data.compositeScope!),
              if (data.unresolvedMembers.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.space4),
                Text('Unresolved imported members', style: AppTypography.h3),
                const SizedBox(height: AppSpacing.space1),
                Text(
                  'These source relationships are preserved individually and '
                  'are not silently replaced.',
                  style: TextStyle(color: lootrColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.space2),
                _Panel(
                  child: Column(
                    children: [
                      for (final member in data.unresolvedMembers)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(LucideIcons.circleAlert),
                          title: Text(
                            '${_titleCase(member.membership)} '
                            '${member.kind}',
                          ),
                          subtitle: Text(member.sourceReference),
                          trailing: Text(_reviewLabel(member.reviewState)),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.space4),
              Text('Overlap information', style: AppTypography.h3),
              const SizedBox(height: AppSpacing.space2),
              if (data.overlaps.isEmpty)
                const _Panel(
                  child: Text(
                    'No transactions in this period also match another budget.',
                  ),
                )
              else
                _Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Budgets evaluate independently. Shared transactions '
                        'remain included in each matching budget.',
                      ),
                      const SizedBox(height: AppSpacing.space2),
                      for (final overlap in data.overlaps)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(overlap.budgetName),
                          subtitle: Text(
                            '${overlap.sharedTransactionCount} shared '
                            'transaction(s)',
                          ),
                          trailing: const Icon(LucideIcons.chevronRight),
                          onTap: () => context.push(
                            '/budgets/imported/${overlap.budgetId}'
                            '?year=${budget.startsAt.year}'
                            '&month=${budget.startsAt.month}',
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.space4),
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
              Text('Period history', style: AppTypography.h3),
              const SizedBox(height: AppSpacing.space2),
              if (data.history.isEmpty)
                const _Panel(
                  child: Text('No materialized historical cycles yet'),
                )
              else
                _Panel(
                  child: Column(
                    children: [
                      for (final period in data.history)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(LucideIcons.calendarRange),
                          title: Text(
                            '${_date(period.startsAt)} → '
                            '${_date(period.endsAt.subtract(const Duration(days: 1)))}',
                          ),
                          trailing: const Icon(LucideIcons.chevronRight),
                          onTap: () => context.push(
                            '/budgets/imported/$id'
                            '?year=${period.startsAt.year}'
                            '&month=${period.startsAt.month}',
                          ),
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

  static String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static String _titleCase(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

  static String _reviewLabel(String value) =>
      value.split('_').map(_titleCase).join(' ');
}

class _ScopePanel extends StatelessWidget {
  const _ScopePanel({required this.scope});

  final CompositeBudgetScopeProjection scope;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ScopeLine(label: 'Membership', values: [_membershipLabel]),
          _ScopeLine(label: 'Direction', values: [scope.direction]),
          _ScopeLine(label: 'Period', values: [scope.periodType]),
          _ScopeLine(
            label: 'Included accounts',
            values: scope.includedAccounts,
          ),
          _ScopeLine(
            label: 'Excluded accounts',
            values: scope.excludedAccounts,
          ),
          _ScopeLine(
            label: 'Included categories',
            values: scope.includedCategories,
          ),
          _ScopeLine(
            label: 'Excluded categories',
            values: scope.excludedCategories,
          ),
          _ScopeLine(
            label: 'Attached transactions',
            values: scope.includedTransactions,
          ),
          _ScopeLine(
            label: 'Excluded transactions',
            values: scope.excludedTransactions,
          ),
        ],
      ),
    );
  }

  String get _membershipLabel => scope.membershipMode == 'explicit_only'
      ? 'Attached transactions only'
      : 'Matching scope and attached transactions';
}

class _ScopeLine extends StatelessWidget {
  const _ScopeLine({required this.label, required this.values});

  final String label;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(color: context.lootrColors.textSecondary),
            ),
          ),
          Expanded(child: Text(values.join(', '))),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.margin});

  final Widget child;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.cardPaddingStandard),
          child: child,
        ),
      ),
    );
  }
}
