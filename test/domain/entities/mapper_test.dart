import 'package:test/test.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/domain/entities/mappers.dart';

void main() {
  final now = DateTime(2026, 6, 19, 12, 0, 0);

  group('Transaction mapper', () {
    test('Row → Entity → Companion round-trip', () {
      final row = TransactionData(
        id: 'tx-1',
        accountId: 'acc-1',
        amount: 100.50,
        transactionDirection: 'expense',
        transactionMode: 'one_time',
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
        syncStatus: 'local_only',
      );
      final entity = row.toEntity();
      final companion = entity.toCompanion();

      expect(companion.id.value, 'tx-1');
      expect(companion.accountId.value, 'acc-1');
      expect(companion.amount.value, 100.50);
      expect(companion.transactionDirection.value, 'expense');
      expect(companion.transactionMode.value, 'one_time');
      expect(companion.occurredAt.value, now);
      expect(companion.syncStatus.present, isFalse);
      expect(companion.lastSyncedAt.present, isFalse);
    });

    test('nullable fields round-trip', () {
      final row = TransactionData(
        id: 'tx-2',
        accountId: 'acc-1',
        categoryId: 'cat-1',
        payeeId: 'pay-1',
        parentTransactionId: 'tx-1',
        recurringTemplateId: 'rt-1',
        amount: 200,
        transactionDirection: 'income',
        transactionMode: 'recurring',
        transactionSubtype: 'salary',
        note: 'Monthly salary',
        metadata: {'source': 'company'},
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
        deletedAt: now,
        syncStatus: 'synced',
        lastSyncedAt: now,
      );
      final entity = row.toEntity();
      expect(entity.categoryId, 'cat-1');
      expect(entity.payeeId, 'pay-1');
      expect(entity.note, 'Monthly salary');
      expect(entity.metadata, {'source': 'company'});
      expect(entity.deletedAt, now);

      final companion = entity.toCompanion();
      expect(companion.categoryId.value, 'cat-1');
      expect(companion.note.value, 'Monthly salary');
      expect(companion.metadata.value, {'source': 'company'});
      expect(companion.deletedAt.value, now);
    });

    test('null nullable fields stay null', () {
      final row = TransactionData(
        id: 'tx-3',
        accountId: 'acc-1',
        amount: 50,
        transactionDirection: 'expense',
        transactionMode: 'one_time',
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
        syncStatus: 'local_only',
      );
      final entity = row.toEntity();
      expect(entity.categoryId, isNull);
      expect(entity.payeeId, isNull);
      expect(entity.note, isNull);
      expect(entity.metadata, isNull);
      expect(entity.deletedAt, isNull);

      final companion = entity.toCompanion();
      expect(companion.categoryId.value, isNull);
      expect(companion.note.value, isNull);
      expect(companion.metadata.value, isNull);
      expect(companion.deletedAt.value, isNull);
    });
  });

  group('Account mapper', () {
    test('Row → Entity → Companion round-trip', () {
      final row = AccountData(
        id: 'acc-1',
        ownerUserId: 'u1',
        name: 'Checking',
        accountType: 'bank',
        balance: 1000,
        currencyCode: 'PHP',
        isArchived: false,
        isHidden: false,
        createdAt: now,
        updatedAt: now,
        syncStatus: 'local_only',
      );
      final entity = row.toEntity();
      expect(entity.balance, 1000);
      expect(entity.currencyCode, 'PHP');
      expect(entity.isArchived, false);

      final companion = entity.toCompanion();
      expect(companion.balance.value, 1000);
      expect(companion.currencyCode.value, 'PHP');
      expect(companion.isArchived.value, false);
    });
  });

  group('Transfer mapper', () {
    test('feeAmount null → 0 in entity', () {
      final row = TransferData(
        id: 't-1',
        sourceAccountId: 'a1',
        destinationAccountId: 'a2',
        amount: 1000,
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
        syncStatus: 'local_only',
        feeAmount: null,
      );
      final entity = row.toEntity();
      expect(entity.feeAmount, 0); // DB null coerced to entity default
    });

    test('feeAmount 25 round-trips', () {
      final row = TransferData(
        id: 't-1',
        sourceAccountId: 'a1',
        destinationAccountId: 'a2',
        amount: 1000,
        feeAmount: 25,
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
        syncStatus: 'local_only',
      );
      final entity = row.toEntity();
      expect(entity.feeAmount, 25);

      final companion = entity.toCompanion();
      expect(companion.feeAmount.value, 25);
    });
  });

  group('User mapper', () {
    test('nullable fields round-trip', () {
      final row = UserData(
        id: 'u1',
        email: 'test@example.com',
        displayName: 'Test',
        currencyCode: 'PHP',
        locale: 'en-PH',
        timezone: 'Asia/Manila',
        aiEnabled: false,
        createdAt: now,
        updatedAt: now,
        syncStatus: 'local_only',
      );
      final entity = row.toEntity();
      expect(entity.email, 'test@example.com');
      expect(entity.currencyCode, 'PHP');
      expect(entity.aiEnabled, false);

      final companion = entity.toCompanion();
      expect(companion.email.value, 'test@example.com');
      expect(companion.currencyCode.value, 'PHP');
      expect(companion.aiEnabled.value, false);
    });
  });

  group('User mapper null fields', () {
    test('null email/displayName round-trip correctly', () {
      final row = UserData(
        id: 'u2',
        email: null,
        displayName: null,
        currencyCode: 'PHP',
        locale: null,
        timezone: null,
        aiEnabled: false,
        createdAt: now,
        updatedAt: now,
        syncStatus: 'local_only',
      );
      final entity = row.toEntity();
      expect(entity.email, isNull);
      expect(entity.displayName, isNull);

      final companion = entity.toCompanion();
      expect(companion.email.value, isNull);
      expect(companion.displayName.value, isNull);
    });
  });
}
