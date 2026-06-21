import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/repo_providers.dart';
import '../../../core/theme/spacing.dart';
import '../../../data/database/app_database.dart';
import '../../../domain/entities/account.dart';
import '../../../domain/entities/category.dart';
import '../../../domain/entities/debt_record.dart';
import '../../../domain/entities/goal.dart';
import '../../../domain/entities/household.dart';
import '../../../domain/entities/recurring_template.dart';
import '../../../domain/value_objects/field_types.dart';

String _makeId(String prefix) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch}';

Future<String> _ensureCurrentUserId(WidgetRef ref) async {
  final userRepo = ref.read(userRepoProvider);
  final currentUser = await userRepo.getCurrentUser();
  if (currentUser != null) return currentUser.id;

  final newId = _makeId('usr');
  await userRepo.create(
    UsersCompanion.insert(
      id: newId,
      displayName: const Value('Local User'),
      locale: const Value('en-PH'),
      timezone: const Value('Asia/Manila'),
    ),
  );
  return newId;
}

double? _parseAmount(String raw) {
  final cleaned = raw.trim().replaceAll(',', '');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

DateTime _nextOccurrenceForRule(String rule, {DateTime? from}) {
  final base = from ?? DateTime.now();
  switch (rule) {
    case 'daily':
      return base.add(const Duration(days: 1));
    case 'weekly':
      return base.add(const Duration(days: 7));
    case 'biweekly':
      return base.add(const Duration(days: 14));
    case 'monthly':
      return DateTime(base.year, base.month + 1, base.day);
    case 'quarterly':
      return DateTime(base.year, base.month + 3, base.day);
    case 'yearly':
      return DateTime(base.year + 1, base.month, base.day);
    default:
      return base.add(const Duration(days: 30));
  }
}

Future<void> _showSheet({
  required BuildContext context,
  required Widget Function(BuildContext, StateSetter) builder,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final insets = MediaQuery.viewInsetsOf(context).bottom;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.pagePaddingMobile,
                AppSpacing.space4,
                AppSpacing.pagePaddingMobile,
                insets + AppSpacing.space4,
              ),
              child: SingleChildScrollView(child: builder(context, setState)),
            ),
          );
        },
      );
    },
  );
}

InputDecoration _fieldDecoration(String label) {
  return InputDecoration(labelText: label, border: const OutlineInputBorder());
}

void _showMessage(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<void> showAccountSheet(
  BuildContext context,
  WidgetRef ref, {
  Account? initial,
}) async {
  final nameController = TextEditingController(text: initial?.name ?? '');
  final balanceController = TextEditingController(
    text: initial == null ? '' : initial.balance.abs().toStringAsFixed(2),
  );
  var accountType = initial?.accountType ?? AccountType.cash;

  await _showSheet(
    context: context,
    builder: (sheetContext, setState) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            initial == null ? 'New Account' : 'Edit Account',
            style: Theme.of(sheetContext).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.space4),
          TextField(
            controller: nameController,
            decoration: _fieldDecoration('Account Name'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: AppSpacing.space3),
          DropdownButtonFormField<String>(
            value: accountType,
            decoration: _fieldDecoration('Account Type'),
            items: const [
              DropdownMenuItem(value: AccountType.cash, child: Text('Cash')),
              DropdownMenuItem(value: AccountType.bank, child: Text('Bank')),
              DropdownMenuItem(
                value: AccountType.ewallet,
                child: Text('E-Wallet'),
              ),
              DropdownMenuItem(
                value: AccountType.savings,
                child: Text('Savings'),
              ),
              DropdownMenuItem(
                value: AccountType.investment,
                child: Text('Investment'),
              ),
              DropdownMenuItem(
                value: AccountType.crypto,
                child: Text('Crypto'),
              ),
              DropdownMenuItem(
                value: AccountType.creditCard,
                child: Text('Credit Card'),
              ),
              DropdownMenuItem(value: AccountType.loan, child: Text('Loan')),
              DropdownMenuItem(value: AccountType.bnpl, child: Text('BNPL')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => accountType = value);
            },
          ),
          const SizedBox(height: AppSpacing.space3),
          TextField(
            controller: balanceController,
            decoration: _fieldDecoration(
              initial == null ? 'Opening Balance' : 'Current Balance',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: AppSpacing.space4),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final balance = _parseAmount(balanceController.text) ?? 0;
                if (name.isEmpty) {
                  _showMessage(context, 'Account name is required.');
                  return;
                }

                final accountRepo = ref.read(accountRepoProvider);
                if (initial == null) {
                  final ownerUserId = await _ensureCurrentUserId(ref);
                  await accountRepo.create(
                    AccountsCompanion.insert(
                      id: _makeId('acc'),
                      ownerUserId: ownerUserId,
                      name: name,
                      accountType: accountType,
                      balance: Value(balance),
                    ),
                  );
                } else {
                  await accountRepo.update(
                    AccountsCompanion(
                      id: Value(initial.id),
                      name: Value(name),
                      accountType: Value(accountType),
                      balance: Value(balance),
                    ),
                  );
                }

                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                _showMessage(
                  context,
                  initial == null ? 'Account created.' : 'Account updated.',
                );
              },
              child: Text(initial == null ? 'Save Account' : 'Save Changes'),
            ),
          ),
        ],
      );
    },
  );
}

