import 'package:flutter/material.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/format/money_format.dart';
import '../../../../core/format/amount_expression.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/typography.dart';

/// Reusable amount input with a monospace, direction-coloured field and a
/// currency prefix.
class AmountInput extends StatelessWidget {
  const AmountInput({
    super.key,
    required this.direction,
    this.controller,
    this.currency = 'PHP',
    this.onChanged,
    this.label,
    this.enableCalculator = true,
  });

  final TransactionDirection direction;
  final TextEditingController? controller;
  final String currency;
  final ValueChanged<String>? onChanged;
  final String? label;
  final bool enableCalculator;

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
    final lootrColors = context.lootrColors;
    final directionColor = _directionColor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTypography.captionMedium.copyWith(
              color: lootrColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: colorScheme.outline),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(
                MoneyFormat.symbolFor(currency),
                style: AppTypography.mono.copyWith(color: directionColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
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
              if (enableCalculator)
                IconButton(
                  tooltip: 'Open amount calculator',
                  onPressed: controller == null
                      ? null
                      : () => _openCalculator(context),
                  icon: const Icon(Icons.calculate_outlined, size: 20),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openCalculator(BuildContext context) async {
    final expressionController = TextEditingController(
      text: controller?.text ?? '',
    );
    String? error;
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Amount calculator'),
          content: TextField(
            controller: expressionController,
            autofocus: true,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              hintText: '(120 + 30) / 2',
              helperText: 'Use +, −, ×, ÷, and parentheses.',
              errorText: error,
            ),
            onSubmitted: (_) {
              try {
                Navigator.pop(
                  dialogContext,
                  AmountExpression.evaluate(expressionController.text),
                );
              } on FormatException catch (exception) {
                setState(() => error = exception.message);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  Navigator.pop(
                    dialogContext,
                    AmountExpression.evaluate(expressionController.text),
                  );
                } on FormatException catch (exception) {
                  setState(() => error = exception.message);
                }
              },
              child: const Text('Use amount'),
            ),
          ],
        ),
      ),
    );
    expressionController.dispose();
    if (result == null || controller == null) return;
    final formatted = result == result.roundToDouble()
        ? result.toStringAsFixed(0)
        : result.toStringAsFixed(2);
    controller!.text = formatted;
    onChanged?.call(formatted);
  }
}
