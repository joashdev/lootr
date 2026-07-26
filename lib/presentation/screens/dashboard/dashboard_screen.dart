import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../application/providers/dashboard_provider.dart';
import '../../../application/providers/dashboard_layout_provider.dart';
import '../../../application/providers/sync_providers.dart';
import '../../../core/theme/spacing.dart';
import '../../shared/components/empty_state.dart';
import '../../shared/components/primary_screen_header.dart';
import 'widgets/account_summary_cards.dart';
import 'widgets/budget_progress_rings.dart';
import 'widgets/dashboard_shimmer.dart';
import 'widgets/income_expense_strip.dart';
import 'widgets/insights_section.dart';
import 'widgets/net_worth_sparkline.dart';
import 'widgets/recent_transactions_list.dart';
import 'widgets/safe_to_spend_hero.dart';
import 'widgets/spending_donut.dart';
import 'widgets/upcoming_recurring_list.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: dashboard.maybeWhen(
        data: (data) => _DashboardHeader(
          data: data,
          onCustomize: () => _showDashboardCustomization(context),
        ),
        orElse: () => const PrimaryScreenHeader(title: 'Dashboard'),
      ),
      body: dashboard.when(
        loading: () => const DashboardShimmer(),
        error: (error, _) => _ErrorView(message: error.toString()),
        data: (data) {
          if (data.isEmpty) {
            return _EmptyDashboard(
              onAddAccount: () => context.push('/more/accounts'),
            );
          }

          final layout = ref.watch(dashboardLayoutProvider);
          return RefreshIndicator(
            onRefresh: () => ref.read(syncManagerProvider).sync(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pagePaddingMobile,
                AppSpacing.space3,
                AppSpacing.pagePaddingMobile,
                120,
              ),
              children: [
                SafeToSpendHero(data: data),
                for (final module in layout.order)
                  if (layout.isVisible(module)) ...[
                    const SizedBox(height: AppSpacing.space4),
                    _DashboardModule(module: module, data: data),
                  ],
                if (data.insights.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.space4),
                  InsightsSection(insights: data.insights),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDashboardCustomization(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _DashboardCustomizationSheet(),
    );
  }
}

class _DashboardHeader extends ConsumerWidget implements PreferredSizeWidget {
  const _DashboardHeader({required this.data, required this.onCustomize});

  final DashboardData data;
  final VoidCallback onCustomize;

  @override
  Size get preferredSize => Size.fromHeight(
    _hasName
        ? PrimaryScreenHeader.heightWithEyebrow
        : PrimaryScreenHeader.height,
  );

  bool get _hasName => data.displayName?.trim().isNotEmpty == true;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = data.displayName?.trim() ?? '';

    // Sync status and global search header actions are hidden until those
    // features ship; the sync engine and sheet remain available in code.
    return PrimaryScreenHeader(
      // Greeting sits in the eyebrow so a long name (the title) is never
      // truncated by the time-of-day prefix.
      eyebrow: _hasName ? data.greeting : null,
      title: _hasName ? name : data.greeting,
      subtitle: DateFormat('EEEE, MMMM d').format(data.currentDate),
      actions: [
        IconButton(
          tooltip: 'Customize dashboard',
          onPressed: onCustomize,
          icon: const Icon(Icons.tune),
        ),
      ],
    );
  }
}

class _DashboardModule extends StatelessWidget {
  const _DashboardModule({required this.module, required this.data});

  final DashboardModule module;
  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: ValueKey('dashboard-${module.name}'),
      child: switch (module) {
        DashboardModule.netWorth => NetWorthSparkline(data: data),
        DashboardModule.accounts => AccountSummaryCards(
          accounts: data.accounts,
          currencyCode: data.currencyCode,
        ),
        DashboardModule.cashFlow => IncomeExpenseStrip(data: data),
        DashboardModule.budgets => BudgetProgressRings(
          budgets: data.budgets,
          currencyCode: data.currencyCode,
        ),
        DashboardModule.spending => SpendingDonut(data: data),
        DashboardModule.activity => Column(
          children: [
            RecentTransactionsList(
              transactions: data.recentTransactions,
              currencyCode: data.currencyCode,
            ),
            const SizedBox(height: AppSpacing.space4),
            UpcomingRecurringList(
              items: data.upcomingRecurring,
              currencyCode: data.currencyCode,
            ),
          ],
        ),
      },
    );
  }
}

class _DashboardCustomizationSheet extends ConsumerWidget {
  const _DashboardCustomizationSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(dashboardLayoutProvider);
    final notifier = ref.read(dashboardLayoutProvider.notifier);

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space5,
              0,
              AppSpacing.space3,
              AppSpacing.space2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Customize dashboard',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: notifier.restoreDefaults,
                  child: const Text('Restore defaults'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space5),
            child: Text(
              'Safe to Spend stays first. Keep at least '
              '${DashboardLayoutNotifier.minimumVisible} modules visible.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.space2),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: layout.order.length,
              onReorderItem: notifier.reorderItem,
              itemBuilder: (context, index) {
                final module = layout.order[index];
                final isVisible = layout.isVisible(module);
                return Semantics(
                  key: ValueKey(module.name),
                  label: '${module.label} dashboard module',
                  toggled: isVisible,
                  child: ListTile(
                    leading: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle),
                    ),
                    title: Text(module.label),
                    trailing: Switch(
                      value: isVisible,
                      onChanged: (value) async {
                        final changed = await notifier.setVisible(
                          module,
                          value,
                        );
                        if (!changed && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Keep at least four dashboard modules visible.',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard({required this.onAddAccount});

  final VoidCallback onAddAccount;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      headline: 'Welcome to Lootr',
      subtext: 'Start by adding an account. Transactions come next.',
      ctaLabel: 'Add your first account',
      onCtaPressed: onAddAccount,
      illustration: const Icon(Icons.wallet_outlined, size: 72),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: AppSpacing.space3),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.space2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