Future<void> showDebtSheet(BuildContext context, WidgetRef ref) async {
  final counterpartyController = TextEditingController();
  final amountController = TextEditingController();
  final remainingController = TextEditingController();
  final noteController = TextEditingController();
  var direction = DebtDirection.borrowed;

  await _showSheet(
    context: context,
    builder: (sheetContext, setState) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('New Debt', style: Theme.of(sheetContext).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.space4),
          TextField(
            controller: counterpartyController,
            decoration: _fieldDecoration('Counterparty'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: AppSpacing.space3),
          DropdownButtonFormField<String>(
            value: direction,
            decoration: _fieldDecoration('Direction'),
            items: const [
              DropdownMenuItem(
                value: DebtDirection.borrowed,
                child: Text('You borrowed'),
              ),
              DropdownMenuItem(
                value: DebtDirection.lent,
                child: Text('You lent'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => direction = value);
            },
          ),
          const SizedBox(height: AppSpacing.space3),
          TextField(
            controller: amountController,
            decoration: _fieldDecoration('Total Amount'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: AppSpacing.space3),
          TextField(
            controller: remainingController,
            decoration: _fieldDecoration('Remaining Balance'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: AppSpacing.space3),
          TextField(
            controller: noteController,
            decoration: _fieldDecoration('Note (Optional)'),
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.space4),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                final counterparty = counterpartyController.text.trim();
                final amount = _parseAmount(amountController.text);
                final remaining =
                    _parseAmount(remainingController.text) ?? amount ?? 0;
                if (counterparty.isEmpty || amount == null || amount <= 0) {
                  _showMessage(
                    context,
                    'Enter a counterparty and valid amount.',
                  );
                  return;
                }

                final ownerUserId = await _ensureCurrentUserId(ref);
                final status = remaining <= 0
                    ? DebtStatus.settled
                    : remaining < amount
                    ? DebtStatus.partiallyPaid
                    : DebtStatus.active;

                await ref
                    .read(debtRepoProvider)
                    .create(
                      DebtRecordsCompanion.insert(
                        id: _makeId('debt'),
                        ownerUserId: ownerUserId,
                        counterpartyName: counterparty,
                        debtDirection: direction,
                        amount: amount,
                        remainingBalance: remaining.clamp(0, amount).toDouble(),
                        note: Value(
                          noteController.text.trim().isEmpty
                              ? null
                              : noteController.text.trim(),
                        ),
                        status: status,
                      ),
                    );

                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                _showMessage(context, 'Debt saved.');
              },
              child: const Text('Save Debt'),
            ),
          ),
        ],
      );
    },
  );
}

