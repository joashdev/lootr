import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/colors.dart';
import '../../sheets/quick_actions_sheet.dart';

class TabShell extends StatelessWidget {
  const TabShell({super.key, required this.navigationShell});

  static const _pillHeight = 56.0;
  static const _addButtonSize = 56.0;
  static const _navBottomGap = 16.0;
  static const _navHorizontalInset = 16.0;

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = Theme.of(context).colorScheme.surface;

    final navOverlayHeight =
        _navBottomGap + _pillHeight + bottomPadding + 48;

    return Scaffold(
      body: Stack(
        children: [
          navigationShell,

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: navOverlayHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      surface.withValues(alpha: 0.0),
                      surface.withValues(alpha: 0.75),
                      surface.withValues(alpha: 1.0),
                    ],
                    stops: const [0.0, 0.3, 1.0],
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            left: _navHorizontalInset,
            right: _navHorizontalInset,
            bottom: _navBottomGap + bottomPadding,
            child: _buildFloatingNav(context, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingNav(BuildContext context, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _buildNavPill(context, isDark)),
        const SizedBox(width: 8),
        _buildAddIsland(context, isDark),
      ],
    );
  }

  Widget _buildNavPill(BuildContext context, bool isDark) {
    return SizedBox(
      height: _pillHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1A1A1E).withValues(alpha: 0.95)
                  : const Color(0xFFFFFFFF).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? const Color(0x14FFFFFF)
                    : const Color(0x0D000000),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? const Color(0x66000000)
                      : const Color(0x1F000000),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                _NavTab(
                  icon: LucideIcons.home,
                  label: 'Home',
                  isActive: navigationShell.currentIndex == 0,
                  onTap: () => navigationShell.goBranch(0),
                  isDark: isDark,
                ),
                _NavTab(
                  icon: LucideIcons.receiptText,
                  label: 'Transactions',
                  isActive: navigationShell.currentIndex == 1,
                  onTap: () => navigationShell.goBranch(1),
                  isDark: isDark,
                ),
                _NavTab(
                  icon: LucideIcons.pieChart,
                  label: 'Budgets',
                  isActive: navigationShell.currentIndex == 2,
                  onTap: () => navigationShell.goBranch(2),
                  isDark: isDark,
                ),
                _NavTab(
                  icon: LucideIcons.grid2X2,
                  label: 'More',
                  isActive: navigationShell.currentIndex == 3,
                  onTap: () =>
                      navigationShell.goBranch(3, initialLocation: true),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddIsland(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () => _showQuickActions(context),
      child: Container(
        width: _addButtonSize,
        height: _addButtonSize,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkPrimary600 : AppColors.primary600,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDark ? const Color(0x593B82F6) : const Color(0x662563EB),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(LucideIcons.plus, color: Colors.white, size: 28),
      ),
    );
  }

  void _showQuickActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => const QuickActionsSheet(),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final activeColor = isDark
        ? AppColors.darkPrimary600
        : AppColors.primary600;
    final inactiveColor = isDark
        ? AppColors.darkTextTertiary
        : AppColors.lightTextTertiary;
    final color = isActive ? activeColor : inactiveColor;
    final fontWeight = isActive ? FontWeight.w500 : FontWeight.w400;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: double.infinity,
          decoration: BoxDecoration(
            color: isActive
                ? (isDark ? const Color(0x263B82F6) : const Color(0x1A2563EB))
                : null,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: fontWeight,
                  color: color,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}