import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';

/// Formats a transactions-list date group heading for display.
///
/// Returns "Today" or "Yesterday" relative to [now] (defaults to
/// [DateTime.now]), otherwise "Jun 29" for dates in the current year and
/// "Jun 29, 2025" for dates in any other year. Pure function: inject [now]
/// in tests for deterministic output.
String formatDateGroupTitle(DateTime date, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(reference.year, reference.month, reference.day);
  final yesterday = DateTime(reference.year, reference.month, reference.day - 1);

  if (day == today) return 'Today';
  if (day == yesterday) return 'Yesterday';
  return day.year == today.year
      ? DateFormat('MMM d').format(day)
      : DateFormat('MMM d, yyyy').format(day);
}

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
