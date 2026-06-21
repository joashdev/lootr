import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../application/providers/accounts_provider.dart';
import '../../application/providers/categories_provider.dart';
import '../../application/providers/payees_provider.dart';
import '../../application/providers/repo_providers.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/payee.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transfer.dart';
import '../../domain/use_cases/add_transaction.dart';
import '../../domain/use_cases/create_transfer.dart';
import '../../domain/use_cases/edit_transaction.dart';
import '../../domain/use_cases/edit_transfer.dart';

class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({
    super.key,
    this.initialTransaction,
    this.initialTransfer,
  });

  final Transaction? initialTransaction;
  final Transfer? initialTransfer;

  @override
  ConsumerState<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _feeController = TextEditingController();
  final _noteController = TextEditingController();

  String? _accountId;
  String? _categoryId;
  String? _payeeId;
  String? _sourceAccountId;
  String? _destinationAccountId;
  late String _direction;
  late DateTime _occurredAt;
  bool _isSaving = false;

  bool get _isTransactionEditing => widget.initialTransaction != null;
  bool get _isTransferEditing => widget.initialTransfer != null;

  @override
  void initState() {
    super.initState();
    final initialTransaction = widget.initialTransaction;
    final initialTransfer = widget.initialTransfer;

    _direction = initialTransaction?.direction == 'income' ? 'income' : 'expense';
    _occurredAt =
        initialTransaction?.occurredAt ?? initialTransfer?.occurredAt ?? DateTime.now();
    _accountId = initialTransaction?.accountId;
    _categoryId = initialTransaction?.categoryId;
    _payeeId = initialTransaction?.payeeId;
    _sourceAccountId = initialTransfer?.sourceAccountId;
    _destinationAccountId = initialTransfer?.destinationAccountId;
    _amountController.text = initialTransaction != null
        ? initialTransaction.amount.toStringAsFixed(2)
        : initialTransfer != null
            ? initialTransfer.amount.toStringAsFixed(2)
            : '';
    _feeController.text = initialTransfer == null
        ? ''
        : initialTransfer.feeAmount == 0
            ? ''
            : initialTransfer.feeAmount.toStringAsFixed(2);
    _noteController.text = initialTransaction?.note ?? initialTransfer?.note ?? '';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _feeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;

    setState(() {
      _occurredAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _occurredAt.hour,
        _occurredAt.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (picked == null) return;

    setState(() {
      _occurredAt = DateTime(
        _occurredAt.year,
        _occurredAt.month,
        _occurredAt.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  String? _normalizeOptionalText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _modeLabel(String mode) {
    switch (mode) {
      case 'one_time':
        return 'One-time';
      case 'recurring':
        return 'Recurring';
      case 'installment':
        return 'Installment';
      case 'debt':
        return 'Debt';
      default:
        return mode;
    }
  }

  Future<void> _saveTransaction() async {
    if (_isSaving) return;
    if (_formKey.currentState?.validate() != true) return;
    if (_accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an account to continue.')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final transactionRepo = ref.read(transactionRepoProvider);
    final accountRepo = ref.read(accountRepoProvider);
    final note = _normalizeOptionalText(_noteController.text);
    final now = DateTime.now();

    if (_isTransactionEditing) {
      final initial = widget.initialTransaction!;
      final updated = initial.copyWith(
        accountId: _accountId,
        categoryId: () => _categoryId,
        payeeId: () => _payeeId,
        amount: amount,
        direction: _direction,
        note: () => note,
        occurredAt: _occurredAt,
        updatedAt: now,
      );

      final result = await EditTransaction(transactionRepo, accountRepo).call(updated);
      if (!mounted) return;

      result.fold(
        onSuccess: (_) => context.pop(),
        onFailure: (message, _) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        },
      );
    } else {
      final transaction = Transaction(
        id: 'txn-${DateTime.now().microsecondsSinceEpoch}',
        accountId: _accountId!,
        categoryId: _categoryId,
        payeeId: _payeeId,
        amount: amount,
        direction: _direction,
        mode: 'one_time',
        note: note,
        occurredAt: _occurredAt,
        createdAt: now,
        updatedAt: now,
      );

      final result = await AddTransaction(transactionRepo, accountRepo).call(transaction);
      if (!mounted) return;

      result.fold(
        onSuccess: (_) => context.pop(),
        onFailure: (message, _) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        },
      );
    }

    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _saveTransfer() async {
    if (_isSaving) return;
    if (_formKey.currentState?.validate() != true) return;
    if (_sourceAccountId == null || _destinationAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select both source and destination accounts.'),
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    final feeAmount = _feeController.text.trim().isEmpty
        ? 0.0
        : double.tryParse(_feeController.text.trim());
    if (amount == null || feeAmount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid transfer amounts.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final note = _normalizeOptionalText(_noteController.text);
    final accountRepo = ref.read(accountRepoProvider);
    final transferRepo = ref.read(transferRepoProvider);
    final now = DateTime.now();
    final transfer = Transfer(
      id: widget.initialTransfer?.id ?? 'xfer-${DateTime.now().microsecondsSinceEpoch}',
      sourceAccountId: _sourceAccountId!,
      destinationAccountId: _destinationAccountId!,
      amount: amount,
      feeAmount: feeAmount,
      note: note,
      occurredAt: _occurredAt,
      createdAt: widget.initialTransfer?.createdAt ?? now,
      updatedAt: now,
    );

    final result = _isTransferEditing
        ? await EditTransfer(transferRepo, accountRepo).call(transfer)
        : await CreateTransfer(transferRepo, accountRepo).call(transfer);

    if (!mounted) return;

    result.fold(
      onSuccess: (_) => context.pop(),
      onFailure: (message, _) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      },
    );

    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final payeesAsync = ref.watch(payeesProvider);

    final accounts = accountsAsync is AsyncData<List<Account>>
        ? accountsAsync.value
        : const <Account>[];
    final categories = categoriesAsync is AsyncData<List<Category>>
        ? categoriesAsync.value
        : const <Category>[];
    final payees = payeesAsync is AsyncData<List<Payee>>
        ? payeesAsync.value
        : const <Payee>[];

    return SafeArea(
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _isTransferEditing
                          ? 'Edit Transfer'
                          : _isTransactionEditing
                              ? 'Edit Transaction'
                              : 'Add Transaction',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (_isTransactionEditing) ...[
                const SizedBox(height: 4),
                Text(
                  'Mode: ${_modeLabel(widget.initialTransaction!.mode)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: _isTransferEditing
                    ? _buildTransferForm(accounts)
                    : _buildTransactionForm(accounts, categories, payees),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionForm(
    List<Account> accounts,
    List<Category> categories,
    List<Payee> payees,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'expense',
              label: Text('Expense'),
              icon: Icon(Icons.arrow_upward),
            ),
            ButtonSegment(
              value: 'income',
              label: Text('Income'),
              icon: Icon(Icons.arrow_downward),
            ),
          ],
          selected: {_direction},
          onSelectionChanged: (selection) {
            setState(() => _direction = selection.first);
          },
        ),
        const SizedBox(height: 16),
        _amountField(),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey('account-${_accountId ?? 'none'}-${accounts.length}'),
          initialValue: accounts.any((account) => account.id == _accountId)
              ? _accountId
              : null,
          decoration: const InputDecoration(labelText: 'Account'),
          items: [
            for (final account in accounts)
              DropdownMenuItem<String>(
                value: account.id,
                child: Text(account.name),
              ),
          ],
          onChanged: accounts.isEmpty ? null : (value) => setState(() => _accountId = value),
          validator: (value) => value == null ? 'Select an account' : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String?>(
          key: ValueKey('category-${_categoryId ?? 'none'}-${categories.length}'),
          initialValue: categories.any((category) => category.id == _categoryId)
              ? _categoryId
              : null,
          decoration: const InputDecoration(labelText: 'Category'),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('No category'),
            ),
            for (final category in categories)
              DropdownMenuItem<String?>(
                value: category.id,
                child: Text(category.name),
              ),
          ],
          onChanged: (value) => setState(() => _categoryId = value),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String?>(
          key: ValueKey('payee-${_payeeId ?? 'none'}-${payees.length}'),
          initialValue:
              payees.any((payee) => payee.id == _payeeId) ? _payeeId : null,
          decoration: const InputDecoration(labelText: 'Payee'),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('No payee'),
            ),
            for (final payee in payees)
              DropdownMenuItem<String?>(
                value: payee.id,
                child: Text(
                  payee.displayName?.isNotEmpty == true
                      ? payee.displayName!
                      : payee.normalizedName,
                ),
              ),
          ],
          onChanged: (value) => setState(() => _payeeId = value),
        ),
        const SizedBox(height: 16),
        _noteField(),
        const SizedBox(height: 16),
        _dateTimeSection(),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isSaving ? null : _saveTransaction,
            child: Text(
              _isSaving
                  ? 'Saving...'
                  : _isTransactionEditing
                      ? 'Save Changes'
                      : 'Add Transaction',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransferForm(List<Account> accounts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _amountField(labelText: 'Transfer Amount'),
        const SizedBox(height: 16),
        TextFormField(
          controller: _feeController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Fee',
            prefixText: 'PHP ',
          ),
          validator: (value) {
            if ((value ?? '').trim().isEmpty) return null;
            final parsed = double.tryParse(value!.trim());
            if (parsed == null || parsed < 0) {
              return 'Enter a valid fee';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey('source-${_sourceAccountId ?? 'none'}-${accounts.length}'),
          initialValue:
              accounts.any((account) => account.id == _sourceAccountId) ? _sourceAccountId : null,
          decoration: const InputDecoration(labelText: 'From account'),
          items: [
            for (final account in accounts)
              DropdownMenuItem<String>(
                value: account.id,
                child: Text(account.name),
              ),
          ],
          onChanged: accounts.isEmpty
              ? null
              : (value) => setState(() => _sourceAccountId = value),
          validator: (value) => value == null ? 'Select a source account' : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey('destination-${_destinationAccountId ?? 'none'}-${accounts.length}'),
          initialValue: accounts.any((account) => account.id == _destinationAccountId)
              ? _destinationAccountId
              : null,
          decoration: const InputDecoration(labelText: 'To account'),
          items: [
            for (final account in accounts)
              DropdownMenuItem<String>(
                value: account.id,
                child: Text(account.name),
              ),
          ],
          onChanged: accounts.isEmpty
              ? null
              : (value) => setState(() => _destinationAccountId = value),
          validator: (value) => value == null ? 'Select a destination account' : null,
        ),
        const SizedBox(height: 16),
        _noteField(hintText: 'Optional transfer note'),
        const SizedBox(height: 16),
        _dateTimeSection(),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isSaving ? null : _saveTransfer,
            child: Text(_isSaving ? 'Saving...' : 'Save Transfer'),
          ),
        ),
      ],
    );
  }

  Widget _amountField({String labelText = 'Amount'}) {
    return TextFormField(
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: labelText,
        prefixText: 'PHP ',
      ),
      validator: (value) {
        final parsed = double.tryParse((value ?? '').trim());
        if (parsed == null || parsed <= 0) {
          return 'Enter an amount greater than zero';
        }
        return null;
      },
    );
  }

  Widget _noteField({String hintText = 'Optional note'}) {
    return TextFormField(
      controller: _noteController,
      minLines: 2,
      maxLines: 4,
      decoration: InputDecoration(
        labelText: 'Note',
        hintText: hintText,
      ),
    );
  }

  Widget _dateTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date & time',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(DateFormat('MMM d, yyyy').format(_occurredAt)),
            ),
            OutlinedButton.icon(
              onPressed: _pickTime,
              icon: const Icon(Icons.access_time),
              label: Text(DateFormat('h:mm a').format(_occurredAt)),
            ),
          ],
        ),
      ],
    );
  }
}
