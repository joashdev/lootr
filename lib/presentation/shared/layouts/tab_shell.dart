import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/shadows.dart';
import '../../../core/theme/spacing.dart';
import '../../sheets/quick_actions_sheet.dart';

class TabShell extends StatelessWidget {
  const TabShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final lootrColors = Theme.of(context).extension<LootrColorScheme>()!;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _buildBottomBar(context, lootrColors),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    LootrColorScheme lootrColors,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.centerRight,
      children: [
        Container(
          height: 64 + MediaQuery.of(context).padding.bottom,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(color: lootrColors.borderSubtle, width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                _TabItem(
                  icon: PhosphorIconsRegular.house,
                  label: 'Dashboard',
                  isActive: navigationShell.currentIndex == 0,
                  onTap: () => navigationShell.goBranch(0),
                  lootrColors: lootrColors,
                ),
                _TabItem(
                  icon: PhosphorIconsRegular.list,
                  label: 'Transactions',
                  isActive: navigationShell.currentIndex == 1,
                  onTap: () => navigationShell.goBranch(1),
                  lootrColors: lootrColors,
                ),
                _TabItem(
                  icon: PhosphorIconsRegular.chartPie,
                  label: 'Budgets',
                  isActive: navigationShell.currentIndex == 2,
                  onTap: () => navigationShell.goBranch(2),
                  lootrColors: lootrColors,
                ),
                _TabItem(
                  icon: PhosphorIconsRegular.squaresFour,
                  label: 'More',
                  isActive: navigationShell.currentIndex == 3,
                  onTap: () => navigationShell.goBranch(3),
                  lootrColors: lootrColors,
                ),
                const SizedBox(width: 56 + AppSpacing.space2 * 2),
              ],
            ),
          ),
        ),
        Positioned(
          top: -12,
          right: AppSpacing.space2,
          child: GestureDetector(
            onTap: () => _showQuickActions(context),
            child: Container(
              width: 56,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary600,
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(14)),
                boxShadow: AppShadows.island,
              ),
              child: const Icon(
                PhosphorIconsRegular.plus,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showQuickActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => const QuickActionsSheet(),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.lootrColors,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final LootrColorScheme lootrColors;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primary600 : lootrColors.textTertiary;
    final fontWeight = isActive ? FontWeight.w600 : FontWeight.w400;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: fontWeight,
                color: color,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
