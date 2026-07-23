import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../application/providers/period_context_provider.dart';
import '../../../domain/value_objects/period_context.dart';

class PeriodSelector extends ConsumerWidget {
  const PeriodSelector({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(periodContextProvider);
    final isMonth = period.kind == PeriodContextKind.calendarMonth;

    return Semantics(
      container: true,
      label: 'Selected period: ${period.description}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: isMonth ? 'Previous month' : 'Previous cycle unavailable',
            onPressed: isMonth
                ? ref.read(periodContextProvider.notifier).previous
                : null,
            icon: const Icon(LucideIcons.chevronLeft, size: 18),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: isMonth
                ? () => _showMonthPicker(context, ref, period)
                : null,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: compact ? 96 : 144,
                minHeight: 44,
              ),
              child: Center(
                child: Text(
                  period.description,
                  textAlign: TextAlign.center,
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: isMonth ? 'Next month' : 'Next cycle unavailable',
            onPressed: isMonth
                ? ref.read(periodContextProvider.notifier).next
                : null,
            icon: const Icon(LucideIcons.chevronRight, size: 18),
          ),
        ],
      ),
    );
  }

  Future<void> _showMonthPicker(
    BuildContext context,
    WidgetRef ref,
    PeriodContext period,
  ) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: period.startsAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 5, 12, 31),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Select month',
    );
    if (selected != null) {
      ref.read(periodContextProvider.notifier).selectMonth(selected);
    }
  }
}
