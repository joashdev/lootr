import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/typography.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.hintText,
    this.onChanged,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController? controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool autofocus;
  final TextCapitalization textCapitalization;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lootrColors = context.lootrColors;
    final effectiveBgColor = _isFocused
        ? colorScheme.primaryContainer
        : colorScheme.surface;
    final effectiveBorderColor = _isFocused
        ? colorScheme.primary
        : colorScheme.outline;

    return Container(
      decoration: BoxDecoration(
        color: effectiveBgColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: effectiveBorderColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (widget.prefixIcon != null) ...[
            widget.prefixIcon!,
            const SizedBox(width: 8),
          ],
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onChanged: widget.onChanged,
              obscureText: widget.obscureText,
              keyboardType: widget.keyboardType,
              maxLines: widget.maxLines,
              autofocus: widget.autofocus,
              textCapitalization: widget.textCapitalization,
              style: AppTypography.body.copyWith(color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: AppTypography.body.copyWith(
                  color: lootrColors.textTertiary,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (widget.suffixIcon != null) ...[
            const SizedBox(width: 8),
            widget.suffixIcon!,
          ],
        ],
      ),
    );
  }
}
