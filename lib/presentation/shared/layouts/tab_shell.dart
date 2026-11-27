import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../application/providers/ai_settings_provider.dart';
import '../../../core/theme/typography.dart';
import '../../sheets/quick_actions_sheet.dart';

class TabShell extends StatelessWidget {
  const TabShell({super.key, required this.navigationShell});

  static const _pillHeight = 58.0;
  static const _addButtonSize = 58.0;
  static const _navBottomGap = 16.0;
  static const _navHorizontalInset = 16.0;

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final background = Theme.of(context).scaffoldBackgroundColor;

    final navOverlayHeight = _navBottomGap + _pillHeight + bottomPadding + 12;

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
                      background.withValues(alpha: 0),
                      background.withValues(alpha: 0.76),
                      background,
                    ],
                    stops: const [0, 0.65, 1],
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            left: _navHorizontalInset,
            right: _navHorizontalInset,
            bottom: _navBottomGap + bottomPadding,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 536),
                child: _buildFloatingNav(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingNav(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _buildNavPill(context)),
        const SizedBox(width: 8),
        _buildAddIsland(context),
      ],
    );
  }

  Widget _buildNavPill(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide(color: colorScheme.outline),
    );
    return SizedBox(
      height: _pillHeight,
      child: Material(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: shape,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              _NavTab(
                icon: LucideIcons.home,
                label: 'Home',
                isActive: navigationShell.currentIndex == 0,
                onTap: () => navigationShell.goBranch(0),
              ),
              _NavTab(
                icon: LucideIcons.receiptText,
                label: 'Transactions',
                isActive: navigationShell.currentIndex == 1,
                onTap: () => navigationShell.goBranch(1),
                flex:
                    navigationShell.currentIndex == 1 &&
                        MediaQuery.textScalerOf(context).scale(11) >= 16
                    ? 2
                    : 1,
              ),
              _NavTab(
                icon: LucideIcons.pieChart,
                label: 'Budgets',
                isActive: navigationShell.currentIndex == 2,
                onTap: () => navigationShell.goBranch(2),
              ),
              _NavTab(
                icon: LucideIcons.grid2X2,
                label: 'More',
                isActive: navigationShell.currentIndex == 3,
                onTap: () => navigationShell.goBranch(3, initialLocation: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddIsland(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(22);
    return SizedBox.square(
      dimension: _addButtonSize,
      child: Semantics(
        button: true,
        label: 'Add transaction, transfer, or scan receipt',
        onTap: () => _showQuickActions(context),
        excludeSemantics: true,
        child: Material(
          color: colorScheme.primary,
          elevation: 2,
          borderRadius: borderRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _showQuickActions(context),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.plus, color: colorScheme.onPrimary, size: 23),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Add',
                      style: AppTypography.micro.copyWith(
                        color: colorScheme.onPrimary,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showQuickActions(BuildContext context) {
    final assistanceEnabled = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(smartEntryAssistanceEnabledProvider);
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => QuickActionsSheet(assistanceEnabled: assistanceEnabled),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.flex = 1,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final int flex;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = isActive ? colors.onPrimaryContainer : colors.secondary;
    final fontWeight = isActive ? FontWeight.w600 : FontWeight.w500;

    return Expanded(
      flex: flex,
      child: Semantics(
        button: true,
        selected: isActive,
        label: '$label tab',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: double.infinity,
              decoration: BoxDecoration(
                color: isActive ? colors.primaryContainer : null,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(height: 2),
                  // Scale down long labels (e.g. "Transactions") instead of
                  // clipping them; short labels render at full size.
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          maxLines: 1,
                          style: AppTypography.micro.copyWith(
                            fontWeight: fontWeight,
                            color: color,
                            height: 1.15,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
