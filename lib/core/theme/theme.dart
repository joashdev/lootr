import 'package:flutter/material.dart';

import 'colors.dart';
import 'typography.dart';

abstract class AppTheme {
  AppTheme._();

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorSchemeSeed: AppColors.primary,
    textTheme: AppTypography.textTheme,
  );

  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorSchemeSeed: AppColors.primary,
    textTheme: AppTypography.textTheme,
  );
}
