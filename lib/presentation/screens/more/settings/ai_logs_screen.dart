import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/providers/ai_processing_logs_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../shared/components/empty_state.dart';

class AiLogsScreen extends ConsumerStatefulWidget {
  const AiLogsScreen({super.key});

  @override
  ConsumerState<AiLogsScreen> createState() => _AiLogsScreenState();
}

class _AiLogsScreenState extends ConsumerState<AiLogsScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(aiProcessingLogsProvider);
    final lootrColors = context.lootrColors;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('AI Processing Logs'),
      ),
      body: logsAsync.when(
        data: (logs) {
          final filtered = _filter == 'all'
              ? logs
              : logs.where((log) => log.sourceType == _filter).toList();
          if (filtered.isEmpty) {
            return const EmptyState(
              headline: 'No logs yet',
              subtext:
                  'AI processing logs will appear here when AI features are used.',
              ctaLabel: 'Enable AI',
              onCtaPressed: null,
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.pagePaddingMobile),
                child: Wrap(
                  spacing: AppSpacing.space2,
                  children: [
                    for (final filter in const [
                      'all',
                      'ocr',
                      'nlp',
                      'categorization',
                    ])
                      ChoiceChip(
                        label: Text(filter == 'all' ? 'All' : filter),
                        selected: _filter == filter,
                        onSelected: (_) => setState(() => _filter = filter),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    indent: AppSpacing.pagePaddingMobile,
                    color: lootrColors.borderSubtle,
                  ),
                  itemBuilder: (context, index) {
                    final log = filtered[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.pagePaddingMobile,
                      ),
                      title: Text(log.sourceType.toUpperCase()),
                      subtitle: Text(
                        log.sourceReferenceId ?? 'No related record',
                        style: AppTypography.caption.copyWith(
                          color: lootrColors.textSecondary,
                        ),
                      ),
                      trailing: Text(
                        '${log.createdAt.month}/${log.createdAt.day}',
                        style: AppTypography.caption.copyWith(
                          color: lootrColors.textTertiary,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        error: (err, _) => Center(child: Text('Error: $err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
