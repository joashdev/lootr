import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../application/providers/dashboard_provider.dart';
import '../../../../application/providers/sync_providers.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';
import '../../../shared/components/app_snackbar.dart';
import '../../../sheets/sync_status_sheet.dart';

class GreetingHeader extends ConsumerWidget {
  const GreetingHeader({super.key, required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStatusIconProvider);
    final lootrColors = context.lootrColors;
    final greetingName = data.displayName?.trim().isNotEmpty == true
        ? ', ${data.displayName!.trim()}'
        : '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${data.greeting}$greetingName', style: AppTypography.h1),
              const SizedBox(height: 2),
              Text(
                DateFormat('EEEE, MMMM d').format(data.currentDate),
                style: AppTypography.body.copyWith(
                  color: lootrColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        _HeaderIconButton(
          icon: _syncIcon(syncState),
          color: _syncColor(syncState, lootrColors, context),
          onTap: () {
            showModalBottomSheet<void>(
              context: context,
              useRootNavigator: true,
              isScrollControlled: true,
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              builder: (_) => const SyncStatusSheet(),
            );
          },
        ),
        const SizedBox(width: AppSpacing.space2),
        _HeaderIconButton(
          icon: LucideIcons.search,
          color: lootrColors.textSecondary,
          onTap: () {
            AppSnackBar.show(context, 'Global search is coming soon');
          },
        ),
      ],
    );
  }

  IconData _syncIcon(SyncIconState state) {
    switch (state) {
      case SyncIconState.synced:
        return LucideIcons.cloudCheck;
      case SyncIconState.pending:
        return LucideIcons.cloudUpload;
      case SyncIconState.failed:
        return LucideIcons.triangleAlert;
      case SyncIconState.offline:
        return LucideIcons.triangleAlert;
      case SyncIconState.syncing:
        return LucideIcons.loaderCircle;
    }
  }

  Color _syncColor(
    SyncIconState state,
    LootrColorScheme lootrColors,
    BuildContext context,
  ) {
    switch (state) {
      case SyncIconState.synced:
        return lootrColors.success;
      case SyncIconState.pending:
        return lootrColors.warning;
      case SyncIconState.failed:
      case SyncIconState.offline:
        return lootrColors.danger;
      case SyncIconState.syncing:
        return Theme.of(context).colorScheme.primary;
    }
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      icon: Icon(icon, color: color),
    );
  }
}
