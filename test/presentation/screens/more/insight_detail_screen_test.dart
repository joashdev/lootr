import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/presentation/screens/more/insight_detail_screen.dart';

void main() {
  testWidgets('unknown deterministic insight id never fabricates AI copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: InsightDetailScreen(id: 'top-category')),
      ),
    );

    expect(find.text('Insight unavailable'), findsOneWidget);
    expect(find.text('Unusual Activity'), findsNothing);
    expect(find.textContaining('unusually large transaction'), findsNothing);
  });
}