Future<void> showGoalSheet(BuildContext context, WidgetRef ref) async {
  final nameController = TextEditingController();
  final targetController = TextEditingController();
  final currentController = TextEditingController();
  var goalType = GoalType.savings;

  await _showSheet(
    context: context,
    builder: (sheetContext, setState) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('New Goal', style: Theme.of(sheetContext).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.space4),
          TextField(
            controller: nameController,
            decoration: _fieldDecoration('Goal Name'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: AppSpacing.space3),
          DropdownButtonFormField<String>(
            value: goalType,
            decoration: _fieldDecoration('Goal Type'),
            items: const [
              DropdownMenuItem(
                value: GoalType.emergencyFund,
                child: Text('Emergency Fund'),
              ),
              DropdownMenuItem(value: GoalType.savings, child: Text('Savings')),
              DropdownMenuItem(value: GoalType.travel, child: Text('Travel')),
              DropdownMenuItem(
                value: GoalType.debtPayoff,
                child: Text('Debt Payoff'),
              ),
              DropdownMenuItem(value: GoalType.custom, child: Text('Custom')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => goalType = value);
            },
          ),
          const SizedBox(height: AppSpacing.space3),
          TextField(
            controller: targetController,
            decoration: _fieldDecoration('Target Amount'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: AppSpacing.space3),
          TextField(
            controller: currentController,
            decoration: _fieldDecoration('Current Amount'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: AppSpacing.space4),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final targetAmount = _parseAmount(targetController.text);
                final currentAmount = _parseAmount(currentController.text) ?? 0;
                if (name.isEmpty || targetAmount == null || targetAmount <= 0) {
                  _showMessage(context, 'Enter a goal name and target amount.');
                  return;
                }

                final ownerUserId = await _ensureCurrentUserId(ref);
                await ref
                    .read(goalRepoProvider)
                    .create(
                      GoalsCompanion.insert(
                        id: _makeId('goal'),
                        ownerUserId: ownerUserId,
                        name: name,
                        goalType: goalType,
                        targetAmount: targetAmount,
                        currentAmount: Value(currentAmount),
                      ),
                    );

                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                _showMessage(context, 'Goal created.');
              },
              child: const Text('Save Goal'),
            ),
          ),
        ],
      );
    },
  );
}

Future<void> showGoalContributionSheet(
  BuildContext context,
  WidgetRef ref,
  Goal goal, {
  required List<Account> accounts,
}) async {
  final amountController = TextEditingController();
  var selectedAccountId = accounts.isEmpty ? null : accounts.first.id;

  await _showSheet(
    context: context,
    builder: (sheetContext, setState) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Add Contribution',
            style: Theme.of(sheetContext).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(goal.name),
          const SizedBox(height: AppSpacing.space4),
          TextField(
            controller: amountController,
            decoration: _fieldDecoration('Contribution Amount'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          if (accounts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.space3),
            DropdownButtonFormField<String>(
              value: selectedAccountId,
              decoration: _fieldDecoration('Source Account'),
              items: accounts
                  .map(
                    (account) => DropdownMenuItem(
                      value: account.id,
                      child: Text(account.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => selectedAccountId = value);
              },
            ),
          ],
          const SizedBox(height: AppSpacing.space4),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                final amount = _parseAmount(amountController.text);
                if (amount == null || amount <= 0) {
                  _showMessage(context, 'Enter a valid contribution amount.');
                  return;
                }

                await ref
                    .read(goalRepoProvider)
                    .addContribution(goal.id, amount);

                if (selectedAccountId != null) {
                  await ref
                      .read(transactionRepoProvider)
                      .create(
                        TransactionsCompanion.insert(
                          id: _makeId('txn'),
                          accountId: selectedAccountId!,
                          amount: amount,
                          transactionDirection: TransactionDirection.expense,
                          transactionMode: TransactionMode.oneTime,
                          note: Value('Goal contribution • ${goal.name}'),
                          metadata: Value({'goalId': goal.id}),
                          occurredAt: DateTime.now(),
                        ),
                      );
                }

                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                _showMessage(context, 'Contribution added.');
              },
              child: const Text('Save Contribution'),
            ),
          ),
        ],
      );
    },
  );
}

