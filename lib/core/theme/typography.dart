import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract class AppTypography {
  AppTypography._();

  static TextStyle get display => GoogleFonts.geist(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: -1.2,
  );

  static TextStyle get h1 => GoogleFonts.geist(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.6,
  );

  static TextStyle get h2 => GoogleFonts.geist(
    fontSize: 21,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.3,
  );

  static TextStyle get h3 => GoogleFonts.geist(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: -0.2,
  );

  static TextStyle get body =>
      GoogleFonts.geist(fontSize: 15, fontWeight: FontWeight.w400, height: 1.6);

  static TextStyle get bodyMedium => GoogleFonts.geist(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.6,
    letterSpacing: -0.1,
  );

  static TextStyle get caption =>
      GoogleFonts.geist(fontSize: 13, fontWeight: FontWeight.w400, height: 1.5);

  static TextStyle get captionMedium => GoogleFonts.geist(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.5,
    letterSpacing: -0.1,
  );

  static TextStyle get micro => GoogleFonts.geist(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.4,
  );

  static TextStyle get mono => GoogleFonts.geistMono(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.5,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  // Headline-sized numeric styles — Geist Mono with tabular figures so hero
  // figures match the rest of the app's amounts instead of falling back to the
  // proportional sans display/h1 styles.
  static TextStyle get displayMono => GoogleFonts.geistMono(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: -0.5,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle get h1Mono => GoogleFonts.geistMono(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.3,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle get h2Mono => GoogleFonts.geistMono(
    fontSize: 21,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.2,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle get h3Mono => GoogleFonts.geistMono(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: -0.1,
    fontFeatures: const [FontFeature.tabularFigures()],
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
