import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/mappers.dart';
import '../../domain/value_objects/field_types.dart';
import 'repo_providers.dart';

final accountsProvider = StreamProvider<List<Account>>((ref) {
  final repo = ref.watch(accountRepoProvider);
  return repo.watchAll().map((rows) => rows.map((r) => r.toEntity()).toList());
});

final accountTypesProvider = Provider<List<String>>(
  (ref) => const [
    AccountType.cash,
    AccountType.bank,
    AccountType.ewallet,
    AccountType.savings,
    AccountType.investment,
    AccountType.crypto,
    AccountType.creditCard,
    AccountType.loan,
    AccountType.bnpl,
  ],
);
