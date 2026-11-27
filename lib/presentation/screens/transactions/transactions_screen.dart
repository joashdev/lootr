import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../application/providers/accounts_provider.dart';
import '../../../application/providers/categories_provider.dart';
import '../../../application/providers/filtered_transactions_provider.dart';
import '../../../application/providers/notification_provider.dart';
import '../../../application/providers/payees_provider.dart';
import '../../../application/providers/period_context_provider.dart';
import '../../../application/providers/repo_providers.dart';
import '../../../application/providers/sync_providers.dart';
import '../../../application/providers/transaction_bulk_command_provider.dart';
import '../../../application/providers/transaction_entry_support.dart';
import '../../../application/providers/transaction_filters_provider.dart';
import '../../../application/providers/transaction_list_intent_provider.dart';
import '../../../application/providers/transactions_tab_provider.dart';
import '../../../application/providers/undo_stack_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radius.dart';
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
  String? _lastAppliedRouteModeFilter;

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(transactionSearchQueryProvider);
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

  void _clearSearch() {
    _searchController.clear();
    ref.read(transactionSearchQueryProvider.notifier).clear();
  }

  void _startSelection([String? id]) {
    FocusScope.of(context).unfocus();
    ref.read(transactionListIntentProvider.notifier).startSelection(id);
  }

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

  Map<DateTime, List<Transaction>> _groupByDate(
    List<Transaction> transactions,
  ) {
    final grouped = <DateTime, List<Transaction>>{};

    for (final txn in transactions) {
      final day = DateUtils.dateOnly(txn.occurredAt);
      grouped.putIfAbsent(day, () => []).add(txn);
    }

    // Dart maps preserve insertion order, so date groups follow the already
    // sorted provider output for both newest-first and oldest-first modes.
    return grouped;
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
    final command = ref.read(transactionBulkCommandProvider);
    final plan = await command.preflight(request);
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
      final undo = await command.apply(plan);
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
    FocusScope.of(context).unfocus();
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
    final size = MediaQuery.sizeOf(context);
    final labelScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final compactControls = size.width < 56 + 250 * labelScale;
    final stackControls =
        compactControls &&
        size.height - MediaQuery.viewInsetsOf(context).bottom > 360;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && ledgerQuery != null) {
          ref.read(activeLedgerQueryProvider.notifier).clear();
        }
      },
      child: Scaffold(
        appBar: listIntent.isSelecting
            ? _buildSelectionAppBar(listIntent)
            : _buildNormalAppBar(
                listIntent,
                compact: compactControls,
                stackControls: stackControls,
              ),
        body: Column(
          children: [
            Offstage(
              offstage: listIntent.isSelecting,
              child: ExcludeFocus(
                excluding: listIntent.isSelecting,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pagePaddingMobile,
                    AppSpacing.space2,
                    AppSpacing.pagePaddingMobile,
                    AppSpacing.space1,
                  ),
                  child: Column(
                    children: [
                      if (stackControls)
                        Wrap(
                          spacing: AppSpacing.space1,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildSortButton(listIntent, showLabel: true),
                            _buildFilterButton(filters, textOnly: true),
                            _buildSelectButton(),
                          ],
                        ),
                      if (stackControls)
                        const SizedBox(height: AppSpacing.space2),
                      Row(
                        key: const ValueKey('transaction-search'),
                        children: [
                          Expanded(
                            child: Tooltip(
                              message: 'Search transactions',
                              child: SearchInput(
                                controller: _searchController,
                                onChanged: _onSearchChanged,
                              ),
                            ),
                          ),
                          if (!stackControls) ...[
                            const SizedBox(width: AppSpacing.space2),
                            _buildFilterButton(
                              filters,
                              iconOnly: compactControls,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (listIntent.isSelecting)
              _buildSelectionActions(listIntent.selectedIds.isNotEmpty)
            else ...[
              const Center(child: PeriodSelector(compact: true)),
              if (ledgerQuery != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pagePaddingMobile,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          ledgerQuery.explanation,
                          style: AppTypography.captionMedium.copyWith(
                            color: context.lootrColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space2),
                      TextButton(
                        onPressed: () => ref
                            .read(activeLedgerQueryProvider.notifier)
                            .clear(),
                        child: const Text('Clear drill-down'),
                      ),
                    ],
                  ),
                ),
              const FilterChipBar(),
            ],
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
    TransactionListIntent listIntent, {
    required bool compact,
    required bool stackControls,
  }) {
    if (compact) {
      return AppBar(
        automaticallyImplyLeading: false,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('Transactions', style: AppTypography.h2),
        ),
        actions: stackControls
            ? null
            : [
                _buildSortButton(listIntent),
                IconButton(
                  tooltip: 'Select transactions',
                  onPressed: _startSelection,
                  icon: const Icon(LucideIcons.listChecks),
                ),
              ],
      );
    }
    return PrimaryScreenHeader(
      title: 'Transactions',
      actions: [
        _buildSortButton(listIntent, showLabel: true),
        _buildSelectButton(),
      ],
    );
  }

  Widget _buildSelectButton() {
    return Tooltip(
      message: 'Select transactions',
      child: TextButton(
        onPressed: _startSelection,
        child: const Text('Select'),
      ),
    );
  }

  Widget _buildSortButton(
    TransactionListIntent listIntent, {
    bool showLabel = false,
  }) {
    return PopupMenuButton<TransactionSort>(
      tooltip: 'Sort transactions',
      initialValue: listIntent.sort,
      onSelected: ref.read(transactionListIntentProvider.notifier).setSort,
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
          value: TransactionSort.newestFirst,
          checked: listIntent.sort == TransactionSort.newestFirst,
          child: const Text('Newest first'),
        ),
        CheckedPopupMenuItem(
          value: TransactionSort.oldestFirst,
          checked: listIntent.sort == TransactionSort.oldestFirst,
          child: const Text('Oldest first'),
        ),
      ],
      icon: showLabel ? null : const Icon(LucideIcons.arrowUpDown, size: 20),
      child: showLabel
          ? Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space2,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Align(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Text(
                    'Sort',
                    style: AppTypography.captionMedium.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildFilterButton(
    TransactionFilters filters, {
    bool iconOnly = false,
    bool textOnly = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    final foreground = filters.isEmpty
        ? colors.onSurface
        : colors.onPrimaryContainer;
    final background = filters.isEmpty
        ? colors.surface
        : colors.primaryContainer;
    const icon = Icon(LucideIcons.slidersHorizontal, size: 18);
    if (iconOnly) {
      return IconButton.outlined(
        tooltip: filters.isEmpty
            ? 'Filter transactions'
            : 'Filter transactions (${filters.activeCount} active)',
        onPressed: _openFilterSheet,
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          side: BorderSide(color: colors.outline),
          foregroundColor: foreground,
          backgroundColor: background,
        ),
        icon: Badge(
          isLabelVisible: !filters.isEmpty,
          backgroundColor: colors.onPrimaryContainer,
          child: icon,
        ),
      );
    }
    return Tooltip(
      message: 'Filter transactions',
      child: OutlinedButton(
        onPressed: _openFilterSheet,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: EdgeInsets.symmetric(
            horizontal: textOnly ? AppSpacing.space2 : AppSpacing.space3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          side: BorderSide(color: colors.outline),
          foregroundColor: foreground,
          backgroundColor: background,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!textOnly) ...[icon, const SizedBox(width: AppSpacing.space2)],
            Text(
              filters.isEmpty || textOnly
                  ? 'Filters'
                  : 'Filters (${filters.activeCount})',
              style: AppTypography.captionMedium,
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildSelectionAppBar(TransactionListIntent intent) {
    final hasSelection = intent.selectedIds.isNotEmpty;
    return AppBar(
      leading: IconButton(
        tooltip: 'Exit selection mode',
        onPressed: () =>
            ref.read(transactionListIntentProvider.notifier).clearSelection(),
        icon: const Icon(LucideIcons.x),
      ),
      title: Text(
        hasSelection
            ? '${intent.selectedIds.length} selected'
            : 'Select transactions',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildSelectionActions(bool hasSelection) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: AppSpacing.space1,
        children: [
          Tooltip(
            message: 'Recategorize selected',
            child: TextButton.icon(
              onPressed: hasSelection ? _bulkRecategorize : null,
              icon: const Icon(LucideIcons.tags, size: 18),
              label: const Text('Category'),
            ),
          ),
          Tooltip(
            message: 'Move selected to account',
            child: TextButton.icon(
              onPressed: hasSelection ? _bulkMoveAccount : null,
              icon: const Icon(LucideIcons.walletCards, size: 18),
              label: const Text('Account'),
            ),
          ),
          Tooltip(
            message: 'Delete selected',
            child: TextButton.icon(
              onPressed: hasSelection
                  ? () => _runBulkOperation(TransactionBulkOperation.delete)
                  : null,
              style: TextButton.styleFrom(foregroundColor: colors.error),
              icon: const Icon(LucideIcons.trash2, size: 18),
              label: const Text('Delete'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scrollableMessage({required Widget child}) {
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(hasScrollBody: false, child: Center(child: child)),
      ],
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
      return _scrollableMessage(
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
      return _scrollableMessage(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 44,
                color: context.lootrColors.textSecondary,
              ),
              const SizedBox(height: AppSpacing.space4),
              Text(
                'No results',
                style: AppTypography.h2.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.space2),
              Text(
                hasSearch
                    ? 'Try adjusting your search'
                    : 'Try adjusting your filters',
                style: AppTypography.body.copyWith(
                  color: context.lootrColors.textSecondary,
                ),
                textAlign: TextAlign.center,
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
                        onPressed: _clearSearch,
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
      return _scrollableMessage(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 44,
                color: context.lootrColors.textSecondary,
              ),
              const SizedBox(height: AppSpacing.space4),
              Text(
                needsAccount
                    ? 'No transactions yet'
                    : 'No transactions this period',
                style: AppTypography.h2.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.space2),
              if (needsAccount)
                Text(
                  'Add an account first, then track transactions.',
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
                  isExpanded: false,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final groups = _groupByDate(filtered);
    final accountMap = _accountMap(accounts);
    final categoryMap = _categoryMap(categories);
    final payeeNames = _payeeNameMap(payees);
    final colors = Theme.of(context).colorScheme;

    Widget buildRow(BuildContext context, Transaction txn) {
      final account = accountMap[txn.accountId];
      final category = categoryMap[txn.categoryId];
      final transfer = isTransferEntry(txn);
      return Dismissible(
        key: ValueKey(txn.id),
        direction: listIntent.isSelecting
            ? DismissDirection.none
            : DismissDirection.horizontal,
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            context.push(
              '/transactions/new',
              extra: transferFromTransaction(txn) ?? txn,
            );
            return false;
          }
          await _onDelete(txn.id);
          return false;
        },
        background: _swipeBackground(
          isLeading: true,
          label: 'Edit',
          icon: LucideIcons.pencil,
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
        ),
        secondaryBackground: _swipeBackground(
          isLeading: false,
          label: 'Delete',
          icon: LucideIcons.trash2,
          backgroundColor: colors.errorContainer,
          foregroundColor: colors.onErrorContainer,
        ),
        child: TransactionRowWidget(
          transaction: txn,
          accountName: account?.name ?? txn.accountId,
          categoryName: transfer ? null : category?.name ?? txn.categoryId,
          payeeName: transfer
              ? (txn.metadata?['destination_account_name']?.toString() ??
                    accountMap[txn.metadata?['destination_account_id']
                            ?.toString()]
                        ?.name)
              : payeeNames[txn.payeeId] ?? txn.payeeId,
          leading: _buildRowLeading(txn, account: account, category: category),
          showSelectionIndicator: listIntent.isSelecting,
          isSelected: listIntent.selectedIds.contains(txn.id),
          grouped: true,
          onLongPress: () => _startSelection(txn.id),
          onTap: listIntent.isSelecting
              ? () => ref
                    .read(transactionListIntentProvider.notifier)
                    .toggleSelection(txn.id)
              : () => context.push('/transactions/${txn.id}'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pagePaddingMobile,
              AppSpacing.space2,
              AppSpacing.pagePaddingMobile,
              0,
            ),
            sliver: DecoratedSliver(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: colors.outline),
              ),
              sliver: SliverPadding(
                padding: const EdgeInsets.fromLTRB(1, 1, 1, AppSpacing.space3),
                sliver: SliverMainAxisGroup(
                  slivers: [
                    for (final entry in groups.entries) ...[
                      SliverToBoxAdapter(
                        child: DateGroupHeader(
                          title: formatDateGroupTitle(entry.key),
                        ),
                      ),
                      SliverList.separated(
                        itemCount: entry.value.length,
                        itemBuilder: (context, index) =>
                            buildRow(context, entry.value[index]),
                        separatorBuilder: (context, _) => Divider(
                          height: 1,
                          indent: AppSpacing.space4 + 36 + AppSpacing.space3,
                          endIndent: AppSpacing.space4,
                          color: colors.outlineVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height:
                  AppSpacing.bottomNavClearance +
                  MediaQuery.paddingOf(context).bottom,
            ),
          ),
        ],
      ),
    );
  }

  Widget _swipeBackground({
    required bool isLeading,
    required String label,
    required IconData icon,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Container(
      color: backgroundColor,
      alignment: isLeading
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: foregroundColor),
            const SizedBox(width: AppSpacing.space2),
            Text(
              label,
              style: AppTypography.bodyMedium.copyWith(color: foregroundColor),
            ),
          ],
        ),
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
      width: 36,
      height: 36,
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
