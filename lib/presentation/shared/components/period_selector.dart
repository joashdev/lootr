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
    final notifier = ref.read(periodContextProvider.notifier);

    return Semantics(
      container: true,
      label: 'Selected period: ${period.description}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: isMonth ? 'Previous month' : 'Previous cycle',
            onPressed: notifier.previous,
            icon: const Icon(LucideIcons.chevronLeft, size: 18),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _showPicker(context, ref, period),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: compact ? 144 : 168,
                minHeight: 44,
              ),
              child: Center(
                child: isMonth
                    ? Text(
                        period.label,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge,
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            period.label,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          Text(
                            period.dateRangeLabel,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
              ),
            ),
          ),
          IconButton(
            tooltip: isMonth ? 'Next month' : 'Next cycle',
            onPressed: notifier.next,
            icon: const Icon(LucideIcons.chevronRight, size: 18),
          ),
        ],
      ),
    );
  }

  Future<void> _showPicker(
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
      helpText: period.kind == PeriodContextKind.calendarMonth
          ? 'Select month'
          : 'Select cycle start',
    );
    if (selected != null) {
      ref.read(periodContextProvider.notifier).moveTo(selected);
    }
  }
}
