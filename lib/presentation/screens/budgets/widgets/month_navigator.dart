import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../application/providers/period_context_provider.dart';
import '../../../../core/theme/colors.dart';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _compactMonthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'June',
  'July',
  'Aug',
  'Sept',
  'Oct',
  'Nov',
  'Dec',
];

class MonthNavigator extends ConsumerWidget {
  const MonthNavigator({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(periodContextProvider);
    final month = period.startsAt.month;
    final year = period.startsAt.year;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(LucideIcons.chevronLeft, size: 16),
          onPressed: ref.read(periodContextProvider.notifier).previous,
          tooltip: 'Previous month',
          splashRadius: 20,
        ),
        GestureDetector(
          onTap: () => _showMonthPicker(context, ref),
          child: SizedBox(
            width: compact ? 96 : 120,
            child: Text(
              '${(compact ? _compactMonthNames : _monthNames)[month - 1]} $year',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compact ? 16 : 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(LucideIcons.chevronRight, size: 16),
          onPressed: ref.read(periodContextProvider.notifier).next,
          tooltip: 'Next month',
          splashRadius: 20,
        ),
      ],
    );
  }

  void _showMonthPicker(BuildContext context, WidgetRef ref) {
    final period = ref.read(periodContextProvider);
    final month = period.startsAt.month;
    final year = period.startsAt.year;
    final now = DateTime.now();
    final colorScheme = Theme.of(context).colorScheme;
    final lootrColors = context.lootrColors;
    showDialog(
      context: context,
      builder: (ctx) {
        var selectedYear = year;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Column(
                children: [
                  Text(
                    'Select Month',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(LucideIcons.chevronLeft, size: 20),
                        onPressed: selectedYear <= 2020
                            ? null
                            : () => setState(() => selectedYear--),
                        splashRadius: 20,
                      ),
                      SizedBox(
                        width: 72,
                        child: Text(
                          '$selectedYear',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.chevronRight, size: 20),
                        onPressed: selectedYear >= now.year + 5
                            ? null
                            : () => setState(() => selectedYear++),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                ],
              ),
              content: SizedBox(
                width: 280,
                child: GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.4,
                  children: List.generate(12, (index) {
                    final m = index + 1;
                    final isSelected = m == month && selectedYear == year;
                    final isDisabled =
                        selectedYear == now.year + 5 && m > now.month;
                    return InkWell(
                      onTap: isDisabled
                          ? null
                          : () {
                              ref
                                  .read(periodContextProvider.notifier)
                                  .selectMonth(DateTime(selectedYear, m));
                              Navigator.of(ctx).pop();
                            },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colorScheme.primary.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            _compactMonthNames[index],
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isDisabled
                                  ? lootrColors.textTertiary
                                  : isSelected
                                  ? colorScheme.primary
                                  : colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
