import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../application/providers/dashboard_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../shared/components/cards/cards.dart';

class InsightsSection extends StatelessWidget {
  const InsightsSection({super.key, required this.insights});

  final List<DashboardInsight> insights;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Insights', style: AppTypography.h2),
        const SizedBox(height: AppSpacing.space3),
        for (final insight in insights)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.space2),
            child: StandardCard(
              onTap: () => context.push('/more/insights/${insight.id}'),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    LucideIcons.sparkles,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(insight.title, style: AppTypography.h3),
                        const SizedBox(height: 2),
                        Text(
                          insight.body,
                          style: AppTypography.body.copyWith(
                            color: context.lootrColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
