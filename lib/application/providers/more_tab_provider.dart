import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ai_settings_provider.dart';

class MoreItem {
  final String label;
  final String? icon;
  final String route;
  final bool enabled;

  const MoreItem({
    required this.label,
    this.icon,
    required this.route,
    this.enabled = true,
  });
}

class MoreSectionGroup {
  final String header;
  final List<MoreItem> items;

  const MoreSectionGroup({required this.header, required this.items});
}

final moreTabProvider = Provider<List<MoreSectionGroup>>((ref) {
  final aiEnabled = ref.watch(aiEnabledProvider);
  final moreList = <MoreSectionGroup>[
    const MoreSectionGroup(
      header: 'Financial',
      items: [
        MoreItem(label: 'Accounts', icon: 'wallet', route: '/more/accounts'),
        MoreItem(
          label: 'Debts & Lending',
          icon: 'hand-coins',
          route: '/more/debts',
        ),
        MoreItem(label: 'Goals', icon: 'target', route: '/more/goals'),
        MoreItem(label: 'Recurring', icon: 'repeat', route: '/more/recurring'),
      ],
    ),
    MoreSectionGroup(
      header: 'Insights',
      items: [
        MoreItem(label: 'Reports', icon: 'chart-bar', route: '/more/reports'),
        MoreItem(
          label: 'Insights',
          icon: 'sparkles',
          route: '/more/insights',
          enabled: aiEnabled,
        ),
      ],
    ),
    const MoreSectionGroup(
      header: 'Manage',
      items: [
        MoreItem(label: 'Categories', icon: 'tag', route: '/more/categories'),
        MoreItem(label: 'Payees', icon: 'address-book', route: '/more/payees'),
        MoreItem(label: 'Households', icon: 'users', route: '/more/households'),
      ],
    ),
    const MoreSectionGroup(
      header: 'Settings',
      items: [
        MoreItem(
          label: 'Profile & Preferences',
          icon: 'user-circle',
          route: '/more/settings/profile',
        ),
        MoreItem(
          label: 'Notifications',
          icon: 'bell',
          route: '/more/settings/notifications',
        ),
        MoreItem(label: 'AI & Data', icon: 'brain', route: '/more/settings/ai'),
        MoreItem(
          label: 'Cloud Sync',
          icon: 'cloud',
          route: '/more/settings/sync',
        ),
        MoreItem(
          label: 'Data & Backup',
          icon: 'database',
          route: '/more/settings/data',
        ),
        MoreItem(
          label: 'Appearance',
          icon: 'palette',
          route: '/more/settings/appearance',
        ),
        MoreItem(
          label: 'Security',
          icon: 'shield-check',
          route: '/more/settings/security',
        ),
        MoreItem(label: 'About', icon: 'info', route: '/more/settings/about'),
      ],
    ),
  ];
  return moreList;
});
