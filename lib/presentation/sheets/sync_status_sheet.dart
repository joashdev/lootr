import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../application/providers/sync_providers.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../shared/components/app_snackbar.dart';

class SyncStatusSheet extends ConsumerWidget {
  const SyncStatusSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(syncHealthStreamProvider);
    final lootrColors = context.lootrColors;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: health.when(
          data: (data) {
            final iconState = ref.watch(syncStatusIconProvider);
            final icon = switch (iconState) {
              SyncIconState.synced => LucideIcons.cloudCheck,
              SyncIconState.pending => LucideIcons.cloudUpload,
              SyncIconState.failed => LucideIcons.triangleAlert,
              _ => LucideIcons.loaderCircle,
            };
            final iconColor = switch (iconState) {
              SyncIconState.synced => lootrColors.success,
              SyncIconState.pending => lootrColors.warning,
              SyncIconState.failed => lootrColors.danger,
              _ => Theme.of(context).colorScheme.primary,
            };

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: lootrColors.textTertiary.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.space5),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: iconColor),
                    ),
                    const SizedBox(width: AppSpacing.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sync status', style: AppTypography.h2),
                          const SizedBox(height: 2),
                          Text(
                            _statusCopy(iconState),
                            style: AppTypography.caption.copyWith(
                              color: lootrColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space5),
                _StatusRow(
                  label: 'Last synced',
                  value: data.lastSyncedAt == null
                      ? 'Not yet synced'
                      : DateFormat(
                          'MMM d, h:mm a',
                        ).format(data.lastSyncedAt!.toLocal()),
                ),
                _StatusRow(
                  label: 'Pending changes',
                  value: '${data.pendingCount}',
                ),
                _StatusRow(
                  label: 'Failed changes',
                  value: '${data.failedCount}',
                ),
                _StatusRow(label: 'Last result', value: data.lastStatus),
                const SizedBox(height: AppSpacing.space5),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      await ref.read(syncManagerProvider).sync();
                      if (context.mounted) {
                        AppSnackBar.show(context, 'Sync requested');
                      }
                    },
                    icon: const Icon(LucideIcons.rotateCw),
                    label: const Text('Retry sync'),
                  ),
                ),
              ],
            );
          },
          loading: () => const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.space6),
            child: Text('Unable to load sync status: $error'),
          ),
        ),
      ),
    );
  }

  String _statusCopy(SyncIconState state) {
    switch (state) {
      case SyncIconState.synced:
        return 'Everything is backed up.';
      case SyncIconState.pending:
        return 'Some local changes are still waiting to sync.';
      case SyncIconState.failed:
        return 'Some changes need another sync attempt.';
      case SyncIconState.offline:
        return 'Offline. Changes will sync when you reconnect.';
      case SyncIconState.syncing:
        return 'Checking sync status...';
    }
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final lootrColors = context.lootrColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.body.copyWith(
                color: lootrColors.textSecondary,
              ),
            ),
          ),
          Text(value, style: AppTypography.bodyMedium),
        ],
      ),
    );
  }
}
