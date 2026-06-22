import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../application/providers/ai_settings_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../shared/components/empty_state.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiEnabled = ref.watch(aiEnabledProvider);
    final lootrColors = context.lootrColors;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(centerTitle: false, title: const Text('Insights')),
      body: !aiEnabled
          ? EmptyState(
              headline: 'AI is not enabled',
              subtext:
                  'Enable AI in Settings to get spending insights and smart suggestions.',
              ctaLabel: 'Enable AI',
              onCtaPressed: () => context.push('/more/settings/ai'),
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.pagePaddingMobile),
              children: [
                Material(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.push('/more/insights/spending-trend'),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.space4),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              LucideIcons.sparkles,
                              color: colorScheme.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.space3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Spending Trend',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  'Your food spending is up 15% this month',
                                  style: AppTypography.caption.copyWith(
                                    color: lootrColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            LucideIcons.chevronRight,
                            size: 18,
                            color: lootrColors.textTertiary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.space3),
                Material(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () =>
                        context.push('/more/insights/unusual-activity'),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.space4),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: lootrColors.warningBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              LucideIcons.alertTriangle,
                              color: lootrColors.warning,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.space3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Unusual Activity',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  'Large transaction detected',
                                  style: AppTypography.caption.copyWith(
                                    color: lootrColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            LucideIcons.chevronRight,
                            size: 18,
                            color: lootrColors.textTertiary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
