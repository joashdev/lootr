import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/providers/accounts_provider.dart';
import '../../application/providers/categories_provider.dart';
import '../../application/providers/filtered_transactions_provider.dart';
import '../../application/providers/period_context_provider.dart';
import '../../application/providers/repo_providers.dart';
import '../../core/format/money_format.dart';
import '../../core/theme/spacing.dart';
import '../../data/repositories/composite_budget_repo.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/value_objects/exact_money.dart';
import '../shared/components/app_snackbar.dart';
import '../shared/components/sheet_handle.dart';

String _compositeBudgetId() {
  final random = Random();
  return 'budget-${List.generate(20, (_) => random.nextInt(16).toRadixString(16)).join()}';
}

class CompositeBudgetSheet extends ConsumerStatefulWidget {
  const CompositeBudgetSheet({super.key, this.budgetId});

  final String? budgetId;

  @override
  ConsumerState<CompositeBudgetSheet> createState() =>
      _CompositeBudgetSheetState();
}

class _CompositeBudgetSheetState extends ConsumerState<CompositeBudgetSheet> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _cycleController = TextEditingController();
  final Map<String, String> _accounts = {};
  final Map<String, String> _categories = {};
  final Map<String, String> _transactions = {};

  String _currency = 'PHP';
  String _periodType = 'monthly';
  String _direction = 'expense';
  String _membershipMode = 'all_matching';
  DateTime? _start;
  DateTime? _end;
  bool _loading = false;
  bool _saving = false;
  CompositeBudgetDraft? _loadedDraft;

  bool get _isEditing => widget.budgetId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    } else {
      final period = ref.read(periodContextProvider);
      _start = period.startsAt;
      _end = period.endsAt;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _cycleController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final draft = await ref
        .read(compositeBudgetRepoProvider)
        .getDraft(widget.budgetId!);
    if (!mounted) return;
    if (draft == null) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _loadedDraft = draft;
      _nameController.text = draft.name;
      _amountController.text = draft.limit.toDecimalString();
      _cycleController.text = draft.cycleRule ?? '';
      _currency = draft.limit.currencyCode;
      _periodType = draft.periodType;
      _direction = draft.directionFilter;
      _membershipMode = draft.membershipMode;
      _start = draft.periodStart;
      _end = draft.periodEnd;
      for (final id in draft.includedAccountIds) {
        _accounts[id] = 'include';
      }
      for (final id in draft.excludedAccountIds) {
        _accounts[id] = 'exclude';
      }
      for (final id in draft.includedCategoryIds) {
        _categories[id] = 'include';
      }
      for (final id in draft.excludedCategoryIds) {
        _categories[id] = 'exclude';
      }
      for (final id in draft.includedTransactionIds) {
        _transactions[id] = 'include';
      }
      for (final id in draft.excludedTransactionIds) {
        _transactions[id] = 'exclude';
      }
      _loading = false;
    });
  }

  Set<String> _ids(Map<String, String> values, String membership) => {
    for (final entry in values.entries)
      if (entry.value == membership) entry.key,
  };

  Future<void> _save() async {
    if (_saving) return;
    final user = await ref.read(userRepoProvider).getCurrentUser();
    final ownerId = _loadedDraft?.ownerUserId ?? user?.id;
    if (ownerId == null) {
      _error('Create a user profile before adding budgets.');
      return;
    }
    ExactMoney limit;
    try {
      limit = ExactMoney.parse(_amountController.text, _currency);
    } on FormatException {
      _error('Enter a valid budget amount.');
      return;
    }
    final draft = CompositeBudgetDraft(
      id: widget.budgetId ?? _compositeBudgetId(),
      ownerUserId: ownerId,
      householdId: _loadedDraft?.householdId,
      name: _nameController.text,
      limit: limit,
      periodType: _periodType,
      periodStart: _periodType == 'monthly' ? null : _start,
      periodEnd: _periodType == 'monthly' ? null : _end,
      cycleRule: _periodType == 'custom_cycle'
          ? _cycleController.text.trim()
          : null,
      directionFilter: _direction,
      membershipMode: _membershipMode,
      includedAccountIds: _ids(_accounts, 'include'),
      excludedAccountIds: _ids(_accounts, 'exclude'),
      includedCategoryIds: _ids(_categories, 'include'),
      excludedCategoryIds: _ids(_categories, 'exclude'),
      includedTransactionIds: _ids(_transactions, 'include'),
      excludedTransactionIds: _ids(_transactions, 'exclude'),
    );
    setState(() => _saving = true);
    try {
      final repo = ref.read(compositeBudgetRepoProvider);
      _isEditing ? await repo.update(draft) : await repo.create(draft);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      _error(error.toString().replaceFirst('Invalid argument(s): ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _error(String message) {
    AppSnackBar.show(context, message, variant: AppSnackBarVariant.warning);
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 10),
    );
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _pickEnd() async {
    final currentInclusive = _end?.subtract(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: currentInclusive ?? _start ?? DateTime.now(),
      firstDate: _start ?? DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 10),
    );
    if (picked != null) {
      setState(
        () => _end = DateTime(picked.year, picked.month, picked.day + 1),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts =
        ref.watch(accountsProvider).asData?.value ?? const <Account>[];
    final categories =
        ref.watch(categoriesProvider).asData?.value ?? const <Category>[];
    final transactions =
        ref.watch(filteredTransactionsProvider).asData?.value ??
        const <Transaction>[];
    final currencies = accounts.map((row) => row.currencyCode).toSet().toList()
      ..sort();
    if (!_isEditing &&
        currencies.isNotEmpty &&
        !currencies.contains(_currency)) {
      _currency = currencies.first;
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          children: [
            const SheetHandle(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sheetPaddingHorizontal,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEditing ? 'Edit composite budget' : 'New budget',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(
                    AppSpacing.sheetPaddingHorizontal,
                  ),
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Budget name',
                        hintText: 'e.g. Essentials',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space3),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Amount',
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.space2),
                        DropdownButton<String>(
                          value: _currency,
                          items: [
                            for (final code
                                in currencies.isEmpty
                                    ? <String>[_currency]
                                    : currencies)
                              DropdownMenuItem(value: code, child: Text(code)),
                          ],
                          onChanged: _isEditing
                              ? null
                              : (value) => setState(
                                  () => _currency = value ?? _currency,
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space3),
                    _dropdown(
                      label: 'Period',
                      value: _periodType,
                      values: const {
                        'monthly': 'Calendar month',
                        'date_range': 'Date range',
                        'custom_cycle': 'Custom cycle',
                      },
                      onChanged: (value) => setState(() {
                        _periodType = value;
                        _start ??= ref.read(periodContextProvider).startsAt;
                        _end ??= ref.read(periodContextProvider).endsAt;
                      }),
                    ),
                    if (_periodType != 'monthly') ...[
                      const SizedBox(height: AppSpacing.space2),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _pickStart,
                              child: Text(
                                _start == null
                                    ? 'Start date'
                                    : DateFormat.yMMMd().format(_start!),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.space2),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _pickEnd,
                              child: Text(
                                _end == null
                                    ? 'End date'
                                    : DateFormat.yMMMd().format(
                                        _end!.subtract(const Duration(days: 1)),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_periodType == 'custom_cycle') ...[
                      const SizedBox(height: AppSpacing.space2),
                      TextField(
                        controller: _cycleController,
                        decoration: const InputDecoration(
                          labelText: 'Cycle label or rule',
                          hintText: 'e.g. Pay cycle',
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.space3),
                    _dropdown(
                      label: 'Track',
                      value: _direction,
                      values: const {
                        'expense': 'Expenses',
                        'income': 'Income',
                        'both': 'Income and expenses',
                      },
                      onChanged: (value) => setState(() => _direction = value),
                    ),
                    const SizedBox(height: AppSpacing.space3),
                    _dropdown(
                      label: 'Membership',
                      value: _membershipMode,
                      values: const {
                        'all_matching': 'Matching scope + attached records',
                        'explicit_only': 'Attached records only',
                      },
                      onChanged: (value) =>
                          setState(() => _membershipMode = value),
                    ),
                    const SizedBox(height: AppSpacing.space4),
                    _membershipSection<Account>(
                      title: 'Accounts',
                      items: accounts
                          .where(
                            (row) =>
                                !row.isArchived &&
                                row.deletedAt == null &&
                                row.currencyCode == _currency,
                          )
                          .toList(),
                      idOf: (row) => row.id,
                      labelOf: (row) => '${row.name} · ${row.currencyCode}',
                      values: _accounts,
                    ),
                    _membershipSection<Category>(
                      title: 'Categories',
                      items: categories
                          .where((row) => row.deletedAt == null)
                          .toList(),
                      idOf: (row) => row.id,
                      labelOf: (row) => row.name,
                      values: _categories,
                    ),
                    _membershipSection<Transaction>(
                      title: 'Explicit transactions',
                      items: transactions,
                      idOf: (row) => row.id,
                      labelOf: (row) =>
                          '${row.title ?? row.note ?? 'Transaction'} · '
                          '${MoneyFormat.exactMoney(row.exactAmount)}',
                      values: _transactions,
                    ),
                    const SizedBox(height: AppSpacing.space4),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Saving…' : 'Save budget'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required Map<String, String> values,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final entry in values.entries)
          DropdownMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }

  Widget _membershipSection<T>({
    required String title,
    required List<T> items,
    required String Function(T) idOf,
    required String Function(T) labelOf,
    required Map<String, String> values,
  }) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(
        '${values.values.where((value) => value == 'include').length} included · '
        '${values.values.where((value) => value == 'exclude').length} excluded',
      ),
      children: [
        if (items.isEmpty)
          const ListTile(title: Text('No available records'))
        else
          for (final item in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(labelOf(item)),
              trailing: DropdownButton<String>(
                value: values[idOf(item)] ?? 'ignore',
                items: const [
                  DropdownMenuItem(value: 'ignore', child: Text('Ignore')),
                  DropdownMenuItem(value: 'include', child: Text('Include')),
                  DropdownMenuItem(value: 'exclude', child: Text('Exclude')),
                ],
                onChanged: (value) => setState(() {
                  if (value == null || value == 'ignore') {
                    values.remove(idOf(item));
                  } else {
                    values[idOf(item)] = value;
                  }
                }),
              ),
            ),
      ],
    );
  }
}
