import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';

class InsightDetailScreen extends ConsumerWidget {
  const InsightDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    final (title, description) = switch (id) {
      'spending-trend' => (
        'Spending Trend',
        'Your spending in this category has increased significantly compared to previous months. Consider reviewing your budget for this category.',
      ),
      'unusual-activity' => (
        'Unusual Activity',
        'An unusually large transaction was detected. If this was not you, you may want to review this transaction.',
      ),
      _ => (
        'Insight unavailable',
        'This insight is no longer available. Return to the dashboard for current, data-backed insights.',
      ),
    };

    return Scaffold(
      appBar: AppBar(centerTitle: false, title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.pagePaddingMobile),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.space4),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        LucideIcons.sparkles,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.space2),
                      Text(
                        'AI Insight',
                        style: AppTypography.captionMedium.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space3),
                  Text(
                    description,
                    style: AppTypography.body.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
