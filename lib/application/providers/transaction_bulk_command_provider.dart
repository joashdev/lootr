import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/transaction_repo.dart' as repository;
import 'repo_providers.dart';

enum TransactionBulkOperation { recategorize, moveAccount, delete }

class TransactionBulkRequest {
  const TransactionBulkRequest({
    required this.transactionIds,
    required this.operation,
    this.targetId,
  });

  final Set<String> transactionIds;
  final TransactionBulkOperation operation;
  final String? targetId;
}

class TransactionBulkIssue {
  const TransactionBulkIssue(this.transactionId, this.message);

  final String transactionId;
  final String message;
}

class TransactionBulkPlan {
  const TransactionBulkPlan._({
    required this.request,
    required this.transactionIds,
    required this.issues,
    required this._repositoryPlan,
  });

  final TransactionBulkRequest request;
  final List<String> transactionIds;
  final List<TransactionBulkIssue> issues;
  final repository.TransactionBulkPlan _repositoryPlan;

  bool get canApply => transactionIds.isNotEmpty && issues.isEmpty;
}

class TransactionBulkUndo {
  const TransactionBulkUndo({
    required this.transactionIds,
    required this.rollback,
  });

  final List<String> transactionIds;
  final Future<void> Function() rollback;
}

class TransactionBulkPreflightException implements Exception {
  const TransactionBulkPreflightException(this.issues);

  final List<TransactionBulkIssue> issues;

  @override
  String toString() => issues.map((issue) => issue.message).toSet().join('\n');
}

/// Application boundary for transaction cleanup commands.
///
/// Presentation code works only with application-owned request/result types;
/// repository plans remain an implementation detail of this command.
class TransactionBulkCommand {
  const TransactionBulkCommand(this._repository);

  final repository.TransactionRepo _repository;

  Future<TransactionBulkPlan> preflight(TransactionBulkRequest request) async {
    final repositoryRequest = repository.TransactionBulkRequest(
      transactionIds: request.transactionIds,
      operation: _toRepositoryOperation(request.operation),
      targetId: request.targetId,
    );
    final plan = await _repository.preflightBulk(repositoryRequest);
    return TransactionBulkPlan._(
      request: request,
      transactionIds: List.unmodifiable(plan.transactionIds),
      issues: List.unmodifiable(plan.issues.map(_fromRepositoryIssue)),
      repositoryPlan: plan,
    );
  }

  Future<TransactionBulkUndo> apply(TransactionBulkPlan plan) async {
    try {
      final undo = await _repository.applyBulk(plan._repositoryPlan);
      return TransactionBulkUndo(
        transactionIds: List.unmodifiable(undo.transactionIds),
        rollback: undo.rollback,
      );
    } on repository.TransactionBulkPreflightException catch (error) {
      throw TransactionBulkPreflightException(
        List.unmodifiable(error.issues.map(_fromRepositoryIssue)),
      );
    }
  }
}

final transactionBulkCommandProvider = Provider<TransactionBulkCommand>(
  (ref) => TransactionBulkCommand(ref.watch(transactionRepoProvider)),
);

repository.TransactionBulkOperation _toRepositoryOperation(
  TransactionBulkOperation operation,
) => switch (operation) {
  TransactionBulkOperation.recategorize =>
    repository.TransactionBulkOperation.recategorize,
  TransactionBulkOperation.moveAccount =>
    repository.TransactionBulkOperation.moveAccount,
  TransactionBulkOperation.delete => repository.TransactionBulkOperation.delete,
};

TransactionBulkIssue _fromRepositoryIssue(
  repository.TransactionBulkIssue issue,
) => TransactionBulkIssue(issue.transactionId, issue.message);