Future<void> showDebtPaymentSheet(
  BuildContext context,
  WidgetRef ref,
  DebtRecord debt, {
  required List<Account> accounts,
  required bool settle,
}) async {
  final amountController = TextEditingController(
    text: settle ? debt.remainingBalance.toStringAsFixed(2) : '',
  );
  var selectedAccountId = accounts.isEmpty ? null : accounts.first.id;

  await _showSheet(
    context: context,
    builder: (sheetContext, setState) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            settle ? 'Settle Debt' : 'Record Partial Payment',
            style: Theme.of(sheetContext).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(debt.counterpartyName),
          const SizedBox(height: AppSpacing.space4),
          TextField(
            controller: amountController,
            decoration: _fieldDecoration('Payment Amount'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          if (accounts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.space3),
            DropdownButtonFormField<String>(
              value: selectedAccountId,
              decoration: _fieldDecoration('Account'),
              items: accounts
                  .map(
                    (account) => DropdownMenuItem(
                      value: account.id,
                      child: Text(account.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => selectedAccountId = value);
              },
            ),
          ],
          const SizedBox(height: AppSpacing.space4),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                final amount = _parseAmount(amountController.text);
                if (amount == null || amount <= 0) {
                  _showMessage(context, 'Enter a valid payment amount.');
                  return;
                }

                final boundedAmount = amount > debt.remainingBalance
                    ? debt.remainingBalance
                    : amount;
                final remaining = (debt.remainingBalance - boundedAmount).clamp(
                  0,
                  debt.amount,
                );
                final status = remaining <= 0
                    ? DebtStatus.settled
                    : DebtStatus.partiallyPaid;

                if (selectedAccountId != null) {
                  final payee = await ref
                      .read(payeeRepoProvider)
                      .createOrGetByName(debt.counterpartyName);
                  await ref
                      .read(transactionRepoProvider)
                      .create(
                        TransactionsCompanion.insert(
                          id: _makeId('txn'),
                          accountId: selectedAccountId!,
                          payeeId: Value(payee.id),
                          amount: boundedAmount,
                          transactionDirection:
                              debt.debtDirection == DebtDirection.lent
                              ? TransactionDirection.income
                              : TransactionDirection.expense,
                          transactionMode: TransactionMode.debt,
                          transactionSubtype: const Value(
                            TransactionSubtype.debtPayment,
                          ),
                          note: Value(
                            settle
                                ? 'Debt settled • ${debt.counterpartyName}'
                                : 'Debt payment • ${debt.counterpartyName}',
                          ),
                          metadata: Value({'debtId': debt.id}),
                          occurredAt: DateTime.now(),
                        ),
                      );
                }

                if (status == DebtStatus.settled) {
                  await ref.read(debtRepoProvider).settle(debt.id);
                } else {
                  await ref
                      .read(debtRepoProvider)
                      .update(
                        DebtRecordsCompanion(
                          id: Value(debt.id),
                          remainingBalance: Value(remaining.toDouble()),
                          status: const Value(DebtStatus.partiallyPaid),
                        ),
                      );
                }

                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                _showMessage(
                  context,
                  status == DebtStatus.settled
                      ? 'Debt settled.'
                      : 'Payment recorded.',
                );
              },
              child: Text(settle ? 'Settle' : 'Save Payment'),
            ),
          ),
        ],
      );
    },
  );
}

