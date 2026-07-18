import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

import '../../domain/entities/mappers.dart';
import '../../domain/services/currency_aggregation.dart';
import '../../domain/value_objects/exact_money.dart';
import '../../domain/value_objects/field_types.dart';
import 'repo_providers.dart';

final netWorthByCurrencyProvider = StreamProvider<Map<String, ExactMoney>>((
  ref,
) {
  final repo = ref.watch(accountRepoProvider);
  return repo.watchAll().map((rows) {
    final grouped = CurrencyAggregation.balances(
      rows.map((row) => row.toEntity()),
      isLiability: _isLiability,
    );
    return {
      for (final entry in grouped.entries) entry.key: entry.value.netWorth,
    };
  });
});

/// Compatibility projection for the user's selected currency.
///
/// Consumers that show more than one currency should use
/// [netWorthByCurrencyProvider]; there is deliberately no mixed grand total.
final netWorthProvider = StreamProvider<double>((ref) {
  final accountRepo = ref.watch(accountRepoProvider);
  final userRepo = ref.watch(userRepoProvider);
  final accounts = accountRepo.watchAll().map((rows) {
    final grouped = CurrencyAggregation.balances(
      rows.map((row) => row.toEntity()),
      isLiability: _isLiability,
    );
    return {
      for (final entry in grouped.entries) entry.key: entry.value.netWorth,
    };
  });
  return Rx.combineLatest2(
    userRepo.watchCurrentUser(),
    accounts,
    (user, totals) => totals[user?.currencyCode ?? 'PHP']?.toDouble() ?? 0,
  );
});

bool _isLiability(String accountType) =>
    accountType == AccountType.creditCard ||
    accountType == AccountType.loan ||
    accountType == AccountType.bnpl;
