import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../application/providers/dashboard_provider.dart';
import '../../../application/providers/sync_providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../shared/components/empty_state.dart';
import '../../shared/components/primary_screen_header.dart';
import '../../sheets/sync_status_sheet.dart';
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
        data: (data) => _DashboardHeader(data: data),
        orElse: () => const PrimaryScreenHeader(title: 'Dashboard'),
      ),
      body: dashboard.when(
        loading: () => const DashboardShimmer(),
        error: (error, _) => _ErrorView(message: error.toString()),
        data: (data) {
          if (data.isEmpty) {
            return _EmptyDashboard(
              onAddTransaction: () => context.push('/transactions/new'),
            );
          }

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
                const SizedBox(height: AppSpacing.space4),
                NetWorthSparkline(data: data),
                const SizedBox(height: AppSpacing.space5),
                AccountSummaryCards(
                  accounts: data.accounts,
                  currencyCode: data.currencyCode,
                ),
                const SizedBox(height: AppSpacing.space5),
                IncomeExpenseStrip(data: data),
                const SizedBox(height: AppSpacing.space5),
                BudgetProgressRings(
                  budgets: data.budgets,
                  currencyCode: data.currencyCode,
                ),
                const SizedBox(height: AppSpacing.space5),
                SpendingDonut(data: data),
                const SizedBox(height: AppSpacing.space5),
                RecentTransactionsList(
                  transactions: data.recentTransactions,
                  currencyCode: data.currencyCode,
                ),
                const SizedBox(height: AppSpacing.space5),
                UpcomingRecurringList(
                  items: data.upcomingRecurring,
                  currencyCode: data.currencyCode,
                ),
                if (data.insights.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.space5),
                  InsightsSection(insights: data.insights),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DashboardHeader extends ConsumerWidget implements PreferredSizeWidget {
  const _DashboardHeader({required this.data});

  final DashboardData data;

  @override
  Size get preferredSize => const Size.fromHeight(PrimaryScreenHeader.height);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStatusIconProvider);
    final lootrColors = context.lootrColors;
    final greetingName = data.displayName?.trim().isNotEmpty == true
        ? ', ${data.displayName!.trim()}'
        : '';

    return PrimaryScreenHeader(
      title: '${data.greeting}$greetingName',
      subtitle: DateFormat('EEEE, MMMM d').format(data.currentDate),
      actions: [
        IconButton(
          tooltip: 'Sync status',
          icon: Icon(
            _syncIcon(syncState),
            color: _syncColor(syncState, lootrColors, context),
          ),
          onPressed: () {
            showModalBottomSheet<void>(
              context: context,
              useRootNavigator: true,
              isScrollControlled: true,
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              builder: (_) => const SyncStatusSheet(),
            );
          },
        ),
        IconButton(
          tooltip: 'Search',
          icon: Icon(
            LucideIcons.search,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Global search is coming soon')),
            );
          },
        ),
      ],
    );
  }

  IconData _syncIcon(SyncIconState state) {
    switch (state) {
      case SyncIconState.synced:
        return LucideIcons.cloudCheck;
      case SyncIconState.pending:
        return LucideIcons.cloudUpload;
      case SyncIconState.failed:
      case SyncIconState.offline:
        return LucideIcons.triangleAlert;
      case SyncIconState.syncing:
        return LucideIcons.loaderCircle;
    }
  }

  Color _syncColor(
    SyncIconState state,
    LootrColorScheme lootrColors,
    BuildContext context,
  ) {
    switch (state) {
      case SyncIconState.synced:
        return lootrColors.success;
      case SyncIconState.pending:
        return lootrColors.warning;
      case SyncIconState.failed:
      case SyncIconState.offline:
        return lootrColors.danger;
      case SyncIconState.syncing:
        return Theme.of(context).colorScheme.primary;
    }
  }
}

class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard({required this.onAddTransaction});

  final VoidCallback onAddTransaction;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      headline: 'Welcome to Lootr',
      subtext: 'Start by adding your accounts and transactions',
      ctaLabel: 'Add your first transaction',
      onCtaPressed: onAddTransaction,
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
