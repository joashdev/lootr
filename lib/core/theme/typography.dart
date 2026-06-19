import 'package:flutter/material.dart';

abstract class AppTypography {
  AppTypography._();

  static const String _monoFontFamily = 'monospace';
  static const List<String> _fontFamilyFallback = [
    '.SF Pro Display',
    '.SF Pro Text',
    '-apple-system',
    'BlinkMacSystemFont',
    'Segoe UI',
    'Roboto',
    'Helvetica',
    'Arial',
    'sans-serif',
  ];
  static const List<String> _monoFontFamilyFallback = [
    'SF Mono',
    'Fira Code',
    'Cascadia Code',
    'monospace',
  ];

  static TextStyle get display => const TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        height: 1.1,
        fontFamilyFallback: _fontFamilyFallback,
      );

  static TextStyle get h1 => const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.2,
        fontFamilyFallback: _fontFamilyFallback,
      );

  static TextStyle get h2 => const TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w600,
        height: 1.3,
        fontFamilyFallback: _fontFamilyFallback,
      );

  static TextStyle get h3 => const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.4,
        fontFamilyFallback: _fontFamilyFallback,
      );

  static TextStyle get body => const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.6,
        fontFamilyFallback: _fontFamilyFallback,
      );

  static TextStyle get bodyMedium => const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.6,
        fontFamilyFallback: _fontFamilyFallback,
      );

  static TextStyle get caption => const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.5,
        fontFamilyFallback: _fontFamilyFallback,
      );

  static TextStyle get captionMedium => const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.5,
        fontFamilyFallback: _fontFamilyFallback,
      );

  static TextStyle get micro => const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.4,
        fontFamilyFallback: _fontFamilyFallback,
      );

  static TextStyle get mono => const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.5,
        fontFamily: _monoFontFamily,
        fontFamilyFallback: _monoFontFamilyFallback,
      );

  static TextTheme get textTheme => TextTheme(
        displayLarge: display,
        headlineLarge: h1,
        headlineMedium: h2,
        titleLarge: h3,
        bodyLarge: body,
        bodyMedium: bodyMedium,
        bodySmall: caption,
        labelLarge: captionMedium,
        labelSmall: micro,
      );
}
