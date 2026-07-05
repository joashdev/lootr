import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../application/providers/accounts_provider.dart';
import '../../../application/providers/categories_provider.dart';
import '../../../application/providers/payee_detail_provider.dart';
import '../../../application/providers/repo_providers.dart';
import '../../../core/theme/colors.dart';
import '../../../data/repositories/payee_repo.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/entities/account.dart';
import '../../../domain/entities/category.dart';
import '../../../domain/entities/payee.dart';
import '../../shared/category_visuals.dart';
import '../../shared/components/app_snackbar.dart';
import '../../shared/components/buttons/secondary_button.dart';
import '../../shared/components/empty_state.dart';
import '../transactions/widgets/transaction_row.dart';

class PayeeDetailScreen extends ConsumerWidget {
  const PayeeDetailScreen({super.key, required this.id});

  final String id;

  Future<void> _editPayee(
    BuildContext context,
    WidgetRef ref,
    Payee payee,
  ) async {
    final controller = TextEditingController(text: payee.resolvedName);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Payee'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Payee name',
            hintText: 'Enter payee name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    final nextName = result?.trim();
    if (nextName == null || nextName.isEmpty || nextName == payee.resolvedName) {
      return;
    }

    try {
      await ref.read(payeeRepoProvider).updateName(payee.id, nextName);
    } on PayeeNameConflictException catch (e) {
      if (!context.mounted) return;
      AppSnackBar.show(context, e.toString());
      return;
    }
    if (!context.mounted) return;
    AppSnackBar.show(context, 'Payee updated.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(payeeDetailProvider(id));
    final categories =
        ref.watch(categoriesProvider).asData?.value ?? const <Category>[];
    final accounts =
        ref.watch(accountsProvider).asData?.value ?? const <Account>[];
    final categoryMap = {for (final category in categories) category.id: category};
    final accountMap = {for (final account in accounts) account.id: account.name};

    return Scaffold(
      appBar: AppBar(centerTitle: false, title: const Text('Payee')),
      body: detailAsync.when(
        data: (detail) {
          if (detail == null) {
            return const Center(child: Text('Payee not found'));
          }
          final payee = detail.payee;
          final transactions = detail.transactions;
          if (transactions.isEmpty) {
            return EmptyState(
              headline: payee.resolvedName,
              subtext: 'Transactions for this payee will appear here.',
              ctaLabel: 'Add Transaction',
              onCtaPressed: () => context.push('/transactions/new'),
            );
          }

          final lootrColors = context.lootrColors;
          final colorScheme = Theme.of(context).colorScheme;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.pagePaddingMobile),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              payee.resolvedName,
                              style: AppTypography.h1.copyWith(
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.space1),
                            Text(
                              '${transactions.length} transactions',
                              style: AppTypography.captionMedium.copyWith(
                                color: lootrColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SecondaryButton(
                        label: 'Edit',
                        isExpanded: false,
                        icon: const Icon(LucideIcons.pencil, size: 16),
                        onPressed: () => _editPayee(context, ref, payee),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  color: colorScheme.surfaceContainerLow,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pagePaddingMobile,
                    AppSpacing.space3,
                    AppSpacing.pagePaddingMobile,
                    AppSpacing.space1,
                  ),
                  child: Text(
                    'Related Transactions',
                    style: AppTypography.captionMedium.copyWith(
                      color: lootrColors.textSecondary,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space2,
                  vertical: AppSpacing.space1,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final transaction = transactions[index];
                    final category = transaction.categoryId == null
                        ? null
                        : categoryMap[transaction.categoryId];

                    return TransactionRowWidget(
                      transaction: transaction,
                      accountName:
                          accountMap[transaction.accountId] ?? transaction.accountId,
                      categoryName: category?.name,
                      payeeName: payee.resolvedName,
                      showDate: true,
                      leading: _TransactionLeading(
                        transactionCategory: category,
                        transactionDirection: transaction.direction,
                      ),
                      onTap: () => context.push('/transactions/${transaction.id}'),
                    );
                  }, childCount: transactions.length),
                ),
              ),
            ],
          );
        },
        error: (err, _) => Center(child: Text('Error: $err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _TransactionLeading extends StatelessWidget {
  const _TransactionLeading({
    required this.transactionCategory,
    required this.transactionDirection,
  });

  final Category? transactionCategory;
  final String transactionDirection;

  @override
  Widget build(BuildContext context) {
    final color = transactionCategory != null
        ? parseCategoryColor(transactionCategory!.color)
        : switch (transactionDirection) {
            'income' => context.lootrColors.income,
            'transfer' => context.lootrColors.transfer,
            _ => context.lootrColors.expense,
          };

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: transactionCategory != null
          ? buildCategoryVisualFor(transactionCategory, color: color, size: 18)
          : Icon(
              transactionDirection == 'transfer'
                  ? Icons.swap_horiz_rounded
                  : Icons.receipt_long_outlined,
              color: color,
              size: 18,
            ),
    );
  }
}
