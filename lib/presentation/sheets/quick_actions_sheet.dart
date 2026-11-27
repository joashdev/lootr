import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../application/providers/ai_settings_provider.dart';
import '../../core/router/receipt_scan_route.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/typography.dart';
import '../../domain/value_objects/field_types.dart';
import '../shared/components/buttons/primary_button.dart';
import '../shared/components/sheet_handle.dart';
import 'add_transaction_sheet.dart';

class QuickActionsSheet extends ConsumerStatefulWidget {
  const QuickActionsSheet({super.key});

  @override
  ConsumerState<QuickActionsSheet> createState() => _QuickActionsSheetState();
}

class _QuickActionsSheetState extends ConsumerState<QuickActionsSheet> {
  final TextEditingController _quickInputController = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  String? _voiceError;

  @override
  void dispose() {
    _speech.cancel();
    _quickInputController.dispose();
    super.dispose();
  }

  void _navigate(String location, {AddTransactionSheetArgs? extra}) {
    final router = GoRouter.of(context);
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();
    router.push(location, extra: extra);
  }

  Future<void> _openScan() async {
    FocusScope.of(context).unfocus();
    final receipt = await ReceiptScanRequest.open(context);
    if (!mounted || receipt == null) return;
    _navigate(
      '/transactions/new',
      extra: AddTransactionSheetArgs.fromReceipt(receipt),
    );
  }

  void _openQuickAdd() {
    final initialQuickText = _quickInputController.text.trim();
    if (initialQuickText.isEmpty) return;
    _navigate(
      '/transactions/new',
      extra: AddTransactionSheetArgs(
        startInQuickMode: true,
        initialQuickText: initialQuickText,
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

    setState(() => _voiceError = null);
    final available = await _speech.initialize();
    if (!mounted) return;
    if (!available) {
      setState(() => _voiceError = 'Voice input is unavailable.');
      return;
    }

    _speech.statusListener = (status) {
      if (mounted &&
          (status == SpeechToText.doneStatus ||
              status == SpeechToText.notListeningStatus)) {
        setState(() => _isListening = false);
      }
    };
    _speech.errorListener = (_) {
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _voiceError = 'Voice input could not start.';
      });
    };
    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _quickInputController.text = result.recognizedWords.trim();
          _quickInputController.selection = TextSelection.collapsed(
            offset: _quickInputController.text.length,
          );
        });
      },
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final assistanceEnabled = ref.watch(smartEntryAssistanceEnabledProvider);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
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
                      style: AppTypography.h1.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.surfaceContainerLow,
                    ),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (assistanceEnabled) ...[
                TextField(
                  controller: _quickInputController,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _openQuickAdd(),
                  decoration: InputDecoration(
                    labelText: 'Description',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    hintText: 'Coffee ₱180',
                    hintStyle: TextStyle(color: colorScheme.secondary),
                    errorText: _voiceError,
                    filled: true,
                    fillColor: colorScheme.surfaceContainerLow,
                    border: inputBorder,
                    enabledBorder: inputBorder.copyWith(
                      borderSide: BorderSide(color: colorScheme.outline),
                    ),
                    suffixIcon: IconButton(
                      tooltip: _isListening
                          ? 'Stop listening'
                          : 'Start voice input',
                      onPressed: _toggleSpeechInput,
                      icon: Icon(
                        _isListening ? LucideIcons.audioLines : LucideIcons.mic,
                        color: _isListening
                            ? colorScheme.onSurface
                            : colorScheme.primary,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              PrimaryButton(
                label: assistanceEnabled
                    ? 'Review transaction'
                    : 'Add manually',
                onPressed: !assistanceEnabled
                    ? () => _navigate('/transactions/new')
                    : _quickInputController.text.trim().isEmpty
                    ? null
                    : _openQuickAdd,
                icon: Icon(
                  assistanceEnabled
                      ? LucideIcons.arrowRight
                      : LucideIcons.pencil,
                  size: 17,
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final textScale =
                      MediaQuery.textScalerOf(context).scale(15) / 15;
                  final twoColumns = constraints.maxWidth >= 270 * textScale;
                  final width = twoColumns
                      ? (constraints.maxWidth - 8) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: width,
                        child: _AddShortcut(
                          icon: LucideIcons.scanLine,
                          label: 'Scan receipt',
                          onTap: _openScan,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _AddShortcut(
                          icon: LucideIcons.arrowLeftRight,
                          label: 'Transfer',
                          onTap: () => _navigate(
                            '/transactions/new',
                            extra: const AddTransactionSheetArgs(
                              initialDirection: TransactionDirection.transfer,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton.icon(
                  onPressed: assistanceEnabled
                      ? () => _navigate('/transactions/new')
                      : () => _navigate('/more/settings/ai'),
                  icon: Icon(
                    assistanceEnabled
                        ? LucideIcons.pencil
                        : LucideIcons.sparkles,
                    size: 17,
                  ),
                  label: Text(
                    assistanceEnabled ? 'Add manually' : 'Turn on Quick entry',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddShortcut extends StatelessWidget {
  const _AddShortcut({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppRadius.lg);
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: colors.primaryContainer,
                foregroundColor: colors.onPrimaryContainer,
                child: Icon(icon, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: AppTypography.bodyMedium)),
            ],
          ),
        ),
      ),
    );
  }
}
