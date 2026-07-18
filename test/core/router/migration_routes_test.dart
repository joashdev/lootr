import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lootr/application/providers/onboarding_provider.dart';
import 'package:lootr/core/router/app_router.dart';

class _CompletedOnboarding extends OnboardingNotifier {
  @override
  OnboardingState build() =>
      const OnboardingState(status: OnboardingStatus.completed);
}

void main() {
  late ProviderContainer container;
  late GoRouter router;

  setUp(() {
    container = ProviderContainer(
      overrides: [onboardingProvider.overrideWith(_CompletedOnboarding.new)],
    );
    router = container.read(appRouterProvider);
  });

  tearDown(() => container.dispose());

  test('Data & backup hub matches its static route', () {
    final match = router.configuration.findMatch(
      Uri.parse('/more/settings/data'),
    );
    expect(match.last.route.path, 'settings/data');
  });

  test('Cashew prepare route is not captured as an import run id', () {
    final match = router.configuration.findMatch(
      Uri.parse('/more/settings/data/import-cashew'),
    );
    expect(match.last.route.path, 'import-cashew');
  });

  test('Cashew run and prior summary routes retain their ids', () {
    final run = router.configuration.findMatch(
      Uri.parse('/more/settings/data/import-cashew/run-123'),
    );
    final summary = router.configuration.findMatch(
      Uri.parse('/more/settings/data/imports/run-123'),
    );

    expect(run.last.route.path, ':runId');
    expect(run.pathParameters['runId'], 'run-123');
    expect(summary.last.route.path, 'imports/:runId');
    expect(summary.pathParameters['runId'], 'run-123');
  });
}
