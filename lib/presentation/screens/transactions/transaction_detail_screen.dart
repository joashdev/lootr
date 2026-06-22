import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

import '../../../application/providers/accounts_provider.dart';
import '../../../application/providers/categories_provider.dart';
import '../../../application/providers/payees_provider.dart';
import '../../../application/providers/repo_providers.dart';
import '../../../application/providers/transaction_entry_support.dart';
import '../../../application/providers/undo_stack_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/entities/account.dart';
import '../../../domain/entities/category.dart';
import '../../../domain/entities/mappers.dart';
import '../../../domain/entities/payee.dart';
import '../../../domain/entities/transaction.dart';
import '../../../domain/entities/transfer.dart';
import '../../../domain/use_cases/delete_transaction.dart';
import '../../../domain/use_cases/delete_transfer.dart';
import '../../shared/components/buttons/ghost_button.dart';
import '../../shared/components/buttons/secondary_button.dart';
import '../../shared/components/app_snackbar.dart';
import 'widgets/transaction_detail_card.dart';

class _TransactionDetailEntry {
  const _TransactionDetailEntry({required this.transaction, this.transfer});

  final Transaction transaction;
  final Transfer? transfer;
}

final _transactionDetailEntryProvider = StreamProvider.autoDispose
    .family<_TransactionDetailEntry?, String>((ref, id) {
      final transactionRepo = ref.watch(transactionRepoProvider);
      final transferRepo = ref.watch(transferRepoProvider);

      return Rx.combineLatest2(
        transactionRepo.watchById(id),
        transferRepo.watchById(id),
        (transactionRow, transferRow) {
          if (transactionRow != null && transactionRow.deletedAt == null) {
            return _TransactionDetailEntry(
              transaction: transactionRow.toEntity(),
            );
          }

          if (transferRow != null && transferRow.deletedAt == null) {
            final transfer = transferRow.toEntity();
            return _TransactionDetailEntry(
              transaction: mapTransferToTransaction(transfer),
              transfer: transfer,
            );
          }

          return null;
        },
      );
    });

