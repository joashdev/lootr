import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/providers/ai_processing_logs_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../../data/database/app_database.dart';
import '../../../shared/components/empty_state.dart';

class AiLogsScreen extends ConsumerStatefulWidget {
  const AiLogsScreen({super.key});

  @override
  ConsumerState<AiLogsScreen> createState() => _AiLogsScreenState();
}

class _AiLogsScreenState extends ConsumerState<AiLogsScreen> {
  String _filter = 'all';

  String _prettyPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) return 'No payload recorded';
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(payload));
    } catch (_) {
      return payload;
    }
  }

  Future<void> _showLogDetail(AiProcessingLogData log) {
    final confidence = log.confidenceScore;
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${log.sourceType.toUpperCase()} details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Method: ${log.modelUsed ?? 'local'}'),
              Text(
                'Confidence: ${confidence == null ? 'Not recorded' : '${(confidence * 100).round()}%'}',
              ),
              Text('Timestamp: ${log.createdAt.toLocal().toIso8601String()}'),
              const SizedBox(height: AppSpacing.space3),
              const Text('Payload'),
              const SizedBox(height: AppSpacing.space1),
              SelectableText(_prettyPayload(log.extractedPayload)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(aiProcessingLogsProvider);
    final lootrColors = context.lootrColors;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Smart Entry Processing Logs'),
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
                  'Local processing logs appear here after Smart Entry is used.',
              ctaLabel: 'No activity yet',
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
                        [
                          log.modelUsed ?? 'local',
                          if (log.confidenceScore != null)
                            '${(log.confidenceScore! * 100).round()}% confidence',
                        ].join(' · '),
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
                      onTap: () => _showLogDetail(log),
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
