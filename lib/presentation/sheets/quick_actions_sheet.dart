import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/typography.dart';
import '../shared/components/sheet_handle.dart';
import '../shared/components/app_snackbar.dart';
import 'add_transaction_sheet.dart';

class QuickActionsSheet extends StatelessWidget {
  const QuickActionsSheet({super.key});

  void _navigate(BuildContext context, String location, {Object? extra}) {
    Navigator.of(context).pop();
    context.push(location, extra: extra);
  }

  @override
  Widget build(BuildContext context) {
    return _QuickActionsSheetBody(
      onNavigate: (location, {extra}) =>
          _navigate(context, location, extra: extra),
    );
  }
}

class _QuickActionsSheetBody extends StatefulWidget {
  const _QuickActionsSheetBody({required this.onNavigate});

  final void Function(String location, {Object? extra}) onNavigate;

  @override
  State<_QuickActionsSheetBody> createState() => _QuickActionsSheetBodyState();
}

class _QuickActionsSheetBodyState extends State<_QuickActionsSheetBody> {
  final TextEditingController _quickInputController = TextEditingController();

  @override
  void dispose() {
    _quickInputController.dispose();
    super.dispose();
  }

  void _openQuickAdd() {
    final initialQuickText = _quickInputController.text.trim();
    widget.onNavigate(
      '/transactions/new',
      extra: AddTransactionSheetArgs(
        startInQuickMode: true,
        initialQuickText: initialQuickText.isEmpty ? null : initialQuickText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Add Transaction',
                    style: AppTypography.h2.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                _EntryModeDropdown(
                  onManual: () => widget.onNavigate('/transactions/new'),
                  onScan: () => widget.onNavigate('/scan'),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Describe it below, or pick a mode above.',
              style: AppTypography.body.copyWith(
                color: context.lootrColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.sparkles,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _quickInputController,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _openQuickAdd(),
                      decoration: InputDecoration(
                        hintText: 'Coffee at Starbucks ₱180',
                        hintStyle: AppTypography.body.copyWith(
                          color: context.lootrColors.textTertiary,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      AppSnackBar.show(
                        context,
                        'Voice input is not available in V1',
                        variant: AppSnackBarVariant.neutral,
                        duration: const Duration(seconds: 2),
                      );
                    },
                    icon: Icon(
                      LucideIcons.mic,
                      color: colorScheme.primary,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Try: "Grab ride ₱150" or "Salary ₱45k"',
                style: AppTypography.caption.copyWith(
                  color: context.lootrColors.textTertiary,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

enum _EntryMode { manual, scan }

/// Bordered "Manual ▾" dropdown pill for the quick-actions header, mirroring the
/// mode dropdown in the Add Transaction sheet. Selecting an option triggers the
/// matching entry flow immediately (Manual opens the full Add Transaction sheet,
/// Scan opens the OCR scan route).
class _EntryModeDropdown extends StatelessWidget {
  const _EntryModeDropdown({required this.onManual, required this.onScan});

  final VoidCallback onManual;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopupMenuButton<_EntryMode>(
      initialValue: _EntryMode.manual,
      onSelected: (mode) {
        switch (mode) {
          case _EntryMode.manual:
            onManual();
          case _EntryMode.scan:
            onScan();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: _EntryMode.manual, child: Text('Manual')),
        PopupMenuItem(value: _EntryMode.scan, child: Text('Scan')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Manual',
              style: AppTypography.captionMedium.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              LucideIcons.chevronDown,
              size: 16,
              color: context.lootrColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
