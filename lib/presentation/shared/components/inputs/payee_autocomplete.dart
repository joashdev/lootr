import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/typography.dart';
import '../../../../domain/entities/payee.dart';

/// Autocomplete selector for payees. Reports the typed text via
/// [onTextChanged] so callers can create a new payee on an unknown name.
class PayeeAutocomplete extends StatelessWidget {
  const PayeeAutocomplete({
    super.key,
    required this.payees,
    required this.selectedPayeeId,
    required this.onChanged,
    required this.onTextChanged,
    this.initialText,
  });

  final List<Payee> payees;
  final String? selectedPayeeId;
  final ValueChanged<String?> onChanged;
  final ValueChanged<String> onTextChanged;
  final String? initialText;

  String _labelFor(Payee payee) => payee.resolvedName;

  @override
  Widget build(BuildContext context) {
    final activePayees =
        payees.where((payee) => payee.deletedAt == null).toList()
          ..sort((left, right) => _labelFor(left).compareTo(_labelFor(right)));

    return Autocomplete<Payee>(
      key: ValueKey('${selectedPayeeId ?? 'none'}:${initialText ?? ''}'),
      initialValue: TextEditingValue(text: initialText ?? ''),
      displayStringForOption: _labelFor,
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        if (query.isEmpty) {
          return activePayees;
        }
        return activePayees.where((payee) {
          final label = _labelFor(payee).toLowerCase();
          return label.contains(query);
        });
      },
      onSelected: (payee) {
        onChanged(payee.id);
        onTextChanged(_labelFor(payee));
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        final colorScheme = Theme.of(context).colorScheme;
        final lootrColors = context.lootrColors;

        return TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: (value) {
            onTextChanged(value);
            final normalized = value.trim().toLowerCase();
            if (normalized.isEmpty) {
              onChanged(null);
              return;
            }

            final exactMatch = activePayees.cast<Payee?>().firstWhere(
              (payee) => _labelFor(payee!).toLowerCase() == normalized,
              orElse: () => null,
            );
            onChanged(exactMatch?.id);
          },
          style: AppTypography.body.copyWith(color: colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: 'Search or create payee',
            hintStyle: AppTypography.body.copyWith(
              color: lootrColors.textTertiary,
            ),
            prefixIcon: const Icon(Icons.search, size: 18),
            filled: true,
            fillColor: colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: colorScheme.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: colorScheme.primary),
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final colorScheme = Theme.of(context).colorScheme;
        final lootrColors = context.lootrColors;

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, minWidth: 240),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final payee = options.elementAt(index);
                  final label = _labelFor(payee);
                  final isSelected = payee.id == selectedPayeeId;
                  return InkWell(
                    onTap: () => onSelected(payee),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: AppTypography.body.copyWith(
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check,
                              size: 16,
                              color: lootrColors.success,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
