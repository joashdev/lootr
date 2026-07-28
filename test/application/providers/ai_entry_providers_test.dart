import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/application/providers/ai_entry_providers.dart';
import 'package:lootr/application/providers/ai_settings_provider.dart';
import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/domain/value_objects/result.dart';

Future<List<AiProcessingLogData>> _waitForLogs(
  AppDatabase database,
  int count,
) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    final logs = await database.select(database.aiProcessingLogs).get();
    if (logs.length >= count) return logs;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return database.select(database.aiProcessingLogs).get();
}

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.inMemory();
  });

  tearDown(() async {
    await database.close();
  });

  test('persisted setting rebuilds ParseNL without an app restart', () async {
    await database.users.insertOne(
      UsersCompanion.insert(id: 'user-1', aiEnabled: const Value(false)),
    );
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);

    final disabled = container.read(parseNLProvider)('coffee 180 cash');
    expect(disabled, isA<Failure>());

    await container.read(aiSettingsProvider.notifier).toggleAi();

    expect(container.read(smartEntryAssistanceEnabledProvider), isTrue);
    final enabled = container.read(parseNLProvider)('coffee 180 cash');
    expect(enabled, isA<Success>());

    final logs = await _waitForLogs(database, 1);
    final nlp = logs.singleWhere((log) => log.sourceType == 'nlp');
    expect(nlp.modelUsed, 'regex');
    expect(nlp.extractedPayload, isNotEmpty);
    expect(nlp.confidenceScore, isNotNull);
    expect(nlp.createdAt, isNotNull);
  });

  test('OCR and categorizer factories write complete local logs', () async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        aiEnabledProvider.overrideWith((ref) => true),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(categorizerProvider, (_, _) {});
    addTearDown(subscription.close);

    await container.read(runOCRProvider)('/missing/receipt.jpg');
    final categorizer = await container.read(categorizerProvider.future);
    final suggestion = await categorizer.suggest(
      amount: 250,
      payee: 'Market',
      note: 'weekly groceries',
      direction: 'expense',
    );

    expect(suggestion?.categoryId, 'Groceries');
    final logs = await _waitForLogs(database, 2);
    for (final source in const ['ocr', 'categorization']) {
      final log = logs.singleWhere(
        (candidate) => candidate.sourceType == source,
      );
      expect(log.modelUsed, isNotEmpty);
      expect(log.extractedPayload, isNotEmpty);
      expect(log.confidenceScore, isNotNull);
      expect(log.createdAt, isNotNull);
    }
  });

  test('payee history keeps income and expense categories separate', () async {
    await database.users.insertOne(UsersCompanion.insert(id: 'user-1'));
    await database.accounts.insertOne(
      AccountsCompanion.insert(
        id: 'account-1',
        ownerUserId: 'user-1',
        name: 'Cash',
        accountType: 'cash',
      ),
    );
    await database.categories.insertAll([
      CategoriesCompanion.insert(
        id: 'category-income',
        name: 'Salary',
        categoryGroup: 'income',
      ),
      CategoriesCompanion.insert(
        id: 'category-expense',
        name: 'Shopping',
        categoryGroup: 'expense',
      ),
    ]);
    await database.payees.insertOne(
      PayeesCompanion.insert(id: 'payee-1', normalizedName: 'acme'),
    );
    await database.transactions.insertAll([
      TransactionsCompanion.insert(
        id: 'income-1',
        accountId: 'account-1',
        categoryId: const Value('category-income'),
        payeeId: const Value('payee-1'),
        amount: 1000,
        transactionDirection: 'income',
        transactionMode: 'one_time',
        occurredAt: DateTime(2026, 7, 1),
      ),
      TransactionsCompanion.insert(
        id: 'expense-1',
        accountId: 'account-1',
        categoryId: const Value('category-expense'),
        payeeId: const Value('payee-1'),
        amount: 50,
        transactionDirection: 'expense',
        transactionMode: 'one_time',
        occurredAt: DateTime(2026, 7, 2),
      ),
    ]);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        aiEnabledProvider.overrideWith((ref) => true),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(categorizerProvider, (_, _) {});
    addTearDown(subscription.close);

    final categorizer = await container.read(categorizerProvider.future);

    expect(
      (await categorizer.suggest(
        payee: 'Acme',
        direction: 'income',
      ))?.categoryId,
      'category-income',
    );
    expect(
      (await categorizer.suggest(
        payee: 'Acme',
        direction: 'expense',
      ))?.categoryId,
      'category-expense',
    );
  });

  test(
    'disabled OCR pipeline and categorizer bypass processing and logs',
    () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiEnabledProvider.overrideWith((ref) => false),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(categorizerProvider, (_, _) {});
      addTearDown(subscription.close);

      final ocrResult = await container.read(runOCRProvider)('/receipt.jpg');
      final pipelineResult = await container
          .read(ocrPipelineProvider)
          .process('/receipt.jpg');
      final categorizer = await container.read(categorizerProvider.future);
      final suggestion = await categorizer.suggest(
        payee: 'Market',
        note: 'weekly groceries',
      );

      expect(ocrResult, isA<Failure>());
      expect(pipelineResult.payload.rawText, isEmpty);
      expect(suggestion, isNull);
      expect(await database.select(database.aiProcessingLogs).get(), isEmpty);
    },
  );
}
