import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/theme.dart';
import '../../presentation/screens/budgets/budget_detail_screen.dart';
import '../../presentation/screens/budgets/budgets_screen.dart';
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
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: AppTheme.pagePushCurve,
        )),
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
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.0, 1.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: AppTheme.sheetEnterCurve,
        )),
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
    routes: [
      // Deep-link redirects for spec paths → actual registered routes
      GoRoute(
        path: '/settings/sync',
        redirect: (context, state) => '/more/settings/sync',
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

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            TabShell(navigationShell: navigationShell),
        branches: [
          // Tab 1 — Dashboard
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),

          // Tab 2 — Transactions
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transactions',
                builder: (context, state) => const TransactionsScreen(),
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

          // Tab 3 — Budgets
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/budgets',
                builder: (context, state) => const BudgetsScreen(),
                routes: [
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

          // Tab 4 — More
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
                    pageBuilder: (context, state) =>
                        _pushPage(const RecurringScreen(), key: state.pageKey),
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
                          InsightDetailScreen(
                            id: state.pathParameters['id']!,
                          ),
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
                    pageBuilder: (context, state) => _pushPage(
                      const HouseholdsScreen(),
                      key: state.pageKey,
                    ),
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
                    path: 'settings',
                    pageBuilder: (context, state) =>
                        _pushPage(const ProfileScreen(), key: state.pageKey),
                    routes: [
                      GoRoute(
                        path: 'notifications',
                        pageBuilder: (context, state) => _pushPage(
                          const NotificationSettingsScreen(),
                          key: state.pageKey,
                        ),
                      ),
                      GoRoute(
                        path: 'ai',
                        pageBuilder: (context, state) =>
                            _pushPage(const AiSettingsScreen(),
                                key: state.pageKey),
                        routes: [
                          GoRoute(
                            path: 'logs',
                            pageBuilder: (context, state) => _pushPage(
                              const AiLogsScreen(),
                              key: state.pageKey,
                            ),
                          ),
                        ],
                      ),
                      GoRoute(
                        path: 'sync',
                        pageBuilder: (context, state) => _pushPage(
                          const SyncSettingsScreen(),
                          key: state.pageKey,
                        ),
                      ),
                      GoRoute(
                        path: 'appearance',
                        pageBuilder: (context, state) => _pushPage(
                          const AppearanceScreen(),
                          key: state.pageKey,
                        ),
                      ),
                      GoRoute(
                        path: 'security',
                        pageBuilder: (context, state) => _pushPage(
                          const SecurityScreen(),
                          key: state.pageKey,
                        ),
                      ),
                      GoRoute(
                        path: 'about',
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
      ),

      // Modal / sheet routes (outside ShellRoute)
      GoRoute(
        path: '/transactions/new',
        pageBuilder: (context, state) =>
            _sheetPage(const AddTransactionSheet(), key: state.pageKey),
      ),
      GoRoute(
        path: '/scan',
        pageBuilder: (context, state) =>
            _pushPage(const OcrScanScreen(), key: state.pageKey),
      ),

      // Onboarding
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) =>
            _pushPage(const OnboardingScreen(), key: state.pageKey),
      ),
    ],
  );
});
