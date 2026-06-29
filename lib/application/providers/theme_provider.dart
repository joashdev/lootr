import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'onboarding_provider.dart';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _prefsKey = 'theme_mode';
  bool _loaded = false;

  @override
  ThemeMode build() {
    _loadPersistedMode();
    return ThemeMode.system;
  }

  Future<void> _loadPersistedMode() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = ref.read(sharedPreferencesProvider);
    final raw = prefs.getString(_prefsKey);
    state = switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  void toggle() {
    setMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(_prefsKey, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
