import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'application/providers/onboarding_provider.dart';
import 'core/theme/spacing.dart';
import 'core/theme/theme.dart';
import 'core/theme/typography.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Offline-first: Geist / Geist Mono ship as bundled assets, so never let
  // google_fonts reach out over HTTP to fetch them at runtime.
  GoogleFonts.config.allowRuntimeFetching = false;

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  runApp(const AppBootstrap());
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key, this.sharedPreferencesFuture});

  final Future<SharedPreferences>? sharedPreferencesFuture;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late final Future<SharedPreferences> _prefsFuture;

  @override
  void initState() {
    super.initState();
    _prefsFuture =
        widget.sharedPreferencesFuture ?? SharedPreferences.getInstance();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: _prefsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(snapshot.requireData),
            ],
            child: const App(),
          );
        }

        return MaterialApp(
          title: 'Lootr',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          debugShowCheckedModeBanner: false,
          home: StartupLoadingScreen(error: snapshot.error),
        );
      },
    );
  }
}

class StartupLoadingScreen extends StatelessWidget {
  const StartupLoadingScreen({super.key, this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.space6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasError)
                  const Icon(Icons.error_outline, size: 40)
                else
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                const SizedBox(height: AppSpacing.space4),
                Text(
                  hasError ? 'Unable to start Lootr' : 'Starting Lootr...',
                  style: AppTypography.h2,
                  textAlign: TextAlign.center,
                ),
                if (hasError) ...[
                  const SizedBox(height: AppSpacing.space2),
                  Text(
                    error.toString(),
                    style: AppTypography.body,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
