import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/presentation/shared/components/app_snackbar.dart';

void main() {
  Widget wrapWithTheme(Widget child) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Builder(builder: (context) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          child;
        });
        return const Center(child: Text('test'));
      })),
    );
  }

  group('AppSnackBar._SnackBarContent', () {
    testWidgets('neutral variant renders without overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () => AppSnackBar.show(context, 'Test message'),
                  child: const Text('Show'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Test message'), findsOneWidget);
    });

    testWidgets('success variant renders without overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () => AppSnackBar.show(
                    context,
                    'Success!',
                    variant: AppSnackBarVariant.success,
                  ),
                  child: const Text('Show'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Success!'), findsOneWidget);
    });

    testWidgets('error variant with action renders without overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () => AppSnackBar.showError(
                    context,
                    'Transaction deleted',
                    actionLabel: 'UNDO',
                    onAction: () {},
                  ),
                  child: const Text('Show'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Transaction deleted'), findsOneWidget);
      expect(find.text('UNDO'), findsOneWidget);
    });

    testWidgets('warning variant renders without overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () => AppSnackBar.showWarning(
                    context,
                    'Budget nearly exceeded',
                  ),
                  child: const Text('Show'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Budget nearly exceeded'), findsOneWidget);
    });

    testWidgets('long message renders without overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () => AppSnackBar.show(
                    context,
                    'This is a very long snackbar message that might overflow '
                    'on smaller screens if not handled correctly',
                  ),
                  child: const Text('Show'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'This is a very long snackbar message that might overflow '
          'on smaller screens if not handled correctly',
        ),
        findsOneWidget,
      );
    });
  });
}
