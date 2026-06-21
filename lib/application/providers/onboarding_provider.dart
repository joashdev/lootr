import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// High-level onboarding lifecycle.
enum OnboardingStatus { notStarted, inProgress, completed }

/// Persisted onboarding state.
///
/// [status] tracks whether the user has not started, is part-way through, or
/// has finished onboarding. [step] is the current zero-based page index while
/// [status] is [OnboardingStatus.inProgress].
class OnboardingState {
  final OnboardingStatus status;
  final int step;

  const OnboardingState({
    this.status = OnboardingStatus.notStarted,
    this.step = 0,
  });

  bool get completed => status == OnboardingStatus.completed;

  OnboardingState copyWith({OnboardingStatus? status, int? step}) {
    return OnboardingState(
      status: status ?? this.status,
      step: step ?? this.step,
    );
  }
}

/// Provides the [SharedPreferences] instance.
///
/// Must be overridden at app start (and in tests) with a concrete instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden before use',
  ),
);

class OnboardingNotifier extends Notifier<OnboardingState> {
  static const _statusKey = 'onboarding_status';
  static const _stepKey = 'onboarding_step';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  OnboardingState build() {
    final statusName = _prefs.getString(_statusKey);
    final status = OnboardingStatus.values
        .where((s) => s.name == statusName)
        .firstOrNull;
    final step = _prefs.getInt(_stepKey) ?? 0;
    return OnboardingState(
      status: status ?? OnboardingStatus.notStarted,
      step: step,
    );
  }

  Future<void> _persist(OnboardingState next) async {
    state = next;
    await _prefs.setString(_statusKey, next.status.name);
    await _prefs.setInt(_stepKey, next.step);
  }

  /// Move to a specific step, marking onboarding as in progress.
  Future<void> goToStep(int step) =>
      _persist(state.copyWith(status: OnboardingStatus.inProgress, step: step));

  /// Mark onboarding as started (without changing the current step).
  Future<void> start() => goToStep(state.step);

  /// Complete onboarding.
  Future<void> complete() =>
      _persist(const OnboardingState(status: OnboardingStatus.completed));

  /// Skip onboarding — treated as completed (without demo data).
  Future<void> skip() => complete();

  /// Reset onboarding back to the not-started state (used by tests / dev).
  Future<void> reset() => _persist(const OnboardingState());
}

final onboardingProvider = NotifierProvider<OnboardingNotifier, OnboardingState>(
  OnboardingNotifier.new,
);
