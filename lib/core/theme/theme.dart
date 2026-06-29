import 'package:flutter/material.dart';

import 'colors.dart';
import 'radius.dart';
import 'spacing.dart';
import 'typography.dart';

abstract class AppTheme {
  AppTheme._();

  // Animation curves
  static const Curve sheetEnterCurve = Cubic(0.32, 0.72, 0, 1);
  static const Curve sheetDismissCurve = Cubic(0.32, 0.72, 0, 1);
  static const Curve pagePushCurve = Cubic(0.4, 0, 0.2, 1);
  static const Curve tabSwitchCurve = Curves.easeInOut;
  static const Curve progressCurve = Curves.easeOut;
  static const Curve buttonPressCurve = Curves.easeOut;
  static const Curve snackbarEnterCurve = Curves.easeOut;
  static const Curve snackbarExitCurve = Curves.easeIn;

  // Animation durations
  static const Duration sheetEnterDuration = Duration(milliseconds: 250);
  static const Duration sheetDismissDuration = Duration(milliseconds: 200);
  static const Duration pagePushDuration = Duration(milliseconds: 300);
  static const Duration tabSwitchDuration = Duration(milliseconds: 150);
  static const Duration progressDuration = Duration(milliseconds: 300);
  static const Duration buttonPressDuration = Duration(milliseconds: 100);
  static const Duration snackbarEnterDuration = Duration(milliseconds: 200);
  static const Duration snackbarExitDuration = Duration(milliseconds: 150);

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary600,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primary50,
      onPrimaryContainer: AppColors.primary700,
      secondary: AppColors.lightTextSecondary,
      onSecondary: Colors.white,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
      surfaceContainerHighest: AppColors.lightSurfaceElevated,
      surfaceContainerLow: AppColors.lightBg,
      error: AppColors.danger500,
      onError: Colors.white,
      errorContainer: AppColors.danger50,
      onErrorContainer: AppColors.danger600,
      outline: AppColors.lightBorder,
      outlineVariant: AppColors.lightBorderSubtle,
    ),
    textTheme: AppTypography.textTheme,
    scaffoldBackgroundColor: AppColors.lightBg,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.lightBg,
      foregroundColor: AppColors.lightTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 80,
      titleSpacing: AppSpacing.pagePaddingMobile,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.lightSurface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.lightBorderSubtle,
      thickness: 1,
      space: 1,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary600,
        textStyle: AppTypography.captionMedium,
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.lightTextSecondary,
        minimumSize: const Size(40, 40),
        padding: const EdgeInsets.all(8),
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    ),
    extensions: const [LootrColorScheme.light],
  );

  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.darkPrimary500,
      onPrimary: Colors.white,
      primaryContainer: AppColors.darkPrimary700,
      onPrimaryContainer: AppColors.primary50,
      secondary: AppColors.darkTextSecondary,
      onSecondary: Colors.white,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      surfaceContainerHighest: AppColors.darkSurfaceElevated,
      surfaceContainerLow: AppColors.darkBg,
      error: AppColors.darkDanger500,
      onError: Colors.white,
      errorContainer: AppColors.darkDanger50,
      onErrorContainer: AppColors.darkDanger600,
      outline: AppColors.darkBorder,
      outlineVariant: AppColors.darkBorderSubtle,
    ),
    textTheme: AppTypography.textTheme,
    scaffoldBackgroundColor: AppColors.darkBg,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.darkBg,
      foregroundColor: AppColors.darkTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 80,
      titleSpacing: AppSpacing.pagePaddingMobile,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.darkSurface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.darkBorderSubtle,
      thickness: 1,
      space: 1,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.darkPrimary500,
        textStyle: AppTypography.captionMedium,
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.darkTextSecondary,
        minimumSize: const Size(40, 40),
        padding: const EdgeInsets.all(8),
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    ),
    extensions: const [LootrColorScheme.dark],
  );
}