class TransactionDetailScreen extends ConsumerStatefulWidget {
  const TransactionDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState
    extends ConsumerState<TransactionDetailScreen> {
  Color _directionColor(Transaction transaction) {
    final lotrColors = context.lootrColors;
    switch (transaction.direction) {
      case 'expense':
        return lotrColors.expense;
      case 'income':
        return lotrColors.income;
      case 'transfer':
        return lotrColors.transfer;
      default:
        return lotrColors.expense;
    }
  }

  String _amountPrefix(Transaction transaction) {
    switch (transaction.direction) {
      case 'expense':
        return '-';
      case 'income':
        return '+';
      default:
        return '';
    }
  }

  String _directionLabel(Transaction transaction) {
    switch (transaction.direction) {
      case 'expense':
        return 'Expense';
      case 'income':
        return 'Income';
      case 'transfer':
        return 'Transfer';
      default:
        return transaction.direction;
    }
  }

  String _modeLabel(Transaction transaction, {bool isTransfer = false}) {
    if (isTransfer) return 'Transfer';
    switch (transaction.mode) {
      case 'one_time':
        return 'One-time';
      case 'recurring':
        return 'Recurring';
      case 'installment':
        return 'Installment';
      case 'debt':
        return 'Debt';
      default:
        return transaction.mode;
    }
  }

  String _accountName(String accountId, List<Account> accounts) {
    for (final account in accounts) {
      if (account.id == accountId) return account.name;
    }
    return accountId;
  }

  String? _categoryName(Transaction transaction, List<Category> categories) {
    if (transaction.categoryId == null) return null;
    for (final category in categories) {
      if (category.id == transaction.categoryId) return category.name;
    }
    return transaction.categoryId;
  }

  String? _payeeName(Transaction transaction, List<Payee> payees) {
    if (transaction.payeeId == null) return null;
    for (final payee in payees) {
      if (payee.id == transaction.payeeId) {
        return payee.displayName?.isNotEmpty == true
            ? payee.displayName
            : payee.normalizedName;
      }
    }
    return transaction.payeeId;
  }

  Future<void> _onDelete(_TransactionDetailEntry entry) async {
    final isTransfer = entry.transfer != null;
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
        ? await DeleteTransfer(
            ref.read(transferRepoProvider),
          ).call(entry.transfer!.id)
        : await DeleteTransaction(
            ref.read(transactionRepoProvider),
          ).call(entry.transaction.id);

    result.fold(
      onSuccess: (undoEntry) {
        ref.read(undoStackProvider.notifier).push(undoEntry);
        if (mounted) {
          context.pop();
          AppSnackBar.show(
            context,
            undoEntry.message,
            variant: AppSnackBarVariant.success,
            actionLabel: 'UNDO',
            onAction: () => ref
                .read(undoStackProvider.notifier)
                .undo(undoEntry.transactionId),
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

  @override
  Widget build(BuildContext context) {
    final entryAsync = ref.watch(_transactionDetailEntryProvider(widget.id));
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

    return entryAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Transaction')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Transaction')),
        body: Center(child: Text(error.toString())),
      ),
      data: (entry) {
        if (entry == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Transaction')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Transaction not found',
                    style: AppTypography.h2.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space3),
                  OutlinedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Back'),
                  ),
                ],
              ),
            ),
          );
        }

        return _buildContent(
          entry,
          accounts: accounts,
          categories: categories,
          payees: payees,
        );
      },
    );
  }

  Widget _buildContent(
    _TransactionDetailEntry entry, {
    required List<Account> accounts,
    required List<Category> categories,
    required List<Payee> payees,
  }) {
    final transaction = entry.transaction;
    final transfer = entry.transfer;
    final isTransfer = transfer != null;
    final directionColor = _directionColor(transaction);
    final amountStr = NumberFormat('#,##0.00').format(transaction.amount);
    final transferDestinationName = isTransfer
        ? _accountName(transfer.destinationAccountId, accounts)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(
              '/transactions/new',
              extra: isTransfer ? transfer : transaction,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildAmountHeader(
              transaction,
              directionColor,
              amountStr,
              isTransfer: isTransfer,
            ),
            TransactionDetailCard(
              transaction: transaction,
              accountName: _accountName(transaction.accountId, accounts),
              categoryName: isTransfer
                  ? null
                  : _categoryName(transaction, categories),
              payeeName: isTransfer
                  ? transferDestinationName
                  : _payeeName(transaction, payees),
              parentInfo: transaction.parentTransactionId,
              recurringInfo: transaction.recurringTemplateId,
              transferInfo: isTransfer
                  ? 'To $transferDestinationName'
                  : transaction.metadata?['transfer_id']?.toString(),
              metadata: isTransfer
                  ? <String, dynamic>{
                      'From': _accountName(transfer.sourceAccountId, accounts),
                      'To': transferDestinationName,
                      if (transfer.feeAmount > 0)
                        'Fee': 'PHP ${transfer.feeAmount.toStringAsFixed(2)}',
                    }
                  : transaction.metadata,
            ),
            const SizedBox(height: AppSpacing.space4),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Edit',
                      onPressed: () => context.push(
                        '/transactions/new',
                        extra: isTransfer ? transfer : transaction,
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space3),
                  Expanded(
                    child: SecondaryButton(
                      label: 'Delete',
                      onPressed: () => _onDelete(entry),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      isDanger: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.space6),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountHeader(
    Transaction transaction,
    Color directionColor,
    String amountStr, {
    required bool isTransfer,
  }) {
    final dateStr = DateFormat(
      'MMM d, yyyy \u00b7 h:mm a',
    ).format(transaction.occurredAt);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space4,
        AppSpacing.space6,
        AppSpacing.space4,
        AppSpacing.space4,
      ),
      child: Column(
        children: [
          Text(
            '${_amountPrefix(transaction)}\u20B1$amountStr',
            style: AppTypography.display.copyWith(color: directionColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.space2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LocalBadge(
                label: _directionLabel(transaction),
                color: directionColor,
              ),
              const SizedBox(width: 8),
              _LocalBadge(
                label: _modeLabel(transaction, isTransfer: isTransfer),
                color: directionColor.withValues(alpha: 0.7),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            dateStr,
            style: AppTypography.caption.copyWith(
              color: context.lootrColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalBadge extends StatelessWidget {
  const _LocalBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.micro.copyWith(color: color),
      ),
    );
  }
}