Future<void> showRecurringSheet(
  BuildContext context,
  WidgetRef ref, {
  required List<Account> accounts,
  RecurringTemplate? initial,
  String? initialPayeeName,
}) async {
  if (accounts.isEmpty) {
    _showMessage(context, 'Create an account first to add recurring items.');
    return;
  }

  final payeeController = TextEditingController(text: initialPayeeName ?? '');
  final amountController = TextEditingController(
    text: initial?.amount.toStringAsFixed(2) ?? '',
  );
  var selectedAccountId = initial?.accountId ?? accounts.first.id;
  var recurrenceRule = initial?.recurrenceRule ?? 'monthly';

  await _showSheet(
    context: context,
    builder: (sheetContext, setState) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            initial == null ? 'New Recurring Item' : 'Edit Recurring Item',
            style: Theme.of(sheetContext).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.space4),
          TextField(
            controller: payeeController,
            decoration: _fieldDecoration('Payee (Optional)'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: AppSpacing.space3),
          TextField(
            controller: amountController,
            decoration: _fieldDecoration('Amount'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: AppSpacing.space3),
          DropdownButtonFormField<String>(
            value: selectedAccountId,
            decoration: _fieldDecoration('Account'),
            items: accounts
                .map(
                  (account) => DropdownMenuItem(
                    value: account.id,
                    child: Text(account.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => selectedAccountId = value);
            },
          ),
          const SizedBox(height: AppSpacing.space3),
          DropdownButtonFormField<String>(
            value: recurrenceRule,
            decoration: _fieldDecoration('Frequency'),
            items: const [
              DropdownMenuItem(value: 'daily', child: Text('Daily')),
              DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
              DropdownMenuItem(value: 'biweekly', child: Text('Biweekly')),
              DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
              DropdownMenuItem(value: 'quarterly', child: Text('Quarterly')),
              DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => recurrenceRule = value);
            },
          ),
          const SizedBox(height: AppSpacing.space4),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                final amount = _parseAmount(amountController.text);
                if (amount == null || amount <= 0) {
                  _showMessage(context, 'Enter a valid amount.');
                  return;
                }

                String? payeeId;
                final payeeName = payeeController.text.trim();
                if (payeeName.isNotEmpty) {
                  final payee = await ref
                      .read(payeeRepoProvider)
                      .createOrGetByName(payeeName);
                  payeeId = payee.id;
                }

                final recurringRepo = ref.read(recurringRepoProvider);
                if (initial == null) {
                  await recurringRepo.create(
                    RecurringTemplatesCompanion.insert(
                      id: _makeId('rec'),
                      accountId: selectedAccountId,
                      payeeId: Value(payeeId),
                      amount: amount,
                      recurrenceRule: recurrenceRule,
                      nextOccurrenceAt: Value(
                        _nextOccurrenceForRule(recurrenceRule),
                      ),
                    ),
                  );
                } else {
                  await recurringRepo.update(
                    RecurringTemplatesCompanion(
                      id: Value(initial.id),
                      accountId: Value(selectedAccountId),
                      payeeId: Value(payeeId),
                      amount: Value(amount),
                      recurrenceRule: Value(recurrenceRule),
                      nextOccurrenceAt: Value(
                        _nextOccurrenceForRule(
                          recurrenceRule,
                          from: initial.nextOccurrenceAt,
                        ),
                      ),
                    ),
                  );
                }

                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                _showMessage(
                  context,
                  initial == null
                      ? 'Recurring item created.'
                      : 'Recurring item updated.',
                );
              },
              child: Text(
                initial == null ? 'Save Recurring Item' : 'Save Changes',
              ),
            ),
          ),
        ],
      );
    },
  );
}

Future<void> showCategorySheet(
  BuildContext context,
  WidgetRef ref, {
  Category? initial,
  String? initialGroup,
}) async {
  final nameController = TextEditingController(text: initial?.name ?? '');
  final iconController = TextEditingController(text: initial?.icon ?? '');
  final colorController = TextEditingController(text: initial?.color ?? '');
  var group = initial?.categoryGroup ?? initialGroup ?? CategoryGroup.expense;

  await _showSheet(
    context: context,
    builder: (sheetContext, setState) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            initial == null ? 'New Category' : 'Edit Category',
            style: Theme.of(sheetContext).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.space4),
          TextField(
            controller: nameController,
            decoration: _fieldDecoration('Category Name'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: AppSpacing.space3),
          DropdownButtonFormField<String>(
            value: group,
            decoration: _fieldDecoration('Group'),
            items: const [
              DropdownMenuItem(
                value: CategoryGroup.expense,
                child: Text('Expense'),
              ),
              DropdownMenuItem(
                value: CategoryGroup.income,
                child: Text('Income'),
              ),
              DropdownMenuItem(
                value: CategoryGroup.transfer,
                child: Text('Transfer'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => group = value);
            },
          ),
          const SizedBox(height: AppSpacing.space3),
          TextField(
            controller: iconController,
            decoration: _fieldDecoration('Icon Name'),
          ),
          const SizedBox(height: AppSpacing.space3),
          TextField(
            controller: colorController,
            decoration: _fieldDecoration('Color Hex'),
          ),
          const SizedBox(height: AppSpacing.space4),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  _showMessage(context, 'Category name is required.');
                  return;
                }

                final repo = ref.read(categoryRepoProvider);
                if (initial == null) {
                  await repo.create(
                    CategoriesCompanion.insert(
                      id: _makeId('cat'),
                      name: name,
                      categoryGroup: group,
                      icon: Value(
                        iconController.text.trim().isEmpty
                            ? null
                            : iconController.text.trim(),
                      ),
                      color: Value(
                        colorController.text.trim().isEmpty
                            ? null
                            : colorController.text.trim(),
                      ),
                    ),
                  );
                } else {
                  await repo.update(
                    CategoriesCompanion(
                      id: Value(initial.id),
                      name: Value(name),
                      categoryGroup: Value(group),
                      icon: Value(
                        iconController.text.trim().isEmpty
                            ? null
                            : iconController.text.trim(),
                      ),
                      color: Value(
                        colorController.text.trim().isEmpty
                            ? null
                            : colorController.text.trim(),
                      ),
                    ),
                  );
                }

                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                _showMessage(
                  context,
                  initial == null ? 'Category created.' : 'Category updated.',
                );
              },
              child: Text(initial == null ? 'Save Category' : 'Save Changes'),
            ),
          ),
        ],
      );
    },
  );
}

