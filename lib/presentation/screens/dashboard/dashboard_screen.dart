import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../application/providers/dashboard_provider.dart';
import '../../../application/providers/sync_providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../shared/components/app_snackbar.dart';
import '../../shared/components/buttons/app_icon_button.dart';
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
              onAddAccount: () => context.push('/more/accounts'),
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
                const SizedBox(height: AppSpacing.space4),
                AccountSummaryCards(
                  accounts: data.accounts,
                  currencyCode: data.currencyCode,
                ),
                const SizedBox(height: AppSpacing.space4),
                IncomeExpenseStrip(data: data),
                const SizedBox(height: AppSpacing.space4),
                BudgetProgressRings(
                  budgets: data.budgets,
                  currencyCode: data.currencyCode,
                ),
                const SizedBox(height: AppSpacing.space4),
                SpendingDonut(data: data),
                const SizedBox(height: AppSpacing.space4),
                RecentTransactionsList(
                  transactions: data.recentTransactions,
                  currencyCode: data.currencyCode,
                ),
                const SizedBox(height: AppSpacing.space4),
                UpcomingRecurringList(
                  items: data.upcomingRecurring,
                  currencyCode: data.currencyCode,
                ),
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
}

class _DashboardHeader extends ConsumerWidget implements PreferredSizeWidget {
  const _DashboardHeader({required this.data});

  final DashboardData data;

  @override
  Size get preferredSize => Size.fromHeight(
    _hasName
        ? PrimaryScreenHeader.heightWithEyebrow
        : PrimaryScreenHeader.height,
  );

  bool get _hasName => data.displayName?.trim().isNotEmpty == true;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStatusIconProvider);
    final lootrColors = context.lootrColors;
    final name = data.displayName?.trim() ?? '';

    return PrimaryScreenHeader(
      // Greeting sits in the eyebrow so a long name (the title) is never
      // truncated by the time-of-day prefix.
      eyebrow: _hasName ? data.greeting : null,
      title: _hasName ? name : data.greeting,
      subtitle: DateFormat('EEEE, MMMM d').format(data.currentDate),
      actions: [
        AppIconButton(
          tooltip: 'Sync status',
          icon: _syncIcon(syncState),
          color: _syncColor(syncState, lootrColors, context),
          onPressed: () {
            showModalBottomSheet<void>(
              context: context,
              useRootNavigator: true,
              isScrollControlled: true,
              builder: (_) => const SyncStatusSheet(),
            );
          },
        ),
        const SizedBox(width: AppSpacing.space2),
        AppIconButton(
          tooltip: 'Search',
          icon: LucideIcons.search,
          onPressed: () {
            AppSnackBar.show(context, 'Global search is coming soon');
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
