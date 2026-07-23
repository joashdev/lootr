import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../application/providers/accounts_provider.dart';
import '../../../application/providers/categories_provider.dart';
import '../../../application/providers/filtered_transactions_provider.dart';
import '../../../application/providers/notification_provider.dart';
import '../../../application/providers/payees_provider.dart';
import '../../../application/providers/period_context_provider.dart';
import '../../../application/providers/repo_providers.dart';
import '../../../application/providers/sync_providers.dart';
import '../../../application/providers/transaction_entry_support.dart';
import '../../../application/providers/transaction_filters_provider.dart';
import '../../../application/providers/transaction_list_intent_provider.dart';
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
import '../../../domain/value_objects/transaction_list_intent.dart';
import '../../../domain/value_objects/undo_entry.dart';
import '../../../data/repositories/transaction_repo.dart';
import '../more/more_form_sheets.dart';
import '../../sheets/filter_sheet.dart';
import '../../shared/category_visuals.dart';
import '../../shared/components/app_snackbar.dart';
import '../../shared/components/primary_screen_header.dart';
import '../../shared/components/buttons/ghost_button.dart';
import '../../shared/components/buttons/primary_button.dart';
import '../../shared/components/inputs/search_input.dart';
import '../../shared/components/period_selector.dart';
import 'widgets/date_group_header.dart';
import 'widgets/filter_chip_bar.dart';
import 'widgets/transaction_row.dart';
import 'widgets/transaction_shimmer.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key, this.initialModeFilter});

  final String? initialModeFilter;

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String? _lastAppliedRouteModeFilter;

  @override
  void initState() {
    super.initState();
    final persistedQuery = ref.read(transactionSearchQueryProvider);
    _searchController.text = persistedQuery;
    _isSearching = persistedQuery.isNotEmpty;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyRouteModeFilterIfNeeded();
    });
  }

  @override
  void didUpdateWidget(covariant TransactionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialModeFilter == widget.initialModeFilter) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyRouteModeFilterIfNeeded();
    });
  }

  void _applyRouteModeFilterIfNeeded() {
    if (!mounted) {
      return;
    }

    final filterNotifier = ref.read(transactionFiltersProvider.notifier);
    final routeModeFilter = widget.initialModeFilter;
    if (routeModeFilter == null || routeModeFilter.isEmpty) {
      final lastAppliedRouteModeFilter = _lastAppliedRouteModeFilter;
      _lastAppliedRouteModeFilter = null;
      if (lastAppliedRouteModeFilter != null &&
          ref.read(transactionFiltersProvider).mode ==
              lastAppliedRouteModeFilter) {
        filterNotifier.setMode(null);
      }
      return;
    }

    if (_lastAppliedRouteModeFilter == routeModeFilter) {
      return;
    }

    _lastAppliedRouteModeFilter = routeModeFilter;
    filterNotifier.setMode(routeModeFilter);
  }

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
      grouped.entries.toList()..sort((a, b) {
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
    if (!isTransfer && result.isSuccess) {
      await ref.read(notificationSchedulerProvider).rebuildSchedule();
    }

    result.fold(
      onSuccess: (undoEntry) {
        ref
            .read(undoStackProvider.notifier)
            .push(
              UndoEntry(
                transactionId: undoEntry.transactionId,
                message: undoEntry.message,
                rollback: () async {
                  await undoEntry.rollback();
                  await ref
                      .read(notificationSchedulerProvider)
                      .rebuildSchedule();
                },
                createdAt: undoEntry.createdAt,
              ),
            );
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
          AppSnackBar.show(context, message, variant: AppSnackBarVariant.error);
        }
      },
    );
  }

  Future<String?> _pickBulkTarget({
    required String title,
    required List<({String id, String label})> options,
  }) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(title),
        children: [
          for (final option in options)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, option.id),
              child: Text(option.label),
            ),
          if (options.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.space4),
              child: Text('No available options.'),
            ),
        ],
      ),
    );
  }

  Future<bool> _showBulkIssues(List<TransactionBulkIssue> issues) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nothing changed'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Resolve these items before applying the change:'),
                const SizedBox(height: AppSpacing.space3),
                for (final message
                    in issues.map((issue) => issue.message).toSet())
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.space2),
                    child: Text('• $message'),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    return false;
  }

  Future<void> _runBulkOperation(
    TransactionBulkOperation operation, {
    String? targetId,
  }) async {
    final intent = ref.read(transactionListIntentProvider);
    final request = TransactionBulkRequest(
      transactionIds: intent.selectedIds,
      operation: operation,
      targetId: targetId,
    );
    final repo = ref.read(transactionRepoProvider);
    final plan = await repo.preflightBulk(request);
    if (!mounted) return;
    if (!plan.canApply) {
      await _showBulkIssues(plan.issues);
      return;
    }

    if (operation == TransactionBulkOperation.delete) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            'Delete ${plan.transactionIds.length} '
            'transaction${plan.transactionIds.length == 1 ? '' : 's'}?',
          ),
          content: const Text(
            'Balances will be updated. You can undo this for five seconds.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    try {
      final undo = await repo.applyBulk(plan);
      await ref.read(notificationSchedulerProvider).rebuildSchedule();
      if (!mounted) return;
      final batchId = 'bulk-${DateTime.now().microsecondsSinceEpoch}';
      final count = undo.transactionIds.length;
      final action = switch (operation) {
        TransactionBulkOperation.recategorize => 'recategorized',
        TransactionBulkOperation.moveAccount => 'moved',
        TransactionBulkOperation.delete => 'deleted',
      };
      ref
          .read(undoStackProvider.notifier)
          .push(
            UndoEntry(
              transactionId: batchId,
              message: '$count transaction${count == 1 ? '' : 's'} $action',
              rollback: () async {
                await undo.rollback();
                await ref.read(notificationSchedulerProvider).rebuildSchedule();
              },
              createdAt: DateTime.now(),
            ),
          );
      ref.read(transactionListIntentProvider.notifier).clearSelection();
      AppSnackBar.show(
        context,
        '$count transaction${count == 1 ? '' : 's'} $action',
        variant: AppSnackBarVariant.success,
        actionLabel: 'UNDO',
        onAction: () => ref.read(undoStackProvider.notifier).undo(batchId),
        duration: const Duration(seconds: 5),
      );
    } on TransactionBulkPreflightException catch (error) {
      if (mounted) await _showBulkIssues(error.issues);
    } catch (error) {
      if (mounted) {
        AppSnackBar.show(
          context,
          'The batch was not applied. $error',
          variant: AppSnackBarVariant.error,
        );
      }
    }
  }

  Future<void> _bulkRecategorize() async {
    final categories =
        ref.read(categoriesProvider).asData?.value ?? const <Category>[];
    final target = await _pickBulkTarget(
      title: 'Choose category',
      options: categories
          .where((category) => category.deletedAt == null)
          .map((category) => (id: category.id, label: category.name))
          .toList(),
    );
    if (target != null && mounted) {
      await _runBulkOperation(
        TransactionBulkOperation.recategorize,
        targetId: target,
      );
    }
  }

  Future<void> _bulkMoveAccount() async {
    final accounts =
        ref.read(accountsProvider).asData?.value ?? const <Account>[];
    final target = await _pickBulkTarget(
      title: 'Move to account',
      options: accounts
          .where((account) => account.deletedAt == null && !account.isArchived)
          .map(
            (account) => (
              id: account.id,
              label: '${account.name} · ${account.currencyCode}',
            ),
          )
          .toList(),
    );
    if (target != null && mounted) {
      await _runBulkOperation(
        TransactionBulkOperation.moveAccount,
        targetId: target,
      );
    }
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
    final listIntent = ref.watch(transactionListIntentProvider);
    final ledgerQuery = ref.watch(activeLedgerQueryProvider);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && ledgerQuery != null) {
          ref.read(activeLedgerQueryProvider.notifier).clear();
        }
      },
      child: Scaffold(
        appBar: listIntent.isSelecting
            ? _buildSelectionAppBar(listIntent)
            : _isSearching
            ? _buildSearchAppBar()
            : _buildNormalAppBar(filters, listIntent),
        body: Column(
          children: [
            if (!listIntent.isSelecting && !_isSearching)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pagePaddingMobile,
                ),
                child: Row(
                  children: [
                    const Expanded(child: PeriodSelector(compact: true)),
                    if (ledgerQuery != null)
                      TextButton(
                        onPressed: () => ref
                            .read(activeLedgerQueryProvider.notifier)
                            .clear(),
                        child: const Text('Clear drill-down'),
                      ),
                  ],
                ),
              ),
            if (ledgerQuery != null && !listIntent.isSelecting && !_isSearching)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pagePaddingMobile,
                  0,
                  AppSpacing.pagePaddingMobile,
                  AppSpacing.space2,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    ledgerQuery.explanation,
                    style: AppTypography.caption.copyWith(
                      color: context.lootrColors.textSecondary,
                    ),
                  ),
                ),
              ),
            if (!listIntent.isSelecting && !_isSearching) const FilterChipBar(),
            Expanded(
              child: _buildBody(
                state,
                filters,
                searchQuery,
                accounts,
                categories,
                payees,
                listIntent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildNormalAppBar(
    TransactionFilters filters,
    TransactionListIntent listIntent,
  ) {
    final theme = Theme.of(context);
    return PrimaryScreenHeader(
      title: 'Transactions',
      actions: [
        PopupMenuButton<TransactionSort>(
          tooltip: 'Sort transactions',
          initialValue: listIntent.sort,
          onSelected: ref.read(transactionListIntentProvider.notifier).setSort,
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: TransactionSort.newestFirst,
              child: Text('Newest first'),
            ),
            PopupMenuItem(
              value: TransactionSort.oldestFirst,
              child: Text('Oldest first'),
            ),
          ],
          icon: const Icon(LucideIcons.arrowUpDown),
        ),
        IconButton(
          tooltip: 'Select transactions',
          onPressed: () =>
              ref.read(transactionListIntentProvider.notifier).startSelection(),
          icon: const Icon(LucideIcons.listChecks),
        ),
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

  PreferredSizeWidget _buildSelectionAppBar(TransactionListIntent intent) {
    final hasSelection = intent.selectedIds.isNotEmpty;
    return AppBar(
      leading: IconButton(
        tooltip: 'Exit selection mode',
        onPressed: () =>
            ref.read(transactionListIntentProvider.notifier).clearSelection(),
        icon: const Icon(Icons.close),
      ),
      title: Text(
        hasSelection
            ? '${intent.selectedIds.length} selected'
            : 'Select transactions',
      ),
      actions: [
        IconButton(
          tooltip: 'Recategorize selected',
          onPressed: hasSelection ? _bulkRecategorize : null,
          icon: const Icon(LucideIcons.tags),
        ),
        IconButton(
          tooltip: 'Move selected to account',
          onPressed: hasSelection ? _bulkMoveAccount : null,
          icon: const Icon(LucideIcons.walletCards),
        ),
        IconButton(
          tooltip: 'Delete selected',
          onPressed: hasSelection
              ? () => _runBulkOperation(TransactionBulkOperation.delete)
              : null,
          icon: const Icon(LucideIcons.trash2),
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
    TransactionListIntent listIntent,
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
                          ref
                              .read(transactionSearchQueryProvider.notifier)
                              .clear();
                        },
                        isExpanded: false,
                      ),
                    ),
                  if (isFilterActive)
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 220),
                      child: PrimaryButton(
                        label: 'Clear Filters',
                        onPressed: () => ref
                            .read(transactionFiltersProvider.notifier)
                            .reset(),
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
                    direction: listIntent.isSelecting
                        ? DismissDirection.none
                        : DismissDirection.horizontal,
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
                      showSelectionIndicator: listIntent.isSelecting,
                      isSelected: listIntent.selectedIds.contains(txn.id),
                      onLongPress: () => ref
                          .read(transactionListIntentProvider.notifier)
                          .startSelection(txn.id),
                      onTap: listIntent.isSelecting
                          ? () => ref
                                .read(transactionListIntentProvider.notifier)
                                .toggleSelection(txn.id)
                          : () => context.push('/transactions/${txn.id}'),
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
      child = Icon(Icons.swap_horiz_rounded, color: foregroundColor, size: 18);
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
