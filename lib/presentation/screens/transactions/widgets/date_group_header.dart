import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';

class DateGroupHeader extends StatelessWidget {
  const DateGroupHeader({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: colorScheme.surfaceContainerLow,
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: AppTypography.captionMedium.copyWith(
          color: context.lootrColors.textSecondary,
        ),
      ),
    );
  }
}

class DateGroupHeaderDelegate extends SliverPersistentHeaderDelegate {
  DateGroupHeaderDelegate({required this.title});

  final String title;

  @override
  double get minExtent => 40;

  @override
  double get maxExtent => 40;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return DateGroupHeader(title: title);
  }

  @override
  bool shouldRebuild(DateGroupHeaderDelegate oldDelegate) =>
      oldDelegate.title != title;
}
