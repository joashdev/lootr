import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/data/repositories/account_repo.dart';
import 'package:lootr/data/repositories/transaction_repo.dart';
import 'package:lootr/data/repositories/transfer_repo.dart';

void main() {
  late AppDatabase database;
  late AccountRepo accounts;
  late TransactionRepo transactions;
  late TransferRepo transfers;

  setUp(() async {
    database = AppDatabase.inMemory();
    accounts = AccountRepo(database);
    transactions = TransactionRepo(database);
    transfers = TransferRepo(database);
    await database.users.insertOne(UsersCompanion.insert(id: 'user'));
  });

  tearDown(() => database.close());

  Future<void> addAccount({
    required String id,
    required String currency,
    required int scale,
    String atoms = '0',
  }) {
    return accounts.create(
      AccountsCompanion.insert(
        id: id,
        ownerUserId: 'user',
        name: id,
        accountType: 'bank',
        balance: const Value(0),
        currencyCode: Value(currency),
        balanceAtoms: Value(atoms),
        currencyPrecision: Value(scale),
      ),
    );
  }

  test('2, 4, and 12-decimal transaction ledgers retain exact atoms', () async {
    for (final fixture in [
      (id: 'two', currency: 'PHP', scale: 2, atoms: '1'),
      (id: 'four', currency: 'CLF', scale: 4, atoms: '1'),
      (id: 'twelve', currency: 'BTC', scale: 12, atoms: '1'),
    ]) {
      await addAccount(
        id: fixture.id,
        currency: fixture.currency,
        scale: fixture.scale,
      );
      await transactions.create(
        TransactionsCompanion.insert(
          id: 'transaction-${fixture.id}',
          accountId: fixture.id,
          amount: 0,
          amountAtoms: Value(fixture.atoms),
          amountScale: Value(fixture.scale),
          currencyCode: Value(fixture.currency),
          transactionDirection: 'income',
          transactionMode: 'one_time',
          occurredAt: DateTime(2026, 7, 18),
        ),
      );

      final account = await (database.select(
        database.accounts,
      )..where((row) => row.id.equals(fixture.id))).getSingle();
      expect(account.balanceAtoms, fixture.atoms);
      expect(account.currencyPrecision, fixture.scale);
    }
  });

  test('coefficients larger than 64 bits remain authoritative', () async {
    const atoms = '123456789012345678901234567890';
    await addAccount(id: 'large', currency: 'XTS', scale: 12);

    await transactions.create(
      TransactionsCompanion.insert(
        id: 'large-transaction',
        accountId: 'large',
        amount: 0,
        amountAtoms: const Value(atoms),
        amountScale: const Value(12),
        currencyCode: const Value('XTS'),
        transactionDirection: 'income',
        transactionMode: 'one_time',
        occurredAt: DateTime(2026, 7, 18),
      ),
    );

    expect(await accounts.getExactBalance('large'), hasAtoms(atoms, 12, 'XTS'));
  });

  test('precision-losing account mutation is rejected atomically', () async {
    await addAccount(id: 'boundary', currency: 'PHP', scale: 2);

    await expectLater(
      transactions.create(
        TransactionsCompanion.insert(
          id: 'too-precise',
          accountId: 'boundary',
          amount: 0.0001,
          amountAtoms: const Value('1'),
          amountScale: const Value(4),
          currencyCode: const Value('PHP'),
          transactionDirection: 'income',
          transactionMode: 'one_time',
          occurredAt: DateTime(2026, 7, 18),
        ),
      ),
      throwsStateError,
    );

    expect(await database.select(database.transactions).get(), isEmpty);
    expect(await accounts.getExactBalance('boundary'), hasAtoms('0', 2, 'PHP'));
  });

  test(
    'account precision and currency cannot silently reinterpret atoms',
    () async {
      await addAccount(
        id: 'account-boundary',
        currency: 'CLF',
        scale: 4,
        atoms: '1',
      );

      await expectLater(
        accounts.update(
          const AccountsCompanion(
            id: Value('account-boundary'),
            currencyPrecision: Value(2),
          ),
        ),
        throwsStateError,
      );
      await expectLater(
        accounts.update(
          const AccountsCompanion(
            id: Value('account-boundary'),
            currencyCode: Value('USD'),
          ),
        ),
        throwsStateError,
      );

      expect(
        await accounts.getExactBalance('account-boundary'),
        hasAtoms('1', 4, 'CLF'),
      );
    },
  );

  test(
    'same-currency transfer uses exact equal legs at account scales',
    () async {
      await addAccount(
        id: 'same-source',
        currency: 'USD',
        scale: 2,
        atoms: '1000',
      );
      await addAccount(id: 'same-destination', currency: 'USD', scale: 4);

      await transfers.create(
        TransfersCompanion.insert(
          id: 'same-transfer',
          sourceAccountId: 'same-source',
          destinationAccountId: 'same-destination',
          amount: 1.2,
          sourceAmountAtoms: const Value('120'),
          sourceAmountScale: const Value(2),
          sourceCurrencyCode: const Value('USD'),
          destinationAmountAtoms: const Value('12000'),
          destinationAmountScale: const Value(4),
          destinationCurrencyCode: const Value('USD'),
          occurredAt: DateTime(2026, 7, 18),
        ),
      );

      expect(
        await accounts.getExactBalance('same-source'),
        hasAtoms('880', 2, 'USD'),
      );
      expect(
        await accounts.getExactBalance('same-destination'),
        hasAtoms('12000', 4, 'USD'),
      );
    },
  );

  test(
    'cross-currency transfer credits its distinct destination leg',
    () async {
      await addAccount(
        id: 'cross-source',
        currency: 'USD',
        scale: 2,
        atoms: '10000',
      );
      await addAccount(id: 'cross-destination', currency: 'BTC', scale: 12);

      await transfers.create(
        TransfersCompanion.insert(
          id: 'cross-transfer',
          sourceAccountId: 'cross-source',
          destinationAccountId: 'cross-destination',
          amount: 25,
          sourceAmountAtoms: const Value('2500'),
          sourceAmountScale: const Value(2),
          sourceCurrencyCode: const Value('USD'),
          destinationAmountAtoms: const Value('37500000'),
          destinationAmountScale: const Value(12),
          destinationCurrencyCode: const Value('BTC'),
          occurredAt: DateTime(2026, 7, 18),
        ),
      );

      expect(
        await accounts.getExactBalance('cross-source'),
        hasAtoms('7500', 2, 'USD'),
      );
      expect(
        await accounts.getExactBalance('cross-destination'),
        hasAtoms('37500000', 12, 'BTC'),
      );

      await accounts.recalcBalance('cross-source');
      await accounts.recalcBalance('cross-destination');
      expect(
        await accounts.getExactBalance('cross-source'),
        hasAtoms('-2500', 2, 'USD'),
      );
      expect(
        await accounts.getExactBalance('cross-destination'),
        hasAtoms('37500000', 12, 'BTC'),
      );
    },
  );

  test('cross-currency transfer never infers its destination amount', () async {
    await addAccount(
      id: 'implicit-source',
      currency: 'USD',
      scale: 2,
      atoms: '10000',
    );
    await addAccount(id: 'implicit-destination', currency: 'BTC', scale: 12);

    await expectLater(
      transfers.create(
        TransfersCompanion.insert(
          id: 'implicit-transfer',
          sourceAccountId: 'implicit-source',
          destinationAccountId: 'implicit-destination',
          amount: 25,
          occurredAt: DateTime(2026, 7, 18),
        ),
      ),
      throwsStateError,
    );
    expect(await database.select(database.transfers).get(), isEmpty);
  });
}

Matcher hasAtoms(String atoms, int scale, String currency) => isA<dynamic>()
    .having((value) => value.coefficient.toString(), 'atoms', atoms)
    .having((value) => value.scale, 'scale', scale)
    .having((value) => value.currencyCode, 'currency', currency);
