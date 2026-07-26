import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'onboarding_provider.dart';

enum DashboardModule {
  netWorth('Net worth'),
  accounts('Accounts'),
  cashFlow('Income vs expense'),
  budgets('Budgets'),
  spending('Spending by category'),
  activity('Recent and upcoming');

  const DashboardModule(this.label);

  final String label;
}

class DashboardLayoutState {
  const DashboardLayoutState({required this.order, required this.visible});

  static const defaults = DashboardLayoutState(
    order: DashboardModule.values,
    visible: DashboardModule.values,
  );

  final List<DashboardModule> order;
  final List<DashboardModule> visible;

  bool isVisible(DashboardModule module) => visible.contains(module);

  DashboardLayoutState copyWith({
    List<DashboardModule>? order,
    List<DashboardModule>? visible,
  }) {
    return DashboardLayoutState(
      order: order ?? this.order,
      visible: visible ?? this.visible,
    );
  }
}

class DashboardLayoutNotifier extends Notifier<DashboardLayoutState> {
  static const _orderKey = 'dashboard.module_order';
  static const _visibleKey = 'dashboard.visible_modules';
  static const minimumVisible = 4;

  SharedPreferences? _preferences() {
    try {
      return ref.read(sharedPreferencesProvider);
    } on UnimplementedError {
      return null;
    } catch (error) {
      if (error.toString().contains(
        'sharedPreferencesProvider must be overridden before use',
      )) {
        return null;
      }
      rethrow;
    }
  }

  @override
  DashboardLayoutState build() {
    final preferences = _preferences();
    if (preferences == null) return DashboardLayoutState.defaults;

    final order = _decode(preferences.getStringList(_orderKey));
    final visible = _decodeVisible(preferences.getStringList(_visibleKey));
    return DashboardLayoutState(
      order: order,
      visible: visible.length < minimumVisible
          ? DashboardLayoutState.defaults.visible
          : visible,
    );
  }

  Future<void> reorderItem(int oldIndex, int newIndex) async {
    final next = [...state.order];
    final module = next.removeAt(oldIndex);
    next.insert(newIndex, module);
    state = state.copyWith(order: next);
    await _persist();
  }

  Future<bool> setVisible(DashboardModule module, bool value) async {
    final next = [...state.visible];
    if (value) {
      if (!next.contains(module)) next.add(module);
    } else {
      if (next.length <= minimumVisible) return false;
      next.remove(module);
    }
    state = state.copyWith(visible: next);
    await _persist();
    return true;
  }

  Future<void> restoreDefaults() async {
    state = DashboardLayoutState.defaults;
    await _persist();
  }

  List<DashboardModule> _decode(List<String>? raw) {
    final decoded = <DashboardModule>[];
    for (final value in raw ?? const <String>[]) {
      final module = DashboardModule.values
          .where((candidate) => candidate.name == value)
          .firstOrNull;
      if (module != null && !decoded.contains(module)) decoded.add(module);
    }
    for (final module in DashboardModule.values) {
      if (!decoded.contains(module)) decoded.add(module);
    }
    return decoded;
  }

  List<DashboardModule> _decodeVisible(List<String>? raw) {
    if (raw == null) return DashboardLayoutState.defaults.visible;
    final decoded = <DashboardModule>[];
    for (final value in raw) {
      final module = DashboardModule.values
          .where((candidate) => candidate.name == value)
          .firstOrNull;
      if (module != null && !decoded.contains(module)) decoded.add(module);
    }
    return decoded;
  }

  Future<void> _persist() async {
    final preferences = _preferences();
    await preferences?.setStringList(
      _orderKey,
      state.order.map((module) => module.name).toList(),
    );
    await preferences?.setStringList(
      _visibleKey,
      state.visible.map((module) => module.name).toList(),
    );
  }
}

final dashboardLayoutProvider =
    NotifierProvider<DashboardLayoutNotifier, DashboardLayoutState>(
      DashboardLayoutNotifier.new,
    );
