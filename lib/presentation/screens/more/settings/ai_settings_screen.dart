import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../application/providers/ai_settings_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';

class AiSettingsScreen extends ConsumerWidget {
  const AiSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiState = ref.watch(aiSettingsProvider);
    final lootrColors = context.lootrColors;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(centerTitle: false, title: const Text('AI & Data')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
        children: [
          _SettingsSection(
            header: 'On-Device AI',
            children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pagePaddingMobile,
                ),
                secondary: Icon(
                  LucideIcons.brain,
                  size: 20,
                  color: colorScheme.primary,
                ),
                title: Text(
                  'Enable AI Features',
                  style: AppTypography.bodyMedium.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  'Natural language parsing and smart categorization',
                  style: AppTypography.caption.copyWith(
                    color: lootrColors.textSecondary,
                  ),
                ),
                value: aiState.aiEnabled,
                onChanged: (_) =>
                    ref.read(aiSettingsProvider.notifier).toggleAi(),
              ),
            ],
          ),
          _SettingsSection(
            header: 'Model',
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pagePaddingMobile,
                ),
                leading: Icon(
                  LucideIcons.cpu,
                  size: 20,
                  color: colorScheme.primary,
                ),
                title: Text(
                  'Model Info',
                  style: AppTypography.bodyMedium.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  'DeepSeek V4 • On-device',
                  style: AppTypography.caption.copyWith(
                    color: lootrColors.textSecondary,
                  ),
                ),
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pagePaddingMobile,
                ),
                leading: Icon(
                  LucideIcons.download,
                  size: 20,
                  color: colorScheme.primary,
                ),
                title: Text(
                  'Model Download',
                  style: AppTypography.bodyMedium.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  _statusLabel(aiState.modelStatus),
                  style: AppTypography.caption.copyWith(
                    color: lootrColors.textSecondary,
                  ),
                ),
                trailing:
                    aiState.modelStatus == ModelDownloadStatus.notDownloaded
                    ? FilledButton.tonalIcon(
                        onPressed: () async {
                          final notifier = ref.read(
                            aiSettingsProvider.notifier,
                          );
                          notifier.updateModelDownload(
                            status: ModelDownloadStatus.downloading,
                            sizeBytes: 256 * 1024 * 1024,
                            downloadedBytes: 0,
                          );
                          await Future<void>.delayed(
                            const Duration(milliseconds: 400),
                          );
                          notifier.updateModelDownload(
                            status: ModelDownloadStatus.downloaded,
                            sizeBytes: 256 * 1024 * 1024,
                            downloadedBytes: 256 * 1024 * 1024,
                          );
                        },
                        icon: const Icon(LucideIcons.download, size: 16),
                        label: const Text('Download'),
                      )
                    : null,
              ),
            ],
          ),
          _SettingsSection(
            header: 'Data',
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pagePaddingMobile,
                ),
                leading: Icon(
                  LucideIcons.fileText,
                  size: 20,
                  color: colorScheme.primary,
                ),
                title: Text(
                  'AI Processing Logs',
                  style: AppTypography.bodyMedium.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                trailing: Icon(
                  LucideIcons.chevronRight,
                  size: 18,
                  color: lootrColors.textTertiary,
                ),
                onTap: () => context.push('/more/settings/ai/logs'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(ModelDownloadStatus status) {
    switch (status) {
      case ModelDownloadStatus.notDownloaded:
        return 'Not downloaded (0 MB)';
      case ModelDownloadStatus.downloading:
        return 'Downloading… 256 MB';
      case ModelDownloadStatus.downloaded:
        return 'Downloaded (256 MB)';
      case ModelDownloadStatus.failed:
        return 'Download failed';
    }
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.header, required this.children});

  final String header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final lootrColors = context.lootrColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pagePaddingMobile,
            AppSpacing.space3,
            AppSpacing.pagePaddingMobile,
            AppSpacing.space1,
          ),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Text(
            header,
            style: AppTypography.captionMedium.copyWith(
              color: lootrColors.textSecondary,
            ),
          ),
        ),
        ...children,
        const SizedBox(height: AppSpacing.space3),
      ],
    );
  }
}
