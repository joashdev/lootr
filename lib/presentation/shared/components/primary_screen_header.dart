import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';

class PrimaryScreenHeader extends StatelessWidget
    implements PreferredSizeWidget {
  const PrimaryScreenHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.actions = const [],
  });

  static const double height = 80;
  static const double heightWithEyebrow = 98;

  /// Small label rendered above [title]. Lets a screen show a secondary line
  /// (e.g. a greeting) without cramming it into [title], which is single-line
  /// and would otherwise truncate a long [title].
  final String? eyebrow;
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  double get _height => eyebrow != null ? heightWithEyebrow : height;

  @override
  Size get preferredSize => Size.fromHeight(_height);

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
      toolbarHeight: _height,
      shape: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) ...[
            Text(
              eyebrow!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium.copyWith(
                color: lootrColors.textSecondary,
              ),
            ),
            const SizedBox(height: 1),
          ],
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
