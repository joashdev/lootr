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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Add Transaction',
                style: AppTypography.h2.copyWith(color: colorScheme.onSurface),
              ),
            ),
            Text(
              'How would you like to add it?',
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
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    icon: LucideIcons.pencilLine,
                    label: 'Manual Entry',
                    subtitle: 'Fill in details',
                    color: AppColors.primary700,
                    onTap: () => widget.onNavigate('/transactions/new'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionCard(
                    icon: LucideIcons.camera,
                    label: 'Scan Receipt',
                    subtitle: 'OCR capture',
                    color: AppColors.success600,
                    onTap: () => widget.onNavigate('/scan'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 152),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: context.lootrColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
