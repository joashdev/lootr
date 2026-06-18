import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/screens/dashboard/dashboard_screen.dart';
import '../../presentation/screens/onboarding/onboarding_screen.dart';
import '../../presentation/shared/layouts/tab_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const TabShell(),
        routes: [
          GoRoute(
            path: 'dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
    ],
  );
});
