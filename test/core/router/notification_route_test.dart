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
  test(
    '/recurring?filter=subscription matches the recurring deep-link route',
    () {
      final container = ProviderContainer(
        overrides: [onboardingProvider.overrideWith(_CompletedOnboarding.new)],
      );
      addTearDown(container.dispose);

      final GoRouter router = container.read(appRouterProvider);
      final match = router.configuration.findMatch(
        Uri.parse('/recurring?filter=subscription'),
      );

      expect(match.last.route.path, '/recurring');
    },
  );

  test('/recurring/occurrence/:id matches the exact occurrence route', () {
    final container = ProviderContainer(
      overrides: [onboardingProvider.overrideWith(_CompletedOnboarding.new)],
    );
    addTearDown(container.dispose);

    final router = container.read(appRouterProvider);
    final match = router.configuration.findMatch(
      Uri.parse('/recurring/occurrence/occ-1'),
    );

    expect(match.last.route.path, '/recurring/occurrence/:occurrenceId');
  });
}
