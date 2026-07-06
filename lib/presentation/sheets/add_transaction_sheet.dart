import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../application/providers/accounts_provider.dart';
import '../../application/providers/categories_provider.dart';
import '../../application/providers/debts_provider.dart';
import '../../application/providers/filtered_transactions_provider.dart';
import '../../application/providers/payees_provider.dart';
import '../../application/providers/repo_providers.dart';
import '../../application/providers/undo_stack_provider.dart';
import '../../core/constants/enums.dart' as ui;
import '../../core/format/money_format.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/typography.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/debt_record.dart';
import '../../domain/entities/mappers.dart';
import '../../domain/entities/payee.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transfer.dart';
import '../../domain/use_cases/add_transaction.dart';
import '../../domain/use_cases/create_transfer.dart';
import '../../domain/use_cases/edit_transaction.dart';
import '../../domain/use_cases/edit_transfer.dart';
import '../../domain/use_cases/parse_nl.dart';
import '../../domain/value_objects/field_types.dart' as fields;
import '../../domain/value_objects/parsed_transaction.dart';
import '../../domain/value_objects/undo_entry.dart';
import '../shared/components/buttons/primary_button.dart';
import '../shared/components/app_snackbar.dart';
import '../shared/components/inputs/account_dropdown.dart';
import '../shared/components/inputs/amount_input.dart';
import '../shared/components/inputs/category_autocomplete.dart';
import '../shared/components/inputs/payee_autocomplete.dart';

/// Arguments accepted by the `/transactions/new` route. Allows callers (such as
/// the OCR scan flow or the Quick Add island) to open the sheet straight into
/// quick mode or seeded with parsed/edit data.
class AddTransactionSheetArgs {
  const AddTransactionSheetArgs({
    this.initialTransaction,
    this.initialTransfer,
    this.startInQuickMode = false,
    this.initialParsedTransaction,
    this.initialQuickText,
  });

  final Transaction? initialTransaction;
  final Transfer? initialTransfer;
  final bool startInQuickMode;
  final ParsedTransaction? initialParsedTransaction;
  final String? initialQuickText;
}

