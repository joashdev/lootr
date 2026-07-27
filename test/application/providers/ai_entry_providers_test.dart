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
