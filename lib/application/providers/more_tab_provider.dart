import 'package:flutter_riverpod/flutter_riverpod.dart';

class MoreSection {
  final String label;
  final String? icon;
  final bool isHeader;

  const MoreSection({required this.label, this.icon, this.isHeader = false});
}

class MoreSectionGroup {
  final String header;
  final List<MoreSection> items;

  const MoreSectionGroup({required this.header, required this.items});
}

final moreTabProvider = Provider<List<MoreSectionGroup>>((ref) => const [
      MoreSectionGroup(header: 'Financial', items: [
        MoreSection(label: 'Accounts', icon: 'wallet'),
        MoreSection(label: 'Transfers', icon: 'arrows-left-right'),
        MoreSection(label: 'Debts', icon: 'hand-coins'),
      ]),
      MoreSectionGroup(header: 'Insights', items: [
        MoreSection(label: 'Goals', icon: 'target'),
        MoreSection(label: 'Spending by Category', icon: 'chart-pie'),
        MoreSection(label: 'Net Worth Report', icon: 'trend-up'),
      ]),
      MoreSectionGroup(header: 'Manage', items: [
        MoreSection(label: 'Categories', icon: 'tag'),
        MoreSection(label: 'Payees', icon: 'address-book'),
        MoreSection(label: 'Recurring', icon: 'repeat'),
      ]),
      MoreSectionGroup(header: 'Settings', items: [
        MoreSection(label: 'Appearance', icon: 'palette'),
        MoreSection(label: 'Notifications', icon: 'bell'),
        MoreSection(label: 'Data & Sync', icon: 'cloud'),
        MoreSection(label: 'Backup & Export', icon: 'download'),
        MoreSection(label: 'About', icon: 'info'),
      ]),
    ]);
