import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers/onboarding_provider.dart';
import '../../core/theme/theme.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transfer.dart';
import '../../presentation/screens/budgets/budget_detail_screen.dart';
import '../../presentation/screens/budgets/budgets_screen.dart';
import '../../presentation/screens/budgets/imported_budget_detail_screen.dart';
import '../../presentation/screens/dashboard/dashboard_screen.dart';
import '../../presentation/screens/more/account_detail_screen.dart';
import '../../presentation/screens/more/accounts_screen.dart';
import '../../presentation/screens/more/categories_screen.dart';
import '../../presentation/screens/more/debt_detail_screen.dart';
import '../../presentation/screens/more/debts_screen.dart';
import '../../presentation/screens/more/goal_detail_screen.dart';
import '../../presentation/screens/more/goals_screen.dart';
import '../../presentation/screens/more/household_detail_screen.dart';
import '../../presentation/screens/more/households_screen.dart';
import '../../presentation/screens/more/insight_detail_screen.dart';
import '../../presentation/screens/more/insights_screen.dart';
import '../../presentation/screens/more/more_screen.dart';
import '../../presentation/screens/more/payee_detail_screen.dart';
import '../../presentation/screens/more/payees_screen.dart';
import '../../presentation/screens/more/recurring_detail_screen.dart';
import '../../presentation/screens/more/recurring_screen.dart';
import '../../presentation/screens/more/report_detail_screen.dart';
import '../../presentation/screens/more/reports_screen.dart';
import '../../presentation/screens/more/settings/about_screen.dart';
import '../../presentation/screens/more/settings/ai_logs_screen.dart';
import '../../presentation/screens/more/settings/ai_settings_screen.dart';
import '../../presentation/screens/more/settings/appearance_screen.dart';
import '../../presentation/screens/more/settings/data/cashew_import_prepare_screen.dart';
import '../../presentation/screens/more/settings/data/cashew_migration_run_screen.dart';
import '../../presentation/screens/more/settings/data/data_backup_screen.dart';
import '../../presentation/screens/more/settings/data/migration_run_summary_screen.dart';
import '../../presentation/screens/more/settings/notification_settings_screen.dart';
import '../../presentation/screens/more/settings/profile_screen.dart';
import '../../presentation/screens/more/settings/security_screen.dart';
import '../../presentation/screens/more/settings/sync_settings_screen.dart';
import '../../presentation/screens/ocr/ocr_scan_screen.dart';
import '../../presentation/screens/onboarding/onboarding_screen.dart';
import '../../presentation/screens/transactions/transaction_detail_screen.dart';
import '../../presentation/screens/transactions/transactions_screen.dart';
import '../../presentation/sheets/add_transaction_sheet.dart';
import '../../presentation/shared/layouts/tab_shell.dart';

Page<void> _pushPage(Widget child, {LocalKey? key}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: AppTheme.pagePushCurve),
            ),
        child: child,
      );
    },
    transitionDuration: AppTheme.pagePushDuration,
  );
}

