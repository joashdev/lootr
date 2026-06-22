import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../application/providers/demo_data_provider.dart';
import '../../../application/providers/onboarding_provider.dart';
import '../../../application/providers/repo_providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../data/database/app_database.dart';
import '../../shared/components/buttons/ghost_button.dart';
import '../../shared/components/buttons/primary_button.dart';
import '../../shared/components/inputs/app_text_field.dart';
import 'widgets/onboarding_step.dart';
import 'widgets/step_indicator.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  static const supportedCurrencies = ['PHP', 'USD', 'EUR', 'GBP', 'JPY', 'SGD'];

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _stepCount = 4;

  final _pageController = PageController();
  final _nameController = TextEditingController();

  int _currentStep = 0;
  String _currency = 'PHP';
  bool _loadDemoData = true;
  bool _isSubmitting = false;
  bool _isSubmittingDemoData = false;

  static const _setupStepIndex = _stepCount - 1;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(onboardingProvider.notifier).start());
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentStep = index);
    ref.read(onboardingProvider.notifier).goToStep(index);
  }

  void _next() {
    if (_currentStep < _stepCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    } else {
      _finish(loadDemoData: _loadDemoData);
    }
  }

  void _skipToSetup() {
    setState(() {
      _currentStep = _setupStepIndex;
      _loadDemoData = false;
    });
    _pageController.animateToPage(
      _setupStepIndex,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finish({required bool loadDemoData}) async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _isSubmittingDemoData = loadDemoData;
    });

    try {
      await _saveProfile();
      if (loadDemoData) {
        await ref.read(demoDataProvider.notifier).seed();
      }
      await ref.read(onboardingProvider.notifier).complete();

      if (!mounted) return;
      context.go('/');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isSubmittingDemoData = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    final repo = ref.read(userRepoProvider);
    final name = _normalizeDisplayName(_nameController.text);
    final existing = await repo.getCurrentUser();

    _nameController.value = _nameController.value.copyWith(
      text: name,
      selection: TextSelection.collapsed(offset: name.length),
      composing: TextRange.empty,
    );

    if (existing == null) {
      await repo.create(
        UsersCompanion.insert(
          id: 'local-user-1',
          displayName: Value(name.isEmpty ? null : name),
          currencyCode: Value(_currency),
        ),
      );
    } else {
      await repo.update(
        UsersCompanion(
          id: Value(existing.id),
          displayName: Value(name.isEmpty ? existing.displayName : name),
          currencyCode: Value(_currency),
        ),
      );
    }
  }

  String _normalizeDisplayName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
  }

  bool _canProceed() {
    if (_currentStep == _setupStepIndex) {
      return _nameController.text.trim().isNotEmpty;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final loadingMessage = _isSubmittingDemoData
        ? 'Setting up your demo workspace...'
        : 'Setting up your empty workspace...';

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              AbsorbPointer(
                absorbing: _isSubmitting,
                child: Column(
                  children: [
                    _TopBar(
                      showSkip: !_isSubmitting && _currentStep != _setupStepIndex,
                      onSkip: _skipToSetup,
                    ),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: _onPageChanged,
                        children: [
                          const OnboardingStep(
                            key: ValueKey('onboarding-step-0'),
                            icon: LucideIcons.wallet,
                            title: 'Welcome to Lootr',
                            description:
                                'Your personal finance tracker. Private, '
                                'offline-first, always in control.',
                          ),
                          const OnboardingStep(
                            key: ValueKey('onboarding-step-1'),
                            icon: LucideIcons.receiptText,
                            title: 'Track every peso',
                            description:
                                'Quick-add transactions with text or voice. '
                                'No bank connections needed.',
                          ),
                          const OnboardingStep(
                            key: ValueKey('onboarding-step-2'),
                            icon: LucideIcons.pieChart,
                            title: 'Plan your spending',
                            description:
                                'Set budgets, track goals, and see where your '
                                'money goes.',
                          ),
                          OnboardingStep(
                            key: const ValueKey('onboarding-step-3'),
                            icon: LucideIcons.userRound,
                            title: 'Set up your profile',
                            description:
                                'A couple of details to get you started.',
                            child: _SetupForm(
                              nameController: _nameController,
                              currency: _currency,
                              loadDemoData: _loadDemoData,
                              onNameChanged: (value) {
                                final normalized = _normalizeDisplayName(value);
                                if (normalized == value) return;
                                _nameController.value = TextEditingValue(
                                  text: normalized,
                                  selection: TextSelection.collapsed(
                                    offset: normalized.length,
                                  ),
                                );
                              },
                              onCurrencyChanged: (value) =>
                                  setState(() => _currency = value),
                              onDemoDataChanged: (value) =>
                                  setState(() => _loadDemoData = value),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.space6),
                      child: Column(
                        children: [
                          StepIndicator(
                            count: _stepCount,
                            currentIndex: _currentStep,
                          ),
                          const SizedBox(height: AppSpacing.space6),
                          PrimaryButton(
                            label: _currentStep == _stepCount - 1
                                ? 'Get Started'
                                : 'Next',
                            isLoading: _isSubmitting,
                            onPressed:
                                _isSubmitting || !_canProceed() ? null : _next,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_isSubmitting) _SubmissionOverlay(message: loadingMessage),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmissionOverlay extends StatelessWidget {
  const _SubmissionOverlay({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lootrColors = context.lootrColors;

    return Positioned.fill(
      child: ColoredBox(
        color: colorScheme.surface.withValues(alpha: 0.88),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(AppSpacing.space6),
            padding: const EdgeInsets.all(AppSpacing.space6),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: AppSpacing.space4),
                Text(
                  message,
                  style: AppTypography.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.space2),
                Text(
                  'This should only take a moment.',
                  style: AppTypography.caption.copyWith(
                    color: lootrColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.showSkip, required this.onSkip});

  final bool showSkip;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space3,
        vertical: AppSpacing.space2,
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: showSkip
            ? GhostButton(label: 'Skip', isExpanded: false, onPressed: onSkip)
            : const SizedBox(height: 44),
      ),
    );
  }
}

class _SetupForm extends StatelessWidget {
  const _SetupForm({
    required this.nameController,
    required this.currency,
    required this.loadDemoData,
    required this.onNameChanged,
    required this.onCurrencyChanged,
    required this.onDemoDataChanged,
  });

  final TextEditingController nameController;
  final String currency;
  final bool loadDemoData;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onCurrencyChanged;
  final ValueChanged<bool> onDemoDataChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lootrColors = context.lootrColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Label('Display name'),
        const SizedBox(height: AppSpacing.space2),
        AppTextField(
          controller: nameController,
          hintText: 'Your name',
          onChanged: onNameChanged,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: AppSpacing.space5),
        const _Label('Currency'),
        const SizedBox(height: AppSpacing.space2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: colorScheme.outline),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: const ValueKey('currency-dropdown'),
              value: currency,
              isExpanded: true,
              borderRadius: BorderRadius.circular(AppRadius.md),
              items: [
                for (final code in OnboardingScreen.supportedCurrencies)
                  DropdownMenuItem(value: code, child: Text(code)),
              ],
              onChanged: (value) {
                if (value != null) onCurrencyChanged(value);
              },
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.space5),
        Container(
          padding: const EdgeInsets.all(AppSpacing.space4),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: colorScheme.outline),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Load demo data', style: AppTypography.bodyMedium),
                    const SizedBox(height: 2),
                    Text(
                      'Explore the app with sample accounts and transactions.',
                      style: AppTypography.caption.copyWith(
                        color: lootrColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.space3),
              Switch(
                key: const ValueKey('demo-data-toggle'),
                value: loadDemoData,
                onChanged: onDemoDataChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: AppTypography.captionMedium),
    );
  }
}
