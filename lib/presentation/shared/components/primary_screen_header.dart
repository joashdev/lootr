import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';

class PrimaryScreenHeader extends StatelessWidget
    implements PreferredSizeWidget {
  const PrimaryScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  static const double height = 80;

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lootrColors = context.lootrColors;

    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleSpacing: AppSpacing.pagePaddingMobile,
      toolbarHeight: height,
      shape: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.h1.copyWith(color: colorScheme.onSurface),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.captionMedium.copyWith(
                color: lootrColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
      actions: actions.isEmpty
          ? null
          : [
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.space4),
                child: Row(mainAxisSize: MainAxisSize.min, children: actions),
              ),
            ],
    );
  }
}
