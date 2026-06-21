import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lootr/application/providers/onboarding_provider.dart';
import 'package:lootr/core/router/app_router.dart';

/// Onboarding forced to completed so router construction doesn't depend on
/// SharedPreferences and the redirect leaves '/transactions/new' alone.
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

  test('/transactions/new matches the Add sheet route, not /transactions/:id',
      () {
    final match =
        router.configuration.findMatch(Uri.parse('/transactions/new'));
    // Regression guard: before the fix, the shell route ':id' captured "new"
    // and rendered the (empty) transaction detail screen.
    expect(match.last.route.path, '/transactions/new');
  });

  test('a real transaction id still resolves to the detail route', () {
    final match =
        router.configuration.findMatch(Uri.parse('/transactions/abc-123'));
    expect(match.last.route.path, ':id');
  });
}
