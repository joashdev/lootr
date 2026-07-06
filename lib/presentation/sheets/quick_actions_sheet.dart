import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:speech_to_text/speech_to_text.dart';

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
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;

  @override
  void dispose() {
    _speech.cancel();
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

  Future<void> _toggleSpeechInput() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) {
        setState(() => _isListening = false);
      }
      return;
    }

    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _isListening = false);
        AppSnackBar.show(
          context,
          'Voice input could not start on this device.',
          variant: AppSnackBarVariant.warning,
        );
      },
    );

    if (!available) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        'Voice input is unavailable on this device.',
        variant: AppSnackBarVariant.warning,
      );
      return;
    }

    setState(() => _isListening = true);
    await _speech.listen(
      listenMode: ListenMode.dictation,
      partialResults: true,
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _quickInputController.text = result.recognizedWords.trim();
          _quickInputController.selection = TextSelection.collapsed(
            offset: _quickInputController.text.length,
          );
        });
      },
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
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // This sheet IS quick (NL) mode, so Quick is always the active
            // segment; Manual/Scan hand off to their dedicated flows in one tap.
            EntryModeTabs(
              selected: EntryMode.quick,
              onSelected: (mode) {
                switch (mode) {
                  case EntryMode.quick:
                    break; // Already in quick mode.
                  case EntryMode.manual:
                    widget.onNavigate('/transactions/new');
                  case EntryMode.scan:
                    widget.onNavigate('/scan');
                }
              },
            ),
            const SizedBox(height: 12),
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
                    tooltip: _isListening ? 'Stop listening' : 'Start voice input',
                    onPressed: _toggleSpeechInput,
                    icon: Icon(
                      _isListening ? LucideIcons.audioLines : LucideIcons.mic,
                      color: _isListening
                          ? colorScheme.onSurface
                          : colorScheme.primary,
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
