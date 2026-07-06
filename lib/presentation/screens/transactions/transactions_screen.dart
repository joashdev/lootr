import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../application/providers/accounts_provider.dart';
import '../../../application/providers/categories_provider.dart';
import '../../../application/providers/filtered_transactions_provider.dart';
import '../../../application/providers/payees_provider.dart';
import '../../../application/providers/repo_providers.dart';
import '../../../application/providers/sync_providers.dart';
import '../../../application/providers/transaction_entry_support.dart';
import '../../../application/providers/transaction_filters_provider.dart';
import '../../../application/providers/transactions_tab_provider.dart';
import '../../../application/providers/undo_stack_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/entities/account.dart';
import '../../../domain/entities/category.dart';
import '../../../domain/entities/payee.dart';
import '../../../domain/entities/transaction.dart';
import '../../../domain/use_cases/delete_transaction.dart';
import '../../../domain/use_cases/delete_transfer.dart';
import '../../../domain/value_objects/transaction_filters.dart';
import '../more/more_form_sheets.dart';
import '../../sheets/filter_sheet.dart';
import '../../shared/category_visuals.dart';
import '../../shared/components/app_snackbar.dart';
import '../../shared/components/primary_screen_header.dart';
import '../../shared/components/buttons/ghost_button.dart';
import '../../shared/components/buttons/primary_button.dart';
import '../../shared/components/inputs/search_input.dart';
import 'widgets/date_group_header.dart';
import 'widgets/filter_chip_bar.dart';
import 'widgets/transaction_row.dart';
import 'widgets/transaction_shimmer.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    ref.read(transactionSearchQueryProvider.notifier).setQuery(query);
  }

  void _stopSearching() {
    setState(() => _isSearching = false);
    _searchController.clear();
    ref.read(transactionSearchQueryProvider.notifier).clear();
  }

  Map<String, String> _accountNameMap(AsyncValue<List<Account>> accounts) =>
      accounts is AsyncData<List<Account>>
      ? {for (final account in accounts.value) account.id: account.name}
      : const <String, String>{};

  Map<String, String> _categoryNameMap(AsyncValue<List<Category>> categories) =>
      categories is AsyncData<List<Category>>
      ? {for (final category in categories.value) category.id: category.name}
      : const <String, String>{};

  Map<String, String> _payeeNameMap(AsyncValue<List<Payee>> payees) =>
      payees is AsyncData<List<Payee>>
      ? {
          for (final payee in payees.value)
            payee.id: payee.displayName?.isNotEmpty == true
                ? payee.displayName!
                : payee.normalizedName,
        }
      : const <String, String>{};

  Map<String, Account> _accountMap(AsyncValue<List<Account>> accounts) =>
      accounts is AsyncData<List<Account>>
      ? {for (final account in accounts.value) account.id: account}
      : const <String, Account>{};

  Map<String, Category> _categoryMap(AsyncValue<List<Category>> categories) =>
      categories is AsyncData<List<Category>>
      ? {for (final category in categories.value) category.id: category}
      : const <String, Category>{};

  Map<String, List<Transaction>> _groupByDate(List<Transaction> transactions) {
    final grouped = <String, List<Transaction>>{};

    for (final txn in transactions) {
      final dateKey = DateFormat('dd/MM/yyyy').format(txn.occurredAt);
      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(txn);
    }

    final sorted = Map<String, List<Transaction>>.fromEntries(
      grouped.entries.toList()
        ..sort((a, b) {
          final dateA = DateFormat('dd/MM/yyyy').parse(a.key);
          final dateB = DateFormat('dd/MM/yyyy').parse(b.key);
          return dateB.compareTo(dateA);
        }),
    );

    return sorted;
  }

  Future<void> _onDelete(String id) async {
    final transactionAsync = await ref.read(
      filteredTransactionsProvider.future,
    );
    if (!mounted) return;
    final transaction = transactionAsync.cast<Transaction?>().firstWhere(
      (item) => item?.id == id,
      orElse: () => null,
    );
    if (transaction == null) return;
    final isTransfer = isTransferEntry(transaction);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isTransfer ? 'Delete Transfer' : 'Delete Transaction'),
        content: Text(
          isTransfer
              ? 'Are you sure you want to delete this transfer?'
              : 'Are you sure you want to delete this transaction?',
        ),
        actions: [
          GhostButton(
            label: 'Cancel',
            onPressed: () => Navigator.pop(ctx, false),
            isExpanded: false,
          ),
          GhostButton(
            label: 'Delete',
            onPressed: () => Navigator.pop(ctx, true),
            isDanger: true,
            isExpanded: false,
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = isTransfer
        ? await DeleteTransfer(ref.read(transferRepoProvider)).call(id)
        : await DeleteTransaction(ref.read(transactionRepoProvider)).call(id);

    result.fold(
      onSuccess: (undoEntry) {
        ref.read(undoStackProvider.notifier).push(undoEntry);
        if (mounted) {
          AppSnackBar.show(
            context,
            undoEntry.message,
            variant: AppSnackBarVariant.success,
            actionLabel: 'UNDO',
            onAction: () {
              ref.read(undoStackProvider.notifier).undo(id);
            },
            duration: const Duration(seconds: 5),
          );
        }
      },
      onFailure: (message, _) {
        if (mounted) {
          AppSnackBar.show(
            context,
            message,
            variant: AppSnackBarVariant.error,
          );
        }
      },
    );
  }

  Future<void> _onRefresh() async {
    try {
      final syncManager = ref.read(syncManagerProvider);
      await syncManager.sync();
    } catch (_) {}
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => const FilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionsTabProvider);
    final filters = ref.watch(transactionFiltersProvider);
    final searchQuery = ref.watch(transactionSearchQueryProvider);
    final accounts = ref.watch(accountsProvider);
    final categories = ref.watch(categoriesProvider);
    final payees = ref.watch(payeesProvider);

    return Scaffold(
      appBar: _isSearching ? _buildSearchAppBar() : _buildNormalAppBar(filters),
      body: Column(
        children: [
          if (!_isSearching) const FilterChipBar(),
          Expanded(
            child: _buildBody(
              state,
              filters,
              searchQuery,
              accounts,
              categories,
              payees,
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildNormalAppBar(TransactionFilters filters) {
    final theme = Theme.of(context);
    return PrimaryScreenHeader(
      title: 'Transactions',
      actions: [
        IconButton(
          tooltip: 'Filter transactions',
          icon: Icon(
            LucideIcons.slidersHorizontal,
            color: filters.isEmpty
                ? theme.colorScheme.onSurface
                : theme.colorScheme.primary,
          ),
          onPressed: _openFilterSheet,
        ),
        IconButton(
          tooltip: 'Search transactions',
          icon: Icon(LucideIcons.search, color: theme.colorScheme.onSurface),
          onPressed: () => setState(() => _isSearching = true),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildSearchAppBar() {
    return AppBar(
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.only(right: AppSpacing.space4),
        child: SearchInput(
          controller: _searchController,
          autofocus: true,
          onChanged: _onSearchChanged,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: _stopSearching,
      ),
    );
  }

  Widget _buildBody(
    TransactionsTabState state,
    TransactionFilters filters,
    String searchQuery,
    AsyncValue<List<Account>> accounts,
    AsyncValue<List<Category>> categories,
    AsyncValue<List<Payee>> payees,
  ) {
    if (state.isLoading) {
      return const TransactionShimmer();
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Something went wrong',
                style: AppTypography.h2.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.error!,
                style: AppTypography.body.copyWith(
                  color: context.lootrColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => ref.invalidate(filteredTransactionsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final accountNames = _accountNameMap(accounts);
    final categoryNames = _categoryNameMap(categories);
    final payeeNames = _payeeNameMap(payees);
    final accountMap = _accountMap(accounts);
    final categoryMap = _categoryMap(categories);
    final filtered = state.transactions;
    final activeAccounts =
        accounts.asData?.value
            .where(
              (account) => account.deletedAt == null && !account.isArchived,
            )
            .toList() ??
        const <Account>[];

    final hasSearch = searchQuery.isNotEmpty;
    final isFilterActive = !filters.isEmpty;

    if (filtered.isEmpty && (isFilterActive || hasSearch)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: Icon(
                  Icons.search_off,
                  size: 64,
                  color: context.lootrColors.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.space4),
              Text(
                'No results',
                style: AppTypography.h2.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.space2),
              Text(
                hasSearch
                    ? 'Try adjusting your search'
                    : 'Try adjusting your filters',
                style: AppTypography.body.copyWith(
                  color: context.lootrColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.space4),
              Wrap(
                spacing: AppSpacing.space2,
                runSpacing: AppSpacing.space2,
                alignment: WrapAlignment.center,
                children: [
                  if (hasSearch)
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 220),
                      child: PrimaryButton(
                        label: 'Clear Search',
                        onPressed: () {
                          _searchController.clear();
                          ref.read(transactionSearchQueryProvider.notifier).clear();
                        },
                        isExpanded: false,
                      ),
                    ),
                  if (isFilterActive)
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 220),
                      child: PrimaryButton(
                        label: 'Clear Filters',
                        onPressed: () =>
                            ref.read(transactionFiltersProvider.notifier).reset(),
                        isExpanded: false,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (filtered.isEmpty) {
      final needsAccount =
          accounts is AsyncData<List<Account>> && activeAccounts.isEmpty;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: Icon(
                  Icons.receipt_long_outlined,
                  size: 64,
                  color: context.lootrColors.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.space4),
              Text(
                'No transactions yet',
                style: AppTypography.h2.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.space2),
              Text(
                needsAccount
                    ? 'Add an account first, then track transactions.'
                    : 'Add your first transaction to start tracking',
                style: AppTypography.body.copyWith(
                  color: context.lootrColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.space4),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 220),
                child: PrimaryButton(
                  label: needsAccount ? 'Add Account' : 'Add Transaction',
                  onPressed: () {
                    if (needsAccount) {
                      showAccountSheet(context, ref);
                    } else {
                      context.push('/transactions/new');
                    }
                  },
                  icon: const Icon(Icons.add, size: 18),
                  isExpanded: false,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final groups = _groupByDate(filtered);

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          for (final entry in groups.entries) ...[
            SliverToBoxAdapter(
              child: DateGroupHeader(
                title: formatDateGroupTitle(
                  DateFormat('dd/MM/yyyy').parse(entry.key),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final txn = entry.value[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Dismissible(
                    key: Key(txn.id),
                    direction: DismissDirection.horizontal,
                    confirmDismiss: (direction) async {
                      if (direction == DismissDirection.startToEnd) {
                        final transfer = transferFromTransaction(txn);
                        context.push(
                          '/transactions/new',
                          extra: transfer ?? txn,
                        );
                        return false;
                      }
                      await _onDelete(txn.id);
                      return false;
                    },
                    background: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 20),
                      decoration: BoxDecoration(
                        color: AppColors.primary600,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit, color: Colors.white),
                    ),
                    secondaryBackground: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: AppColors.danger600,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    child: TransactionRowWidget(
                      transaction: txn,
                      accountName: accountNames[txn.accountId] ?? txn.accountId,
                      categoryName: isTransferEntry(txn)
                          ? null
                          : txn.categoryId == null
                          ? null
                          : categoryNames[txn.categoryId] ?? txn.categoryId,
                      payeeName: isTransferEntry(txn)
                          ? (txn.metadata?['destination_account_name']
                                    ?.toString() ??
                                accountNames[txn
                                    .metadata?['destination_account_id']
                                    ?.toString()])
                          : txn.payeeId == null
                          ? null
                          : payeeNames[txn.payeeId] ?? txn.payeeId,
                      leading: _buildRowLeading(
                        txn,
                        account: accountMap[txn.accountId],
                        category: txn.categoryId == null
                            ? null
                            : categoryMap[txn.categoryId],
                      ),
                      onTap: () => context.push('/transactions/${txn.id}'),
                    ),
                  ),
                );
              }, childCount: entry.value.length),
            ),
          ],
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 148),
              child: Center(
                child: Text(
                  'No more transactions',
                  style: AppTypography.caption.copyWith(
                    color: context.lootrColors.textTertiary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRowLeading(
    Transaction transaction, {
    Account? account,
    Category? category,
  }) {
    final Color backgroundColor;
    final Color foregroundColor;
    final Widget child;

    if (isTransferEntry(transaction)) {
      backgroundColor = context.lootrColors.transfer.withValues(alpha: 0.12);
      foregroundColor = context.lootrColors.transfer;
      child = Icon(
        Icons.swap_horiz_rounded,
        color: foregroundColor,
        size: 18,
      );
    } else if (category != null) {
      foregroundColor = category.color != null && category.color!.isNotEmpty
          ? parseCategoryColor(category.color)
          : _categoryGroupColor(category.categoryGroup);
      backgroundColor = foregroundColor.withValues(alpha: 0.12);
      child = buildCategoryVisualFor(
        category,
        color: foregroundColor,
        size: 18,
      );
    } else {
      backgroundColor = Theme.of(context).colorScheme.surfaceContainerHighest;
      foregroundColor = Theme.of(context).colorScheme.onSurfaceVariant;
      child = Icon(
        _accountTypeIcon(account?.accountType),
        color: foregroundColor,
        size: 18,
      );
    }

    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: child,
    );
  }

  Color _categoryGroupColor(String group) {
    switch (group) {
      case 'income':
        return context.lootrColors.income;
      case 'transfer':
        return context.lootrColors.transfer;
      default:
        return context.lootrColors.expense;
    }
  }

  IconData _accountTypeIcon(String? accountType) {
    switch (accountType) {
      case 'cash':
        return Icons.payments_outlined;
      case 'ewallet':
        return Icons.smartphone_outlined;
      case 'savings':
        return Icons.savings_outlined;
      case 'investment':
        return Icons.show_chart;
      case 'crypto':
        return Icons.currency_bitcoin;
      case 'credit_card':
        return Icons.credit_card_outlined;
      case 'loan':
      case 'bnpl':
        return Icons.account_balance_wallet_outlined;
      case 'bank':
      default:
        return Icons.account_balance_outlined;
    }
  }

}
