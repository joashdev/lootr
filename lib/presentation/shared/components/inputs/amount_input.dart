import 'package:flutter/material.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/typography.dart';

class AmountInput extends StatelessWidget {
  const AmountInput({
    super.key,
    required this.direction,
    this.controller,
    this.currency = 'PHP',
  });

  final TransactionDirection direction;
  final TextEditingController? controller;
  final String currency;

  Color _directionColor(BuildContext context) {
    final colors = Theme.of(context).extension<LootrColorScheme>()!;
    switch (direction) {
      case TransactionDirection.expense:
        return colors.expense;
      case TransactionDirection.income:
        return colors.income;
      case TransactionDirection.transfer:
        return colors.transfer;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final directionColor = _directionColor(context);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colorScheme.outline),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            currency,
            style: AppTypography.mono.copyWith(
              color: directionColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: AppTypography.h3.copyWith(
                color: directionColor,
                fontFamily: AppTypography.mono.fontFamily,
                fontFamilyFallback: AppTypography.mono.fontFamilyFallback,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: '0.00',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
