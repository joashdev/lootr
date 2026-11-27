import 'package:flutter/material.dart';

abstract class AppColors {
  AppColors._();

  // Primary scale — evergreen
  static const Color primary50 = Color(0xFFE7F0E9);
  static const Color primary100 = Color(0xFFD3E5D8);
  static const Color primary200 = Color(0xFFACCDB7);
  static const Color primary500 = Color(0xFF39775B);
  static const Color primary600 = Color(0xFF215843);
  static const Color primary700 = Color(0xFF194534);

  // Semantic — Success (income green)
  static const Color success50 = Color(0xFFE7F3E9);
  static const Color success500 = Color(0xFF378762);
  static const Color success600 = Color(0xFF236244);

  // Semantic — Warning (amber; used for "tight"/at-risk states)
  static const Color warning50 = Color(0xFFFAEDD9);
  static const Color warning500 = Color(0xFFCB873E);
  static const Color warning600 = Color(0xFF8D541E);

  // Semantic — Danger (terracotta for errors and over-budget states)
  static const Color danger50 = Color(0xFFFAEAE3);
  static const Color danger500 = Color(0xFFBD604B);
  static const Color danger600 = Color(0xFF993E2E);

  // Neutral — Light
  static const Color lightBg = Color(0xFFF6F4EF);
  static const Color lightSurface = Color(0xFFFFFEFA);
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFD9DDD5);
  static const Color lightBorderSubtle = Color(0xFFE8E9E1);
  static const Color lightTextPrimary = Color(0xFF182821);
  static const Color lightTextSecondary = Color(0xFF4E6256);
  static const Color lightTextTertiary = Color(0xFF5F6F64);

  // Neutral — Dark
  static const Color darkBg = Color(0xFF101713);
  static const Color darkSurface = Color(0xFF18231D);
  static const Color darkSurfaceElevated = Color(0xFF213028);
  static const Color darkBorder = Color(0xFF35463B);
  static const Color darkBorderSubtle = Color(0xFF29382E);
  static const Color darkTextPrimary = Color(0xFFF1F5ED);
  static const Color darkTextSecondary = Color(0xFFAFBDB1);
  static const Color darkTextTertiary = Color(0xFFA3B3A7);

  // Primary — Dark
  static const Color darkPrimary500 = Color(0xFFA1D5B2);
  static const Color darkPrimary600 = Color(0xFF81BD98);
  static const Color darkPrimary700 = Color(0xFF244634);

  // Semantic — Dark
  static const Color darkSuccess50 = Color(0xFF20372B);
  static const Color darkSuccess500 = Color(0xFFA0CEAA);
  static const Color darkSuccess600 = Color(0xFF88BD96);
  static const Color darkWarning50 = Color(0xFF423321);
  static const Color darkWarning500 = Color(0xFFEDBE7C);
  static const Color darkWarning600 = Color(0xFFE6B570);
  static const Color darkDanger50 = Color(0xFF482B24);
  static const Color darkDanger500 = Color(0xFFECA993);
  static const Color darkDanger600 = Color(0xFFE49A85);

  // Transaction direction — Light
  static const Color expense = lightTextPrimary;
  static const Color income = Color(0xFF236244);
  static const Color transfer = Color(0xFF335C83);

  // Transaction direction — Dark
  static const Color darkExpense = darkTextPrimary;
  static const Color darkIncome = Color(0xFFA0CEAA);
  static const Color darkTransfer = Color(0xFF98B9E0);
}

class LootrColorScheme extends ThemeExtension<LootrColorScheme> {
  const LootrColorScheme({
    required this.expense,
    required this.income,
    required this.transfer,
    required this.bg,
    required this.surfaceElevated,
    required this.borderSubtle,
    required this.textSecondary,
    required this.textTertiary,
    required this.success,
    required this.successBg,
    required this.warning,
    required this.warningBg,
    required this.danger,
    required this.dangerBg,
  });

  final Color expense;
  final Color income;
  final Color transfer;
  final Color bg;
  final Color surfaceElevated;
  final Color borderSubtle;
  final Color textSecondary;
  final Color textTertiary;
  final Color success;
  final Color successBg;
  final Color warning;
  final Color warningBg;
  final Color danger;
  final Color dangerBg;

  static const light = LootrColorScheme(
    expense: AppColors.expense,
    income: AppColors.income,
    transfer: AppColors.transfer,
    bg: AppColors.lightBg,
    surfaceElevated: AppColors.lightSurfaceElevated,
    borderSubtle: AppColors.lightBorderSubtle,
    textSecondary: AppColors.lightTextSecondary,
    textTertiary: AppColors.lightTextTertiary,
    success: AppColors.success600,
    successBg: AppColors.success50,
    warning: AppColors.warning600,
    warningBg: AppColors.warning50,
    danger: AppColors.danger600,
    dangerBg: AppColors.danger50,
  );

  static const dark = LootrColorScheme(
    expense: AppColors.darkExpense,
    income: AppColors.darkIncome,
    transfer: AppColors.darkTransfer,
    bg: AppColors.darkBg,
    surfaceElevated: AppColors.darkSurfaceElevated,
    borderSubtle: AppColors.darkBorderSubtle,
    textSecondary: AppColors.darkTextSecondary,
    textTertiary: AppColors.darkTextTertiary,
    success: AppColors.darkSuccess600,
    successBg: AppColors.darkSuccess50,
    warning: AppColors.darkWarning600,
    warningBg: AppColors.darkWarning50,
    danger: AppColors.darkDanger600,
    dangerBg: AppColors.darkDanger50,
  );

  @override
  LootrColorScheme copyWith({
    Color? expense,
    Color? income,
    Color? transfer,
    Color? bg,
    Color? surfaceElevated,
    Color? borderSubtle,
    Color? textSecondary,
    Color? textTertiary,
    Color? success,
    Color? successBg,
    Color? warning,
    Color? warningBg,
    Color? danger,
    Color? dangerBg,
  }) {
    return LootrColorScheme(
      expense: expense ?? this.expense,
      income: income ?? this.income,
      transfer: transfer ?? this.transfer,
      bg: bg ?? this.bg,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      success: success ?? this.success,
      successBg: successBg ?? this.successBg,
      warning: warning ?? this.warning,
      warningBg: warningBg ?? this.warningBg,
      danger: danger ?? this.danger,
      dangerBg: dangerBg ?? this.dangerBg,
    );
  }

  @override
  LootrColorScheme lerp(ThemeExtension<LootrColorScheme>? other, double t) {
    if (other is! LootrColorScheme) return this;
    return LootrColorScheme(
      expense: Color.lerp(expense, other.expense, t)!,
      income: Color.lerp(income, other.income, t)!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
      bg: Color.lerp(bg, other.bg, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      success: Color.lerp(success, other.success, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerBg: Color.lerp(dangerBg, other.dangerBg, t)!,
    );
  }
}

extension LootrColorSchemeX on BuildContext {
  LootrColorScheme get lootrColors =>
      Theme.of(this).extension<LootrColorScheme>()!;
}