class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({
    super.key,
    this.initialTransaction,
    this.initialTransfer,
    this.startInQuickMode = false,
    this.initialParsedTransaction,
    this.initialQuickText,
  });

  final Transaction? initialTransaction;
  final Transfer? initialTransfer;
  final bool startInQuickMode;
  final ParsedTransaction? initialParsedTransaction;
  final String? initialQuickText;

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _feeController = TextEditingController();
  final _noteController = TextEditingController();
  final _quickAddController = TextEditingController();
  final SpeechToText _speech = SpeechToText();

  String? _accountId;
  String? _categoryId;
  String? _payeeId;
  String? _sourceAccountId;
  String? _destinationAccountId;
  String? _parentTransactionId;
  String? _debtRecordId;
  String _payeeDraft = '';
  String? _categoryDraft;
  String _recurrenceRule = 'monthly';
  late String _direction;
  late String _mode;
  late DateTime _occurredAt;

  bool _isQuickMode = false;
  bool _isSaving = false;
  bool _seededInitialParsed = false;
  bool _isListening = false;

  ParsedTransaction? _parsedPreview;
  String? _parseError;

  bool get _isTransactionEditing => widget.initialTransaction != null;
  bool get _isTransferEditing => widget.initialTransfer != null;

  @override
  void dispose() {
    _speech.cancel();
    _amountController.dispose();
    _feeController.dispose();
    _noteController.dispose();
    _quickAddController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final initialTransaction = widget.initialTransaction;
    final initialTransfer = widget.initialTransfer;

    _isQuickMode =
        widget.startInQuickMode &&
        !_isTransactionEditing &&
        !_isTransferEditing;
    if ((widget.initialQuickText ?? '').trim().isNotEmpty) {
      _quickAddController.text = widget.initialQuickText!.trim();
    }

    _direction =
        initialTransaction?.direction == fields.TransactionDirection.income
        ? fields.TransactionDirection.income
        : fields.TransactionDirection.expense;
    _mode = initialTransaction?.mode ?? fields.TransactionMode.oneTime;
    _occurredAt =
        initialTransaction?.occurredAt ??
        initialTransfer?.occurredAt ??
        DateTime.now();
    _accountId = initialTransaction?.accountId;
    _categoryId = initialTransaction?.categoryId;
    _payeeId = initialTransaction?.payeeId;
    _parentTransactionId = initialTransaction?.parentTransactionId;
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
    _noteController.text =
        initialTransaction?.note ?? initialTransfer?.note ?? '';

    final metadata = initialTransaction?.metadata ?? const <String, dynamic>{};
    _recurrenceRule = metadata['recurrenceRule'] as String? ?? _recurrenceRule;
    _debtRecordId = metadata['debtRecordId'] as String?;
  }

  Future<void> _toggleSpeechInput() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) {
        setState(() => _isListening = false);
      }
      return;
    }

    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _isListening = false);
        _showSnackBar('Voice input could not start on this device.');
      },
    );

    if (!available) {
      _showSnackBar('Voice input is unavailable on this device.');
      return;
    }

    setState(() => _isListening = true);
    await _speech.listen(
      listenMode: ListenMode.dictation,
      partialResults: true,
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _quickAddController.text = result.recognizedWords.trim();
          _quickAddController.selection = TextSelection.collapsed(
            offset: _quickAddController.text.length,
          );
        });
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String? _normalizeOptionalText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  ui.TransactionDirection _amountDirection() {
    return _direction == fields.TransactionDirection.income
        ? ui.TransactionDirection.income
        : ui.TransactionDirection.expense;
  }

  String _directionLabel(String value) {
    switch (value) {
      case fields.TransactionDirection.income:
        return 'Income';
      case fields.TransactionDirection.transfer:
        return 'Transfer';
      default:
        return 'Expense';
    }
  }

  String _modeLabel(String mode) {
    switch (mode) {
      case fields.TransactionMode.oneTime:
        return 'One-time';
      case fields.TransactionMode.recurring:
        return 'Recurring';
      case fields.TransactionMode.installment:
        return 'Installment';
      case fields.TransactionMode.debt:
        return 'Debt';
      default:
        return mode;
    }
  }

  String? _matchAccountId(String label, List<Account> accounts) {
    final normalized = _normalize(label);
    final exactMatch = accounts.cast<Account?>().firstWhere(
      (account) => _normalize(account!.name) == normalized,
      orElse: () => null,
    );
    if (exactMatch != null) return exactMatch.id;
    final fuzzyMatch = accounts.cast<Account?>().firstWhere(
      (account) => _normalize(account!.name).contains(normalized),
      orElse: () => null,
    );
    return fuzzyMatch?.id;
  }

  String? _matchCategoryId(
    String label,
    List<Category> categories, {
    String? direction,
  }) {
    final normalized = _normalize(label);
    if (normalized.isEmpty) return null;
    final group = (direction ?? _direction) == fields.TransactionDirection.income
        ? fields.CategoryGroup.income
        : fields.CategoryGroup.expense;
    final candidates = categories
        .where(
          (category) =>
              category.deletedAt == null && category.categoryGroup == group,
        )
        .toList();
    final exact = candidates.cast<Category?>().firstWhere(
      (category) => _normalize(category!.name) == normalized,
      orElse: () => null,
    );
    if (exact != null) return exact.id;
    // Fuzzy fallback: NL quick-add emits short labels ("Dining") that
    // otherwise match no real category ("Food & Dining") and would save
    // the transaction uncategorized.
    final fuzzy = candidates.cast<Category?>().firstWhere((category) {
      final name = _normalize(category!.name);
      return name.contains(normalized) || normalized.contains(name);
    }, orElse: () => null);
    return fuzzy?.id;
  }

  String? _matchPayeeId(String label, List<Payee> payees) {
    final normalized = _normalize(label);
    final match = payees.cast<Payee?>().firstWhere((payee) {
      final displayName = payee!.displayName ?? payee.normalizedName;
      return _normalize(displayName) == normalized;
    }, orElse: () => null);
    return match?.id;
  }

  void _seedFromParsedTransaction(
    ParsedTransaction parsed,
    List<Account> accounts,
    List<Category> categories,
    List<Payee> payees,
  ) {
    if (parsed.amount != null) {
      _amountController.text = parsed.amount!.toStringAsFixed(2);
    }
    if (parsed.direction != null) {
      _direction = parsed.direction!;
    }
    if (parsed.account != null) {
      _accountId = _matchAccountId(parsed.account!, accounts);
    }
    if (parsed.category != null) {
      _categoryId = _matchCategoryId(parsed.category!, categories);
      // Keep the raw label only when unresolved, so a matched category
      // displays its real name (icon + name) instead of the parsed alias.
      _categoryDraft = _categoryId == null ? parsed.category : null;
    }
    if (parsed.payee != null) {
      _payeeId = _matchPayeeId(parsed.payee!, payees);
      _payeeDraft = parsed.payee!;
    }
    if (parsed.note != null && _noteController.text.trim().isEmpty) {
      _noteController.text = parsed.note!;
    }
    _parsedPreview = parsed;
  }

  void _ensureSeededFromInitialParsed(
    List<Account> accounts,
    List<Category> categories,
    List<Payee> payees,
  ) {
    if (_seededInitialParsed || widget.initialParsedTransaction == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _seededInitialParsed) return;
      setState(() {
        _seededInitialParsed = true;
        _seedFromParsedTransaction(
          widget.initialParsedTransaction!,
          accounts,
          categories,
          payees,
        );
      });
    });
  }

  void _ensureQuickTextParsed(List<Account> accounts, List<Payee> payees) {
    if (_seededInitialParsed || _quickAddController.text.trim().isEmpty) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _seededInitialParsed) return;
      _seededInitialParsed = true;
      _runQuickAdd(accounts, payees);
    });
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

  // ---------------------------------------------------------------------------
  // Save flows
  // ---------------------------------------------------------------------------

  Map<String, dynamic>? _buildMetadata() {
    final metadata = <String, dynamic>{};
    if (_mode == fields.TransactionMode.recurring) {
      metadata['recurrenceRule'] = _recurrenceRule;
    }
    if (_mode == fields.TransactionMode.debt && _debtRecordId != null) {
      metadata['debtRecordId'] = _debtRecordId;
    }
    if (_parsedPreview != null) {
      metadata['source'] = 'quick_add';
    }
    return metadata.isEmpty ? null : metadata;
  }

  Future<String?> _resolvePayeeId() async {
    if (_payeeId != null) return _payeeId;
    final payeeName = _payeeDraft.trim();
    if (payeeName.isEmpty) return null;
    final payee = await ref
        .read(payeeRepoProvider)
        .createOrGet(_normalize(payeeName));
    return payee.id;
  }

  Future<void> _saveTransaction() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showSnackBar('Enter a valid amount.');
      return;
    }
    if (_accountId == null) {
      _showSnackBar('Select an account to continue.');
      return;
    }

    setState(() => _isSaving = true);

    final transactionRepo = ref.read(transactionRepoProvider);
    final accountRepo = ref.read(accountRepoProvider);
    final note = _normalizeOptionalText(_noteController.text);
    final now = DateTime.now();

    try {
      final payeeId = await _resolvePayeeId();
      final previous = widget.initialTransaction;
      // Fall back to resolving free-typed category text (e.g. an NL
      // quick-add label that was never tapped in the picker) at save time.
      final categoryId =
          _categoryId ??
          _matchCategoryId(
            _categoryDraft ?? '',
            ref.read(categoriesProvider).asData?.value ?? const <Category>[],
          );

      final transaction = Transaction(
        id: previous?.id ?? 'txn-${now.microsecondsSinceEpoch}',
        accountId: _accountId!,
        categoryId: categoryId,
        payeeId: payeeId,
        parentTransactionId: _mode == fields.TransactionMode.installment
            ? _parentTransactionId
            : null,
        recurringTemplateId: previous?.recurringTemplateId,
        amount: amount,
        direction: _direction,
        mode: _mode,
        subtype: previous?.subtype,
        note: note,
        metadata: _buildMetadata(),
        occurredAt: _occurredAt,
        createdAt: previous?.createdAt ?? now,
        updatedAt: now,
        deletedAt: previous?.deletedAt,
      );

      if (_isTransactionEditing) {
        final result = await EditTransaction(
          transactionRepo,
          accountRepo,
        ).call(transaction);
        if (!mounted) return;
        result.fold(
          onSuccess: (_) => _handleSaveSuccess(
            transaction.id,
            isEdit: true,
            previousTransaction: previous,
          ),
          onFailure: (message, _) => _showSnackBar(message),
        );
      } else {
        final result = await AddTransaction(
          transactionRepo,
          accountRepo,
        ).call(transaction);
        if (!mounted) return;
        result.fold(
          onSuccess: (transactionId) =>
              _handleSaveSuccess(transactionId, isEdit: false),
          onFailure: (message, _) => _showSnackBar(message),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveTransfer() async {
    if (_isSaving) return;
    if (_formKey.currentState?.validate() != true) return;
    if (_sourceAccountId == null || _destinationAccountId == null) {
      _showSnackBar('Select both source and destination accounts.');
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    final feeAmount = _feeController.text.trim().isEmpty
        ? 0.0
        : double.tryParse(_feeController.text.trim());
    if (amount == null || amount <= 0 || feeAmount == null || feeAmount < 0) {
      _showSnackBar('Enter valid transfer amounts.');
      return;
    }

    setState(() => _isSaving = true);

    final note = _normalizeOptionalText(_noteController.text);
    final accountRepo = ref.read(accountRepoProvider);
    final transferRepo = ref.read(transferRepoProvider);
    final now = DateTime.now();
    final transfer = Transfer(
      id: widget.initialTransfer?.id ?? 'xfer-${now.microsecondsSinceEpoch}',
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
      onFailure: (message, _) => _showSnackBar(message),
    );

    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  void _handleSaveSuccess(
    String transactionId, {
    required bool isEdit,
    Transaction? previousTransaction,
  }) {
    final message = isEdit ? 'Transaction updated' : 'Transaction saved';

    ref
        .read(undoStackProvider.notifier)
        .push(
          UndoEntry(
            transactionId: transactionId,
            message: message,
            rollback: () async {
              if (isEdit && previousTransaction != null) {
                await ref
                    .read(transactionRepoProvider)
                    .update(previousTransaction.toUpdateCompanion());
                return;
              }
              await ref.read(transactionRepoProvider).softDelete(transactionId);
            },
            createdAt: DateTime.now(),
          ),
        );

    _showSnackBar(message, transactionId: transactionId);
    if (mounted) context.pop();
  }

  void _showSnackBar(String message, {String? transactionId}) {
    final isError = switch (message) {
      'Enter a valid amount.' ||
      'Select an account to continue.' ||
      'Select both source and destination accounts.' ||
      'Enter valid transfer amounts.' => true,
      _ => false,
    };
    AppSnackBar.show(
      context,
      message,
      variant: isError
          ? AppSnackBarVariant.warning
          : AppSnackBarVariant.success,
      actionLabel: transactionId != null ? 'UNDO' : null,
      onAction: transactionId != null
          ? () => ref.read(undoStackProvider.notifier).undo(transactionId)
          : null,
      duration: const Duration(seconds: 4),
    );
  }

  Future<void> _runQuickAdd(List<Account> accounts, List<Payee> payees) async {
    final input = _quickAddController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _parsedPreview = null;
        _parseError = null;
      });
      return;
    }

    final parser = ParseNL(
      knownPayees: payees
          .map<String>((payee) => payee.displayName ?? payee.normalizedName)
          .toList(),
      knownAccounts: accounts.map((account) => account.name).toList(),
    );

    final result = parser(input);
    setState(() {
      result.fold(
        onSuccess: (parsed) {
          _parsedPreview = parsed;
          _parseError = null;
        },
        onFailure: (message, _) {
          _parsedPreview = null;
          _parseError = message;
        },
      );
    });
  }

  void _applyPreviewToManual(
    ParsedTransaction parsed,
    List<Account> accounts,
    List<Category> categories,
    List<Payee> payees,
  ) {
    setState(() {
      _seedFromParsedTransaction(parsed, accounts, categories, payees);
      _isQuickMode = false;
    });
  }

  void _openScan() {
    final router = GoRouter.of(context);
    context.pop();
    router.push('/scan');
  }

  void _handleEntryModeSelected(EntryMode mode) {
    switch (mode) {
      case EntryMode.quick:
        setState(() => _isQuickMode = true);
      case EntryMode.manual:
        setState(() => _isQuickMode = false);
      case EntryMode.scan:
        _openScan();
    }
  }

  void _openAccounts() {
    final router = GoRouter.of(context);
    context.pop();
    router.push('/more/accounts');
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final accounts =
        (ref.watch(accountsProvider).asData?.value ?? const <Account>[])
            .where(
              (account) => account.deletedAt == null && !account.isArchived,
            )
            .toList()
          ..sort((left, right) => left.name.compareTo(right.name));
    final categories =
        ref.watch(categoriesProvider).asData?.value ?? const <Category>[];
    final payees = ref.watch(payeesProvider).asData?.value ?? const <Payee>[];
    final debts =
        ref.watch(debtsProvider).asData?.value ?? const <DebtRecord>[];
    final parentTransactions =
        ref.watch(filteredTransactionsProvider).asData?.value ??
        const <Transaction>[];

    _ensureSeededFromInitialParsed(accounts, categories, payees);
    _ensureQuickTextParsed(accounts, payees);

    final title = _isTransferEditing
        ? 'Edit Transfer'
        : _isTransactionEditing
        ? 'Edit Transaction'
        : 'Add Transaction';
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Material(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (_isTransactionEditing) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Mode: ${_modeLabel(widget.initialTransaction!.mode)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (!_isTransactionEditing && !_isTransferEditing)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                child: EntryModeTabs(
                  selected: _isQuickMode ? EntryMode.quick : EntryMode.manual,
                  onSelected: _handleEntryModeSelected,
                ),
              ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: _isTransferEditing
                      ? _buildTransferEntryForm(accounts)
                      : (_isQuickMode && !_isTransactionEditing)
                      ? _buildQuickAdd(accounts, categories, payees)
                      : _direction == fields.TransactionDirection.transfer
                      ? _buildTransferEntryForm(accounts)
                      : _buildTransactionForm(
                          accounts,
                          categories,
                          payees,
                          debts,
                          parentTransactions,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferEntryForm(List<Account> accounts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_isTransferEditing) ...[
          _buildTransactionTypeTabs(),
          const SizedBox(height: 16),
        ],
        _buildTransferForm(accounts),
      ],
    );
  }

  Widget _buildTransactionForm(
    List<Account> accounts,
    List<Category> categories,
    List<Payee> payees,
    List<DebtRecord> debts,
    List<Transaction> parentTransactions,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTransactionTypeTabs(),
        const SizedBox(height: 16),
        AmountInput(
          direction: _amountDirection(),
          controller: _amountController,
          label: 'Amount',
        ),
        const SizedBox(height: 16),
        _buildLabel('Account'),
        const SizedBox(height: 8),
        AccountDropdown(
          accounts: accounts,
          selectedAccountId: _accountId,
          onChanged: (value) => setState(() => _accountId = value),
        ),
        if (accounts.isEmpty) ...[
          const SizedBox(height: 12),
          _buildNoAccountsPrompt(),
        ] else ...[
          const SizedBox(height: 16),
          _buildLabel('Category'),
          const SizedBox(height: 8),
          CategoryAutocomplete(
            categories: categories,
            selectedCategoryId: _categoryId,
            groupFilter: _direction == fields.TransactionDirection.income
                ? fields.CategoryGroup.income
                : fields.CategoryGroup.expense,
            initialText: _categoryDraft,
            onChanged: (value) => setState(() {
              _categoryId = value;
              // A concrete pick supersedes any free-typed draft label.
              if (value != null) _categoryDraft = null;
            }),
            onTextChanged: (value) => _categoryDraft = value,
          ),
          const SizedBox(height: 16),
          _buildLabel('Payee'),
          const SizedBox(height: 8),
          PayeeAutocomplete(
            payees: payees,
            selectedPayeeId: _payeeId,
            initialText: _payeeDraft.isEmpty ? null : _payeeDraft,
            onChanged: (value) => setState(() => _payeeId = value),
            onTextChanged: (value) => _payeeDraft = value,
          ),
          const SizedBox(height: 16),
          _noteField(),
          const SizedBox(height: 16),
          _dateTimeSection(),
          const SizedBox(height: 16),
          _buildLabel('Transaction Mode'),
          const SizedBox(height: 8),
          _buildTransactionModeToggle(),
          if (_mode == fields.TransactionMode.recurring) ...[
            const SizedBox(height: 16),
            _buildRecurrencePicker(),
          ],
          if (_mode == fields.TransactionMode.installment) ...[
            const SizedBox(height: 16),
            _buildParentTransactionPicker(parentTransactions),
          ],
          if (_mode == fields.TransactionMode.debt) ...[
            const SizedBox(height: 16),
            _buildDebtPicker(debts),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: _isTransactionEditing ? 'Save Changes' : 'Add Transaction',
              onPressed: _isSaving ? null : _saveTransaction,
              isLoading: _isSaving,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickAdd(
    List<Account> accounts,
    List<Category> categories,
    List<Payee> payees,
  ) {
    final lootrColors = context.lootrColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _quickAddController,
          decoration: InputDecoration(
            hintText: 'Describe your transaction...',
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: _isListening ? 'Stop listening' : 'Start voice input',
                  onPressed: _toggleSpeechInput,
                  icon: Icon(
                    _isListening ? LucideIcons.audioLines : LucideIcons.mic,
                    size: 18,
                    color: _isListening
                        ? Theme.of(context).colorScheme.primary
                        : lootrColors.textTertiary,
                  ),
                ),
                IconButton(
                  tooltip: 'Parse',
                  onPressed: () => _runQuickAdd(accounts, payees),
                  icon: const Icon(LucideIcons.arrowRight, size: 18),
                ),
              ],
            ),
          ),
          onSubmitted: (_) => _runQuickAdd(accounts, payees),
        ),
        const SizedBox(height: 8),
        Text(
          'Example: "mcdo 250 gcash"',
          style: AppTypography.caption.copyWith(
            color: lootrColors.textSecondary,
          ),
        ),
        if (_parseError != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: lootrColors.warningBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              _parseError!,
              style: AppTypography.caption.copyWith(color: lootrColors.warning),
            ),
          ),
        ],
        if (_parsedPreview != null) ...[
          const SizedBox(height: 16),
          _buildPreviewCard(_parsedPreview!, categories),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Add Transaction',
            onPressed: _isSaving
                ? null
                : () {
                    _applyPreviewToManual(
                      _parsedPreview!,
                      accounts,
                      categories,
                      payees,
                    );
                    _saveTransaction();
                  },
            isLoading: _isSaving,
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => _applyPreviewToManual(
                _parsedPreview!,
                accounts,
                categories,
                payees,
              ),
              child: const Text('Edit manually'),
            ),
          ),
        ],
      ],
    );
  }

  /// Resolves the parsed category label against the user's real categories.
  /// Falls back to "Uncategorized" when nothing matches, so the preview never
  /// shows a category that would silently disappear on save.
  String _previewCategoryLabel(
    ParsedTransaction parsed,
    List<Category> categories,
  ) {
    final matchedId = _matchCategoryId(
      parsed.category!,
      categories,
      direction: parsed.direction,
    );
    if (matchedId == null) return 'Uncategorized';
    return categories.firstWhere((category) => category.id == matchedId).name;
  }

  Widget _buildPreviewCard(ParsedTransaction parsed, List<Category> categories) {
    final lootrColors = context.lootrColors;
    // The parser produces a single overall confidence, so it is surfaced once
    // below the rows rather than repeated per field.
    final confidence = parsed.confidence;

    Widget previewRow(String label, String value) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: lootrColors.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: AppTypography.body.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preview',
            style: AppTypography.captionMedium.copyWith(
              color: lootrColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          if (parsed.amount != null)
            previewRow('Amount', MoneyFormat.exact(parsed.amount!, 'PHP')),
          if (parsed.payee != null) previewRow('Payee', parsed.payee!),
          if (parsed.account != null) previewRow('Account', parsed.account!),
          if (parsed.category != null)
            previewRow('Category', _previewCategoryLabel(parsed, categories)),
          if (parsed.direction != null)
            previewRow('Direction', _directionLabel(parsed.direction!)),
          Row(
            children: [
              _ConfidenceDot(confidence: confidence),
              const SizedBox(width: 8),
              Text(
                'Confidence ${(confidence * 100).toStringAsFixed(0)}%',
                style: AppTypography.caption.copyWith(
                  color: lootrColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionModeToggle() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ModePill(
          label: 'One-time',
          isSelected: _mode == fields.TransactionMode.oneTime,
          onTap: () => setState(() => _mode = fields.TransactionMode.oneTime),
        ),
        _ModePill(
          label: 'Recurring',
          isSelected: _mode == fields.TransactionMode.recurring,
          onTap: () => setState(() => _mode = fields.TransactionMode.recurring),
        ),
        _ModePill(
          label: 'Installment',
          isSelected: _mode == fields.TransactionMode.installment,
          onTap: () =>
              setState(() => _mode = fields.TransactionMode.installment),
        ),
        _ModePill(
          label: 'Debt',
          isSelected: _mode == fields.TransactionMode.debt,
          onTap: () => setState(() => _mode = fields.TransactionMode.debt),
        ),
      ],
    );
  }

  Widget _buildTransactionTypeTabs() {
    return Row(
      children: [
        Expanded(
          child: _TransactionTypeTab(
            label: 'Expense',
            isSelected: _direction == fields.TransactionDirection.expense,
            onTap: () => _selectDirection(fields.TransactionDirection.expense),
          ),
        ),
        Expanded(
          child: _TransactionTypeTab(
            label: 'Income',
            isSelected: _direction == fields.TransactionDirection.income,
            onTap: () => _selectDirection(fields.TransactionDirection.income),
          ),
        ),
        Expanded(
          child: _TransactionTypeTab(
            label: 'Transfer',
            isSelected: _direction == fields.TransactionDirection.transfer,
            onTap: () => _selectDirection(fields.TransactionDirection.transfer),
          ),
        ),
      ],
    );
  }

  void _selectDirection(String direction) {
    setState(() {
      _direction = direction;
      _categoryId = null;
      _categoryDraft = null;
    });
  }

  Widget _buildNoAccountsPrompt() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add an account first',
            style: AppTypography.bodyMedium.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Transactions need an account so Lootr knows where the money moved.',
            style: AppTypography.caption.copyWith(
              color: context.lootrColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Add Account',
            onPressed: _openAccounts,
            isExpanded: false,
          ),
        ],
      ),
    );
  }

  Widget _buildRecurrencePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Recurrence Rule'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _recurrenceRule,
          items: const [
            DropdownMenuItem(value: 'daily', child: Text('Daily')),
            DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
            DropdownMenuItem(value: 'biweekly', child: Text('Biweekly')),
            DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
            DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
          ],
          onChanged: (value) =>
              setState(() => _recurrenceRule = value ?? 'monthly'),
          decoration: const InputDecoration(hintText: 'Select recurrence'),
        ),
      ],
    );
  }

  Widget _buildParentTransactionPicker(List<Transaction> transactions) {
    final available = transactions
        .where((transaction) => transaction.id != widget.initialTransaction?.id)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Parent Transaction'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue:
              available.any(
                (transaction) => transaction.id == _parentTransactionId,
              )
              ? _parentTransactionId
              : null,
          items: available
              .map(
                (transaction) => DropdownMenuItem<String>(
                  value: transaction.id,
                  child: Text(
                    '${DateFormat('MMM d').format(transaction.occurredAt)} • '
                    '${MoneyFormat.exact(transaction.amount, 'PHP')}',
                  ),
                ),
              )
              .toList(),
          onChanged: available.isEmpty
              ? null
              : (value) => setState(() => _parentTransactionId = value),
          decoration: InputDecoration(
            hintText: available.isEmpty
                ? 'No eligible parent transactions'
                : 'Select parent transaction',
          ),
        ),
      ],
    );
  }

  Widget _buildDebtPicker(List<DebtRecord> debts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Debt Record'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: debts.any((debt) => debt.id == _debtRecordId)
              ? _debtRecordId
              : null,
          items: debts
              .map(
                (debt) => DropdownMenuItem<String>(
                  value: debt.id,
                  child: Text(
                    '${debt.counterpartyName} • '
                    '${MoneyFormat.exact(debt.remainingBalance, 'PHP')}',
                  ),
                ),
              )
              .toList(),
          onChanged: debts.isEmpty
              ? null
              : (value) => setState(() => _debtRecordId = value),
          decoration: InputDecoration(
            hintText: debts.isEmpty
                ? 'No debt records yet'
                : 'Select debt record',
          ),
        ),
      ],
    );
  }

  Widget _buildTransferForm(List<Account> accounts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AmountInput(
          direction: ui.TransactionDirection.transfer,
          controller: _amountController,
          label: 'Transfer Amount',
        ),
        if (accounts.length < 2) ...[
          const SizedBox(height: 12),
          _buildTransferAccountsPrompt(accounts.length),
        ] else ...[
          const SizedBox(height: 16),
          AmountInput(
            direction: ui.TransactionDirection.transfer,
            controller: _feeController,
            label: 'Fee',
          ),
          const SizedBox(height: 16),
          _buildLabel('From Account'),
          const SizedBox(height: 8),
          AccountDropdown(
            accounts: accounts,
            selectedAccountId: _sourceAccountId,
            onChanged: (value) => setState(() => _sourceAccountId = value),
          ),
          const SizedBox(height: 16),
          _buildLabel('To Account'),
          const SizedBox(height: 8),
          AccountDropdown(
            accounts: accounts,
            selectedAccountId: _destinationAccountId,
            onChanged: (value) => setState(() => _destinationAccountId = value),
          ),
          const SizedBox(height: 16),
          _noteField(hintText: 'Optional transfer note'),
          const SizedBox(height: 16),
          _dateTimeSection(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: _isTransferEditing ? 'Save Changes' : 'Add Transfer',
              onPressed: _isSaving ? null : _saveTransfer,
              isLoading: _isSaving,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTransferAccountsPrompt(int accountCount) {
    final colorScheme = Theme.of(context).colorScheme;
    final copy = accountCount == 0
        ? 'Transfers need a source and destination account.'
        : 'Transfers need a second account for the destination.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            accountCount == 0 ? 'Add accounts first' : 'Add another account',
            style: AppTypography.bodyMedium.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            copy,
            style: AppTypography.caption.copyWith(
              color: context.lootrColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: accountCount == 0 ? 'Add Account' : 'Add Another Account',
            onPressed: _openAccounts,
            isExpanded: false,
          ),
        ],
      ),
    );
  }

  Widget _noteField({String hintText = 'Optional note'}) {
    return TextFormField(
      controller: _noteController,
      minLines: 2,
      maxLines: 4,
      decoration: InputDecoration(labelText: 'Note', hintText: hintText),
    );
  }

  Widget _dateTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Date & time', style: Theme.of(context).textTheme.labelLarge),
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: AppTypography.captionMedium.copyWith(
        color: context.lootrColors.textSecondary,
      ),
    );
  }
}

