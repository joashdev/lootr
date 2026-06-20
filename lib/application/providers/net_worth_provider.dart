import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/value_objects/field_types.dart';
import 'repo_providers.dart';

final netWorthProvider = StreamProvider<double>((ref) {
  final repo = ref.watch(accountRepoProvider);

  return repo.watchAll().map((accounts) {
    double assets = 0;
    double liabilities = 0;

    for (final acc in accounts) {
      final type = acc.accountType;
      if (type == AccountType.creditCard ||
          type == AccountType.loan ||
          type == AccountType.bnpl) {
        liabilities += acc.balance.abs();
      } else {
        assets += acc.balance;
      }
    }

    return assets - liabilities;
  });
});