Page<void> _sheetPage(Widget child, {LocalKey? key}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.0, 1.0), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: animation,
                curve: AppTheme.sheetEnterCurve,
              ),
            ),
        child: child,
      );
    },
    transitionDuration: AppTheme.sheetEnterDuration,
    opaque: false,
    barrierDismissible: true,
    barrierColor: Colors.black54,
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final container = ProviderScope.containerOf(context);
      final onboardingState = container.read(onboardingProvider);
      final isOnboarding = state.matchedLocation == '/onboarding';

      if (!onboardingState.completed && !isOnboarding) {
        return '/onboarding';
      }
      if (onboardingState.completed && isOnboarding) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/settings/sync',
        redirect: (context, state) => '/more/settings/sync',
      ),
      GoRoute(
        path: '/recurring',
        redirect: (context, state) {
          final filter = state.uri.queryParameters['filter'];
          final suffix = filter == null ? '' : '?filter=$filter';
          return '/more/recurring$suffix';
        },
      ),
      GoRoute(
        path: '/recurring/:templateId',
        redirect: (context, state) =>
            '/more/recurring/${state.pathParameters['templateId']}',
      ),
      GoRoute(
        path: '/debts/:debtId',
        redirect: (context, state) =>
            '/more/debts/${state.pathParameters['debtId']}',
      ),
      GoRoute(
        path: '/transactions/new',
        pageBuilder: (context, state) {
          final extra = state.extra;
          final args = extra is AddTransactionSheetArgs ? extra : null;
          final tx = extra is Transaction ? extra : args?.initialTransaction;
          final transfer = extra is Transfer ? extra : args?.initialTransfer;
          return _sheetPage(
            AddTransactionSheet(
              initialTransaction: tx,
              initialTransfer: transfer,
              startInQuickMode: args?.startInQuickMode ?? false,
              initialParsedTransaction: args?.initialParsedTransaction,
              initialQuickText: args?.initialQuickText,
            ),
            key: state.pageKey,
          );
        },
      ),
      GoRoute(
        path: '/scan',
        pageBuilder: (context, state) =>
            _pushPage(const OcrScanScreen(), key: state.pageKey),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const OnboardingScreen(),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            TabShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transactions',
                builder: (context, state) => TransactionsScreen(
                  initialModeFilter: state.uri.queryParameters['filter'],
                ),
                routes: [
                  GoRoute(
                    path: ':id',
                    pageBuilder: (context, state) => _pushPage(
                      TransactionDetailScreen(id: state.pathParameters['id']!),
                      key: state.pageKey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/budgets',
                builder: (context, state) => const BudgetsScreen(),
                routes: [
                  GoRoute(
                    path: 'imported/:id',
                    pageBuilder: (context, state) => _pushPage(
                      ImportedBudgetDetailScreen(
                        id: state.pathParameters['id']!,
                        year: int.tryParse(
                          state.uri.queryParameters['year'] ?? '',
                        ),
                        month: int.tryParse(
                          state.uri.queryParameters['month'] ?? '',
                        ),
                      ),
                      key: state.pageKey,
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    pageBuilder: (context, state) => _pushPage(
                      BudgetDetailScreen(id: state.pathParameters['id']!),
                      key: state.pageKey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (context, state) => const MoreScreen(),
                routes: [
                  GoRoute(
                    path: 'accounts',
                    pageBuilder: (context, state) =>
                        _pushPage(const AccountsScreen(), key: state.pageKey),
                    routes: [
                      GoRoute(
                        path: ':id',
                        pageBuilder: (context, state) => _pushPage(
                          AccountDetailScreen(id: state.pathParameters['id']!),
                          key: state.pageKey,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'debts',
                    pageBuilder: (context, state) =>
                        _pushPage(const DebtsScreen(), key: state.pageKey),
                    routes: [
                      GoRoute(
                        path: ':id',
                        pageBuilder: (context, state) => _pushPage(
                          DebtDetailScreen(id: state.pathParameters['id']!),
                          key: state.pageKey,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'goals',
                    pageBuilder: (context, state) =>
                        _pushPage(const GoalsScreen(), key: state.pageKey),
                    routes: [
                      GoRoute(
                        path: ':id',
                        pageBuilder: (context, state) => _pushPage(
                          GoalDetailScreen(id: state.pathParameters['id']!),
                          key: state.pageKey,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'recurring',
                    pageBuilder: (context, state) => _pushPage(
                      RecurringScreen(
                        initialFilter: state.uri.queryParameters['filter'],
                      ),
                      key: state.pageKey,
                    ),
                    routes: [
                      GoRoute(
                        path: ':id',
                        pageBuilder: (context, state) => _pushPage(
                          RecurringDetailScreen(
                            id: state.pathParameters['id']!,
                          ),
                          key: state.pageKey,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'reports',
                    pageBuilder: (context, state) =>
                        _pushPage(const ReportsScreen(), key: state.pageKey),
                    routes: [
                      GoRoute(
                        path: ':type',
                        pageBuilder: (context, state) => _pushPage(
                          ReportDetailScreen(
                            type: state.pathParameters['type']!,
                          ),
                          key: state.pageKey,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'insights',
                    pageBuilder: (context, state) =>
                        _pushPage(const InsightsScreen(), key: state.pageKey),
                    routes: [
                      GoRoute(
                        path: ':id',
                        pageBuilder: (context, state) => _pushPage(
                          InsightDetailScreen(id: state.pathParameters['id']!),
                          key: state.pageKey,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'categories',
                    pageBuilder: (context, state) =>
                        _pushPage(const CategoriesScreen(), key: state.pageKey),
                  ),
                  GoRoute(
                    path: 'payees',
                    pageBuilder: (context, state) =>
                        _pushPage(const PayeesScreen(), key: state.pageKey),
                    routes: [
                      GoRoute(
                        path: ':id',
                        pageBuilder: (context, state) => _pushPage(
                          PayeeDetailScreen(id: state.pathParameters['id']!),
                          key: state.pageKey,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'households',
                    pageBuilder: (context, state) =>
                        _pushPage(const HouseholdsScreen(), key: state.pageKey),
                    routes: [
                      GoRoute(
                        path: ':id',
                        pageBuilder: (context, state) => _pushPage(
                          HouseholdDetailScreen(
                            id: state.pathParameters['id']!,
                          ),
                          key: state.pageKey,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'settings/profile',
                    pageBuilder: (context, state) =>
                        _pushPage(const ProfileScreen(), key: state.pageKey),
                  ),
                  GoRoute(
                    path: 'settings/notifications',
                    pageBuilder: (context, state) => _pushPage(
                      const NotificationSettingsScreen(),
                      key: state.pageKey,
                    ),
                  ),
                  GoRoute(
                    path: 'settings/ai',
                    pageBuilder: (context, state) =>
                        _pushPage(const AiSettingsScreen(), key: state.pageKey),
                  ),
                  GoRoute(
                    path: 'settings/ai-logs',
                    pageBuilder: (context, state) =>
                        _pushPage(const AiLogsScreen(), key: state.pageKey),
                  ),
                  GoRoute(
                    path: 'settings/sync',
                    pageBuilder: (context, state) => _pushPage(
                      const SyncSettingsScreen(),
                      key: state.pageKey,
                    ),
                  ),
                  GoRoute(
                    path: 'settings/data',
                    pageBuilder: (context, state) =>
                        _pushPage(const DataBackupScreen(), key: state.pageKey),
                    routes: [
                      GoRoute(
                        path: 'import-cashew',
                        pageBuilder: (context, state) => _pushPage(
                          const CashewImportPrepareScreen(),
                          key: state.pageKey,
                        ),
                        routes: [
                          GoRoute(
                            path: ':runId',
                            pageBuilder: (context, state) => _pushPage(
                              CashewMigrationRunScreen(
                                runId: state.pathParameters['runId']!,
                              ),
                              key: state.pageKey,
                            ),
                          ),
                        ],
                      ),
                      GoRoute(
                        path: 'imports/:runId',
                        pageBuilder: (context, state) => _pushPage(
                          MigrationRunSummaryScreen(
                            runId: state.pathParameters['runId']!,
                          ),
                          key: state.pageKey,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'settings/appearance',
                    pageBuilder: (context, state) =>
                        _pushPage(const AppearanceScreen(), key: state.pageKey),
                  ),
                  GoRoute(
                    path: 'settings/security',
                    pageBuilder: (context, state) =>
                        _pushPage(const SecurityScreen(), key: state.pageKey),
                  ),
                  GoRoute(
                    path: 'settings/about',
                    pageBuilder: (context, state) =>
                        _pushPage(const AboutScreen(), key: state.pageKey),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
