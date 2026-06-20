import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingState {
  final bool completed;
  final bool skipped;

  const OnboardingState({this.completed = false, this.skipped = false});
}

class OnboardingNotifier extends Notifier<OnboardingState> {
  @override
  OnboardingState build() => const OnboardingState();

  void complete() => state = const OnboardingState(completed: true);
  void skip() => state = const OnboardingState(skipped: true);
  void reset() => state = const OnboardingState();
}

final onboardingProvider = NotifierProvider<OnboardingNotifier, OnboardingState>(
  OnboardingNotifier.new,
);
