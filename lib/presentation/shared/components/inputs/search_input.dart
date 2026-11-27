import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/typography.dart';

/// Search field with a clear button and a debounced [onChanged] callback.
class SearchInput extends StatefulWidget {
  const SearchInput({
    super.key,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.hintText = 'Search',
    this.autofocus = false,
    this.debounceDuration = const Duration(milliseconds: 300),
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final String hintText;
  final bool autofocus;
  final Duration debounceDuration;

  @override
  State<SearchInput> createState() => _SearchInputState();
}

class _SearchInputState extends State<SearchInput> {
  late TextEditingController _controller;
  late bool _ownsController;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant SearchInput oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      _debounce?.cancel();
      _controller.removeListener(_handleControllerChanged);
      if (_ownsController) {
        _controller.dispose();
      }
      _ownsController = widget.controller == null;
      _controller = widget.controller ?? TextEditingController();
      _controller.addListener(_handleControllerChanged);
    }
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onTextChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(widget.debounceDuration, () {
      if (_controller.text == value) widget.onChanged?.call(value);
    });
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    widget.onChanged?.call('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_handleControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lootrColors = context.lootrColors;
    final hasText = _controller.text.isNotEmpty;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: colorScheme.outline),
    );

    return TextField(
      controller: _controller,
      focusNode: widget.focusNode,
      onChanged: _onTextChanged,
      onSubmitted: (value) {
        if (_debounce?.isActive != true) return;
        _debounce?.cancel();
        widget.onChanged?.call(value);
      },
      autofocus: widget.autofocus,
      textInputAction: TextInputAction.search,
      style: AppTypography.body.copyWith(color: colorScheme.onSurface),
      decoration: InputDecoration(
        filled: true,
        fillColor: colorScheme.surface,
        hintText: widget.hintText,
        hintStyle: AppTypography.body.copyWith(
          color: lootrColors.textSecondary,
        ),
        prefixIcon: Icon(
          Icons.search,
          size: 20,
          color: lootrColors.textSecondary,
        ),
        suffixIcon: hasText
            ? IconButton(
                tooltip: 'Clear search',
                onPressed: _clear,
                icon: const Icon(Icons.close, size: 18),
              )
            : null,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: colorScheme.primary),
        ),
        constraints: const BoxConstraints(minHeight: 48),
        isDense: true,
        contentPadding: const EdgeInsetsDirectional.fromSTEB(12, 8, 16, 8),
      ),
    );
  }
}
