import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.padding});

  final String title;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lootrColors = context.lootrColors;
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SectionHeaderDelegate(
        title: title,
        bgColor: colorScheme.surfaceContainerLow,
        textColor: lootrColors.textSecondary,
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}

class _SectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SectionHeaderDelegate({
    required this.title,
    required this.bgColor,
    required this.textColor,
    required this.padding,
  });

  final String title;
  final Color bgColor;
  final Color textColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: bgColor,
      padding: padding,
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: AppTypography.captionMedium.copyWith(color: textColor),
      ),
    );
  }

  @override
  double get maxExtent =>
      padding.resolve(TextDirection.ltr).vertical +
      AppTypography.captionMedium.fontSize! *
          AppTypography.captionMedium.height!;

  @override
  double get minExtent => maxExtent;

  @override
  bool shouldRebuild(_SectionHeaderDelegate oldDelegate) =>
      title != oldDelegate.title || bgColor != oldDelegate.bgColor;
}
