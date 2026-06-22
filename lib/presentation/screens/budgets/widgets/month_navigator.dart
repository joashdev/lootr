import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../application/providers/budgets_tab_provider.dart';

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
    final month = ref.watch(budgetMonthProvider);
    final year = ref.watch(budgetYearProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(LucideIcons.chevronLeft, size: 20),
          onPressed: () {
            if (month == 1) {
              ref.read(budgetMonthProvider.notifier).goTo(12);
              ref.read(budgetYearProvider.notifier).goTo(year - 1);
            } else {
              ref.read(budgetMonthProvider.notifier).goTo(month - 1);
            }
          },
          tooltip: 'Previous month',
          splashRadius: 20,
        ),
        GestureDetector(
          onTap: () => _showMonthPicker(context, ref),
          child: SizedBox(
            width: compact ? 108 : 140,
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
          icon: const Icon(LucideIcons.chevronRight, size: 20),
          onPressed: () {
            if (month == 12) {
              ref.read(budgetMonthProvider.notifier).goTo(1);
              ref.read(budgetYearProvider.notifier).goTo(year + 1);
            } else {
              ref.read(budgetMonthProvider.notifier).goTo(month + 1);
            }
          },
          tooltip: 'Next month',
          splashRadius: 20,
        ),
      ],
    );
  }

  void _showMonthPicker(BuildContext context, WidgetRef ref) {
    final month = ref.read(budgetMonthProvider);
    final year = ref.read(budgetYearProvider);
    final now = DateTime.now();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Select Month'),
          content: SizedBox(
            width: 200,
            height: 300,
            child: YearPicker(
              firstDate: DateTime(2020),
              lastDate: DateTime(now.year + 5),
              selectedDate: DateTime(year, month),
              onChanged: (date) {
                ref.read(budgetMonthProvider.notifier).goTo(date.month);
                ref.read(budgetYearProvider.notifier).goTo(date.year);
                Navigator.of(ctx).pop();
              },
            ),
          ),
        );
      },
    );
  }
}
