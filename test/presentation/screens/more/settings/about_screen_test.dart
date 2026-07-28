import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/application/providers/app_info_provider.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/presentation/screens/more/settings/about_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  testWidgets('opens the in-app public feedback composer', (tester) async {
    Uri? launchedUri;
    final packageInfo = PackageInfo(
      appName: 'Lootr',
      packageName: 'com.lootr.app',
      version: '0.1.0-alpha.1',
      buildNumber: '42',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          packageInfoProvider.overrideWith((ref) async => packageInfo),
          externalUrlLauncherProvider.overrideWithValue((uri) async {
            launchedUri = uri;
            return true;
          }),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const AboutScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Version 0.1.0-alpha.1 (Build 42)'), findsOneWidget);
    await tester.tap(find.text('Send feedback'));
    await tester.pumpAndSettle();

    expect(find.text('Send public feedback'), findsOneWidget);
    expect(find.text('Bug'), findsOneWidget);
    expect(find.text('Feature'), findsOneWidget);
    expect(find.text('Layout'), findsOneWidget);
    expect(find.textContaining('This report will be public'), findsOneWidget);
    expect(
      find.text('Report a security vulnerability privately'),
      findsOneWidget,
    );
    expect(launchedUri, isNull);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    await tester.tap(find.text('License & source · AGPL-3.0'));
    await tester.pumpAndSettle();

    expect(find.text('Lootr license'), findsOneWidget);
    expect(find.textContaining('without any warranty'), findsOneWidget);
    await tester.tap(find.text('View license & source'));
    await tester.pumpAndSettle();

    expect(launchedUri?.path, '/joashdev/lootr/blob/main/LICENSE');
  });
}
