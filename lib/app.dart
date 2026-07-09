import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/providers/category_seed_provider.dart';
import 'application/providers/notification_provider.dart';
import 'application/providers/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/theme.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  bool _scheduledBootstrap = false;

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    ref.watch(categorySeedProvider);
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    if (!_scheduledBootstrap) {
      _scheduledBootstrap = true;
      Future.microtask(() async {
        final scheduler = ref.read(notificationSchedulerProvider);
        await scheduler.initialize();
        await scheduler.rebuildSchedule();
      });
    }

    ref.listen<String?>(notificationDeepLinkProvider, (previous, next) {
      if (next == null || next.isEmpty) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        router.go(next);
        ref.read(notificationDeepLinkProvider.notifier).state = null;
      });
    });

    return MaterialApp.router(
      title: 'Lootr',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