Future<void> showHouseholdSheet(
  BuildContext context,
  WidgetRef ref, {
  Household? initial,
}) async {
  final nameController = TextEditingController(text: initial?.name ?? '');

  await _showSheet(
    context: context,
    builder: (sheetContext, _) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            initial == null ? 'New Household' : 'Rename Household',
            style: Theme.of(sheetContext).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.space4),
          TextField(
            controller: nameController,
            decoration: _fieldDecoration('Household Name'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: AppSpacing.space4),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  _showMessage(context, 'Household name is required.');
                  return;
                }

                final householdRepo = ref.read(householdRepoProvider);
                if (initial == null) {
                  final currentUserId = await _ensureCurrentUserId(ref);
                  final householdId = _makeId('hh');
                  await householdRepo.create(
                    HouseholdsCompanion.insert(
                      id: householdId,
                      name: name,
                      createdByUserId: currentUserId,
                    ),
                  );
                  await householdRepo.addMember(
                    HouseholdMembersCompanion.insert(
                      id: _makeId('hm'),
                      householdId: householdId,
                      userId: currentUserId,
                      role: HouseholdRole.owner,
                    ),
                  );
                } else {
                  await householdRepo.update(
                    HouseholdsCompanion(
                      id: Value(initial.id),
                      name: Value(name),
                    ),
                  );
                }

                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                _showMessage(
                  context,
                  initial == null ? 'Household created.' : 'Household updated.',
                );
              },
              child: Text(initial == null ? 'Save Household' : 'Save Changes'),
            ),
          ),
        ],
      );
    },
  );
}

Future<void> showHouseholdMemberSheet(
  BuildContext context,
  WidgetRef ref,
  Household household,
) async {
  final nameController = TextEditingController();
  var role = HouseholdRole.member;

  await _showSheet(
    context: context,
    builder: (sheetContext, setState) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Invite Member',
            style: Theme.of(sheetContext).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(household.name),
          const SizedBox(height: AppSpacing.space4),
          TextField(
            controller: nameController,
            decoration: _fieldDecoration('Member Name'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: AppSpacing.space3),
          DropdownButtonFormField<String>(
            value: role,
            decoration: _fieldDecoration('Role'),
            items: const [
              DropdownMenuItem(
                value: HouseholdRole.member,
                child: Text('Member'),
              ),
              DropdownMenuItem(
                value: HouseholdRole.viewer,
                child: Text('Viewer'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => role = value);
            },
          ),
          const SizedBox(height: AppSpacing.space4),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  _showMessage(context, 'Member name is required.');
                  return;
                }

                final userId = _makeId('usr');
                await ref
                    .read(userRepoProvider)
                    .create(
                      UsersCompanion.insert(
                        id: userId,
                        displayName: Value(name),
                        locale: const Value('en-PH'),
                        timezone: const Value('Asia/Manila'),
                      ),
                    );
                await ref
                    .read(householdRepoProvider)
                    .addMember(
                      HouseholdMembersCompanion.insert(
                        id: _makeId('hm'),
                        householdId: household.id,
                        userId: userId,
                        role: role,
                      ),
                    );

                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                _showMessage(context, 'Member added.');
              },
              child: const Text('Add Member'),
            ),
          ),
        ],
      );
    },
  );
}
