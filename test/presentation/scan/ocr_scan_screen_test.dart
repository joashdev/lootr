import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/application/providers/ai_settings_provider.dart';
import 'package:lootr/ai/ocr_pipeline.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/domain/use_cases/run_ocr.dart';
import 'package:lootr/presentation/screens/ocr/ocr_scan_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  group('OcrScanScreen', () {
    testWidgets('renders capture controls and falls back without a camera', (
      tester,
    ) async {
      // Inject a deterministic OCR pipeline so no platform channel is touched.
      final runOcr = RunOCR(
        pipeline: OCRPipeline(
          textExtractor: (_) async => const ['Receipt', 'TOTAL 250.00'],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [aiEnabledProvider.overrideWith((ref) => true)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: OcrScanScreen(runOcr: runOcr),
          ),
        ),
      );
      await tester.pump();

      // Capture button, gallery picker and flash toggle are present.
      expect(find.byIcon(LucideIcons.camera), findsOneWidget);
      expect(find.byIcon(LucideIcons.image), findsOneWidget);
      expect(find.byIcon(LucideIcons.zapOff), findsOneWidget);

      // No camera in the test environment -> graceful fallback prompt.
      expect(find.byIcon(LucideIcons.receipt), findsOneWidget);
    });

    testWidgets('flash toggle flips its icon', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [aiEnabledProvider.overrideWith((ref) => true)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const OcrScanScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(LucideIcons.zapOff), findsOneWidget);
      await tester.tap(find.byIcon(LucideIcons.zapOff));
      await tester.pump();
      expect(find.byIcon(LucideIcons.zap), findsOneWidget);
    });

    testWidgets('disabled assistance blocks receipt entry', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [aiEnabledProvider.overrideWith((ref) => false)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const OcrScanScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.textContaining('Smart Entry Assistance is off'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, LucideIcons.image),
            )
            .onPressed,
        isNull,
      );
    });
  });
}
