import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/presentation/shared/components/buttons/primary_button.dart';
import 'package:lootr/domain/value_objects/field_types.dart';
import 'package:lootr/presentation/sheets/add_transaction_sheet.dart';
import 'package:lootr/presentation/sheets/quick_actions_sheet.dart';

void main() {
  AddTransactionSheetArgs? openedArgs;
  setUp(() => openedArgs = null);

  Widget host({required bool assistanceEnabled}) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) =>
                        QuickActionsSheet(assistanceEnabled: assistanceEnabled),
                  ),
                  child: const Text('open-sheet'),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/transactions/new',
          builder: (context, state) {
            openedArgs = state.extra as AddTransactionSheetArgs?;
            return Scaffold(appBar: AppBar(), body: const Text('manual-route'));
          },
        ),
        GoRoute(
          path: '/more/settings/ai',
          builder: (context, state) => const Scaffold(body: Text('ai-route')),
        ),
        GoRoute(
          path: '/scan',
          builder: (context, state) => const Scaffold(body: Text('scan-route')),
        ),
      ],
    );
    addTearDown(router.dispose);
    return MaterialApp.router(theme: AppTheme.light, routerConfig: router);
  }

  Future<void> openSheet(
    WidgetTester tester, {
    bool assistanceEnabled = true,
  }) async {
    await tester.pumpWidget(host(assistanceEnabled: assistanceEnabled));
    await tester.tap(find.text('open-sheet'));
    await tester.pumpAndSettle();
  }

  testWidgets('Quick entry exposes every add method', (tester) async {
    await openSheet(tester);

    expect(find.text('Add Transaction'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Coffee ₱180'), findsOneWidget);
    expect(find.byTooltip('Start voice input'), findsOneWidget);
    expect(
      find.widgetWithText(PrimaryButton, 'Review transaction'),
      findsOneWidget,
    );
    expect(find.text('Add manually').hitTestable(), findsOneWidget);
    expect(find.text('Scan receipt').hitTestable(), findsOneWidget);
    expect(find.text('Transfer').hitTestable(), findsOneWidget);
  });

  testWidgets('Manual is primary when assistance is off', (tester) async {
    await openSheet(tester, assistanceEnabled: false);

    expect(find.byType(TextField), findsNothing);
    expect(find.widgetWithText(PrimaryButton, 'Add manually'), findsOneWidget);
    expect(find.text('Scan receipt').hitTestable(), findsOneWidget);
    expect(find.text('Transfer').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Turn on Quick entry'));
    await tester.pumpAndSettle();
    expect(find.text('ai-route'), findsOneWidget);
  });

  testWidgets('tapping Manual opens the full add-transaction flow in one tap', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.tap(find.text('Add manually'));
    await tester.pumpAndSettle();

    expect(find.text('manual-route'), findsOneWidget);
  });

  testWidgets('tapping Scan opens the receipt scan flow', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('Scan receipt'));
    await tester.pumpAndSettle();

    expect(find.text('scan-route'), findsOneWidget);
  });

  testWidgets('Review transaction passes the draft to Quick entry', (
    tester,
  ) async {
    await openSheet(tester);
    await tester.enterText(find.byType(TextField), '  Lunch 250  ');
    await tester.pump();
    await tester.tap(find.text('Review transaction'));
    await tester.pumpAndSettle();

    expect(openedArgs?.startInQuickMode, isTrue);
    expect(openedArgs?.initialQuickText, 'Lunch 250');
  });

  testWidgets('keyboard Go passes the draft to Quick entry', (tester) async {
    await openSheet(tester);
    await tester.enterText(find.byType(TextField), 'Taxi 150');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();

    expect(openedArgs?.initialQuickText, 'Taxi 150');
  });

  testWidgets('Quick entry fits a small phone with the keyboard open', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openSheet(tester);

    await tester.enterText(find.byType(TextField), 'Taxi 150');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    final action = find.text('Review transaction');
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(openedArgs?.initialQuickText, 'Taxi 150');
    expect(tester.takeException(), isNull);
  });

  testWidgets('transfer shortcut opens the manual form in Transfer', (
    tester,
  ) async {
    await openSheet(tester);
    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();

    expect(openedArgs?.initialDirection, TransactionDirection.transfer);
    expect(openedArgs?.startInQuickMode, isFalse);
  });

  testWidgets('close returns to the current screen', (tester) async {
    await openSheet(tester);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.text('open-sheet'), findsOneWidget);
    expect(find.byType(QuickActionsSheet), findsNothing);
  });

  testWidgets('voice input passes recognized text to Quick entry', (
    tester,
  ) async {
    const channel = MethodChannel('plugin.csdcorp.com/speech_to_text');
    final messenger = tester.binding.defaultBinaryMessenger;
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    Future<void> reportSpeech(MethodCall call) async {
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(call),
        null,
      );
      await tester.pump();
    }

    await openSheet(tester);
    await tester.tap(find.byTooltip('Start voice input'));
    await tester.pump();
    expect(calls, containsAllInOrder(['initialize', 'listen']));
    expect(find.byTooltip('Stop listening'), findsOneWidget);

    await reportSpeech(
      const MethodCall(
        'textRecognition',
        '{"alternates":[{"recognizedWords":"Lunch 250","confidence":1}],'
            '"resultType":2}',
      ),
    );
    await tester.tap(find.text('Review transaction'));
    await tester.pumpAndSettle();
    expect(openedArgs?.initialQuickText, 'Lunch 250');

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('open-sheet'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Start voice input'));
    await tester.pump();
    await reportSpeech(const MethodCall('notifyStatus', 'notListening'));
    expect(find.byTooltip('Start voice input'), findsOneWidget);
    expect(calls.where((method) => method == 'initialize'), hasLength(1));
  });
}
