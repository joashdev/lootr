import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/application/providers/app_info_provider.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/presentation/screens/more/settings/about_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  testWidgets('warns about privacy before opening a GitHub bug report', (
    tester,
  ) async {
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
    await tester.tap(find.text('Report a bug'));
    await tester.pumpAndSettle();

    expect(find.text('Report a public bug'), findsOneWidget);
    expect(find.textContaining('GitHub issues are public'), findsOneWidget);
    expect(launchedUri, isNull);

    await tester.tap(find.text('Continue to GitHub'));
    await tester.pumpAndSettle();

    expect(launchedUri?.path, '/joashdev/lootr/issues/new');
    expect(launchedUri?.queryParameters['body'], contains('Build: 42'));

    launchedUri = null;
    await tester.tap(find.text('License & source · AGPL-3.0'));
    await tester.pumpAndSettle();

    expect(find.text('Lootr license'), findsOneWidget);
    expect(find.textContaining('without any warranty'), findsOneWidget);
    await tester.tap(find.text('View license & source'));
    await tester.pumpAndSettle();

    expect(launchedUri?.path, '/joashdev/lootr/blob/main/LICENSE');
  });
}
