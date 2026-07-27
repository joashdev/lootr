import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/application/providers/database_provider.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/presentation/screens/more/settings/ai_logs_screen.dart';

void main() {
  testWidgets('log detail shows method, confidence, payload, and timestamp', (
    tester,
  ) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final createdAt = DateTime(2026, 7, 27, 14, 35, 12);
    await database.aiProcessingLogs.insertOne(
      AiProcessingLogsCompanion.insert(
        id: 'log-1',
        sourceType: 'nlp',
        modelUsed: const Value('regex'),
        extractedPayload: const Value('{"amount":180,"payee":"Market"}'),
        confidenceScore: const Value(0.8),
        createdAt: Value(createdAt),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(theme: AppTheme.light, home: const AiLogsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NLP'), findsOneWidget);
    expect(find.text('regex · 80% confidence'), findsOneWidget);
    await tester.tap(find.text('NLP'));
    await tester.pumpAndSettle();

    expect(find.text('Method: regex'), findsOneWidget);
    expect(find.text('Confidence: 80%'), findsOneWidget);
    expect(
      find.text('Timestamp: ${createdAt.toIso8601String()}'),
      findsOneWidget,
    );
    expect(find.textContaining('"payee": "Market"'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
