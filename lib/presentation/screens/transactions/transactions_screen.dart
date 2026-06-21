import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import '../../../domain/value_objects/date_range.dart';
import '../../../domain/value_objects/transaction_filters.dart';
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
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() => _searchQuery = query.trim().toLowerCase());
    });
  }

  List<Transaction> _applySearch(
    List<Transaction> transactions, {
    required Map<String, String> accountNames,
    required Map<String, String> categoryNames,
    required Map<String, String> payeeNames,
  }) {
    if (_searchQuery.isEmpty) return transactions;
    return transactions.where((t) {
      if (t.note?.toLowerCase().contains(_searchQuery) == true) return true;
      if (t.amount.toString().contains(_searchQuery)) return true;
      if ((accountNames[t.accountId] ?? '').toLowerCase().contains(
        _searchQuery,
      )) {
        return true;
      }
      if ((categoryNames[t.categoryId] ?? '').toLowerCase().contains(
        _searchQuery,
      )) {
        return true;
      }
      if ((payeeNames[t.payeeId] ?? '').toLowerCase().contains(_searchQuery)) {
        return true;
      }
      final destinationAccountId =
          t.metadata?['destination_account_id']?.toString();
      final destinationName =
          (accountNames[destinationAccountId] ??
                  t.metadata?['destination_account_name']?.toString() ??
                  '')
              .toLowerCase();
      if (destinationName.contains(_searchQuery)) {
        return true;
      }
      return false;
    }).toList();
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));
    final monthStart = DateTime(now.year, now.month, 1);

    final groups = <String, List<Transaction>>{
      'Today': [],
      'Yesterday': [],
      'This Week': [],
      'This Month': [],
      'Earlier': [],
    };

    for (final txn in transactions) {
      final date = DateTime(
        txn.occurredAt.year,
        txn.occurredAt.month,
        txn.occurredAt.day,
      );
      if (date == today) {
        groups['Today']!.add(txn);
      } else if (date == yesterday) {
        groups['Yesterday']!.add(txn);
      } else if (date.isAfter(weekAgo)) {
        groups['This Week']!.add(txn);
      } else if (date.isAfter(monthStart.subtract(const Duration(days: 1)))) {
        groups['This Month']!.add(txn);
      } else {
        groups['Earlier']!.add(txn);
      }
    }

    groups.removeWhere((_, list) => list.isEmpty);
    return groups;
  }

  Future<void> _onDelete(String id) async {
    final transactionAsync = await ref.read(filteredTransactionsProvider.future);
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(undoEntry.message),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'UNDO',
                onPressed: () {
                  ref.read(undoStackProvider.notifier).undo(id);
                },
              ),
            ),
          );
        }
      },
      onFailure: (message, _) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
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
    final filters = ref.read(transactionFiltersProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _FilterSheetWidget(filters: filters),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionsTabProvider);
    final filters = ref.watch(transactionFiltersProvider);
    final accounts = ref.watch(accountsProvider);
    final categories = ref.watch(categoriesProvider);
    final payees = ref.watch(payeesProvider);

    return Scaffold(
      appBar: _isSearching ? _buildSearchAppBar() : _buildNormalAppBar(filters),
      body: Column(
        children: [
          if (!_isSearching) const FilterChipBar(),
          Expanded(
            child: _buildBody(state, filters, accounts, categories, payees),
          ),
        ],
      ),
    );
  }

  AppBar _buildNormalAppBar(dynamic filters) {
    final theme = Theme.of(context);
    return AppBar(
      centerTitle: false,
      leading: IconButton(
        icon: Icon(
          LucideIcons.slidersHorizontal,
          color: filters.isEmpty
              ? theme.colorScheme.onSurface
              : theme.colorScheme.primary,
        ),
        onPressed: _openFilterSheet,
      ),
      title: const Text('Transactions'),
      actions: [
        IconButton(
          icon: Icon(LucideIcons.search, color: theme.colorScheme.onSurface),
          onPressed: () => setState(() => _isSearching = true),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildSearchAppBar() {
    return AppBar(
      title: TextField(
        controller: _searchController,
        autofocus: true,
        style: AppTypography.body.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
        decoration: const InputDecoration(
          hintText: 'Search transactions...',
          border: InputBorder.none,
        ),
        onChanged: _onSearchChanged,
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          setState(() {
            _isSearching = false;
            _searchQuery = '';
            _searchController.clear();
          });
        },
      ),
    );
  }

  Widget _buildBody(
    TransactionsTabState state,
    TransactionFilters filters,
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
    final filtered = _applySearch(
      state.transactions,
      accountNames: accountNames,
      categoryNames: categoryNames,
      payeeNames: payeeNames,
    );

    final hasSearch = _searchQuery.isNotEmpty;
    final isFilterActive = !filters.isEmpty;

    if (filtered.isEmpty && (isFilterActive || hasSearch)) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: context.lootrColors.textTertiary,
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
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
                    child: const Text('Clear Search'),
                  ),
                if (isFilterActive)
                  FilledButton(
                    onPressed: () =>
                        ref.read(transactionFiltersProvider.notifier).reset(),
                    child: const Text('Clear Filters'),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: context.lootrColors.textTertiary,
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
              'Add your first transaction to start tracking',
              style: AppTypography.body.copyWith(
                color: context.lootrColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.space4),
            FilledButton.icon(
              onPressed: () => context.push('/transactions/new'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Transaction'),
            ),
          ],
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
            SliverPersistentHeader(
              pinned: true,
              delegate: DateGroupHeaderDelegate(title: entry.key),
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
                          ? (txn.metadata?['destination_account_name']?.toString() ??
                              accountNames[
                                  txn.metadata?['destination_account_id']?.toString()])
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
    final IconData icon;

    if (isTransferEntry(transaction)) {
      backgroundColor = context.lootrColors.transfer.withValues(alpha: 0.12);
      foregroundColor = context.lootrColors.transfer;
      icon = Icons.swap_horiz_rounded;
    } else if (category != null) {
      backgroundColor = _categoryGroupColor(category.categoryGroup).withValues(alpha: 0.12);
      foregroundColor = _categoryGroupColor(category.categoryGroup);
      icon = _categoryIcon(category.icon);
    } else {
      backgroundColor = Theme.of(context).colorScheme.surfaceContainerHighest;
      foregroundColor = Theme.of(context).colorScheme.onSurfaceVariant;
      icon = _accountTypeIcon(account?.accountType);
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: foregroundColor, size: 18),
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

  IconData _categoryIcon(String? iconName) {
    switch (iconName) {
      case 'shopping-cart':
      case 'cart':
        return Icons.shopping_cart_outlined;
      case 'utensils':
      case 'food':
        return Icons.restaurant_outlined;
      case 'tag':
        return Icons.sell_outlined;
      case 'transport':
        return Icons.directions_car_outlined;
      case 'house':
        return Icons.home_outlined;
      case 'medical':
        return Icons.local_hospital_outlined;
      case 'salary':
        return Icons.work_outline;
      default:
        return Icons.category_outlined;
    }
  }
}

class _FilterSheetWidget extends ConsumerStatefulWidget {
  const _FilterSheetWidget({required this.filters});

  final TransactionFilters filters;

  @override
  ConsumerState<_FilterSheetWidget> createState() => _FilterSheetWidgetState();
}

class _FilterSheetWidgetState extends ConsumerState<_FilterSheetWidget> {
  String? _direction;
  String? _mode;
  String? _accountId;
  String? _categoryId;
  DateRange? _dateRange;
  late final TextEditingController _minAmountController;
  late final TextEditingController _maxAmountController;

  @override
  void initState() {
    super.initState();
    _direction = widget.filters.direction;
    _mode = widget.filters.mode;
    _accountId = widget.filters.accountId;
    _categoryId = widget.filters.categoryId;
    _dateRange = widget.filters.dateRange;
    _minAmountController = TextEditingController(
      text: widget.filters.minAmount?.toStringAsFixed(0) ?? '',
    );
    _maxAmountController = TextEditingController(
      text: widget.filters.maxAmount?.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  void _apply() {
    final minText = _minAmountController.text.trim();
    final maxText = _maxAmountController.text.trim();
    ref
        .read(transactionFiltersProvider.notifier)
        .update(
          TransactionFilters(
            direction: _direction,
            mode: _mode,
            accountId: _accountId,
            categoryId: _categoryId,
            minAmount: minText.isEmpty ? null : double.tryParse(minText),
            maxAmount: maxText.isEmpty ? null : double.tryParse(maxText),
            dateRange: _dateRange,
          ),
        );
    Navigator.pop(context);
  }

  void _clearAll() {
    setState(() {
      _direction = null;
      _mode = null;
      _accountId = null;
      _categoryId = null;
      _dateRange = null;
      _minAmountController.clear();
      _maxAmountController.clear();
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
      initialDateRange: _dateRange == null
          ? null
          : DateTimeRange(start: _dateRange!.start, end: _dateRange!.end),
    );
    if (picked == null) return;
    setState(() => _dateRange = DateRange(picked.start, picked.end));
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    final normalized = s.replaceAll('_', ' ');
    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final accounts = accountsAsync is AsyncData<List<Account>>
        ? accountsAsync.value
        : const <Account>[];
    final categories = categoriesAsync is AsyncData<List<Category>>
        ? categoriesAsync.value
        : const <Category>[];

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.lootrColors.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Filters', style: AppTypography.h2),
                    GestureDetector(
                      onTap: _clearAll,
                      child: Text(
                        'Clear All',
                        style: AppTypography.captionMedium.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildFilterSection(
                      'Direction',
                      ['expense', 'income', 'transfer'],
                      _direction,
                      (v) => setState(
                        () => _direction = _direction == v ? null : v,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildFilterSection(
                      'Mode',
                      ['one_time', 'recurring', 'installment', 'debt'],
                      _mode,
                      (v) => setState(() => _mode = _mode == v ? null : v),
                    ),
                    const SizedBox(height: 20),
                    _buildIdFilterSection(
                      'Account',
                      {
                        for (final account in accounts)
                          account.id: account.name,
                      },
                      _accountId,
                      (v) => setState(
                        () => _accountId = _accountId == v ? null : v,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildIdFilterSection(
                      'Category',
                      {
                        for (final category in categories)
                          category.id: category.name,
                      },
                      _categoryId,
                      (v) => setState(
                        () => _categoryId = _categoryId == v ? null : v,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildAmountSection(),
                    const SizedBox(height: 20),
                    _buildDateSection(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _apply,
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterSection(
    String title,
    List<String> options,
    String? selected,
    ValueChanged<String> onTap,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.captionMedium.copyWith(
            color: context.lootrColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selected == option;
            final label = _capitalize(option);
            return ActionChip(
              label: Text(label),
              backgroundColor: isSelected
                  ? AppColors.primary50
                  : colorScheme.surface,
              side: BorderSide(
                color: isSelected ? AppColors.primary200 : colorScheme.outline,
              ),
              onPressed: () => onTap(option),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildIdFilterSection(
    String title,
    Map<String, String> options,
    String? selected,
    ValueChanged<String> onTap,
  ) {
    if (options.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.captionMedium.copyWith(
            color: context.lootrColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.entries.map((entry) {
            final isSelected = selected == entry.key;
            return ActionChip(
              label: Text(entry.value),
              backgroundColor: isSelected
                  ? AppColors.primary50
                  : colorScheme.surface,
              side: BorderSide(
                color: isSelected ? AppColors.primary200 : colorScheme.outline,
              ),
              onPressed: () => onTap(entry.key),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAmountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Amount',
          style: AppTypography.captionMedium.copyWith(
            color: context.lootrColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _minAmountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Min',
                  prefixText: '₱',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _maxAmountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Max',
                  prefixText: '₱',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateSection() {
    final label = _dateRange == null
        ? 'Any date'
        : '${_formatDate(_dateRange!.start)} - ${_formatDate(_dateRange!.end)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date',
          style: AppTypography.captionMedium.copyWith(
            color: context.lootrColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _pickDateRange,
                child: Text(label),
              ),
            ),
            if (_dateRange != null) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => setState(() => _dateRange = null),
                icon: const Icon(Icons.close),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