/// Entry modes offered at the top of the add-transaction surfaces.
enum EntryMode { quick, manual, scan }

/// Quick | Manual | Scan segmented control shown at the top of the
/// add-transaction sheet (and reused by the quick-actions sheet). Mirrors the
/// Expense/Income/Transfer tab styling so the two segmented rows read as one
/// design language. The highlighted segment always reflects the ACTIVE mode —
/// selection is fully controlled by [selected], never by internal state.
class EntryModeTabs extends StatelessWidget {
  const EntryModeTabs({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final EntryMode selected;
  final ValueChanged<EntryMode> onSelected;

  String _label(EntryMode mode) {
    switch (mode) {
      case EntryMode.quick:
        return 'Quick';
      case EntryMode.manual:
        return 'Manual';
      case EntryMode.scan:
        return 'Scan';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final mode in EntryMode.values)
          Expanded(
            child: _TransactionTypeTab(
              label: _label(mode),
              isSelected: selected == mode,
              onTap: () => onSelected(mode),
            ),
          ),
      ],
    );
  }
}

class _TransactionTypeTab extends StatelessWidget {
  const _TransactionTypeTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: isSelected
                ? BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.sm),
                    ),
                  )
                : null,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: isSelected
                    ? colorScheme.onSurface
                    : context.lootrColors.textSecondary,
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 2,
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outline,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.captionMedium.copyWith(
            color: isSelected
                ? colorScheme.onPrimaryContainer
                : context.lootrColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ConfidenceDot extends StatelessWidget {
  const _ConfidenceDot({required this.confidence});

  final double confidence;

  @override
  Widget build(BuildContext context) {
    final color = confidence >= 0.7
        ? AppColors.success500
        : confidence >= 0.4
        ? AppColors.warning500
        : AppColors.danger500;

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
