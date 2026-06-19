import 'package:flutter/material.dart';

abstract class AppColors {
  AppColors._();

  // Primary scale
  static const Color primary50 = Color(0xFFEFF6FF);
  static const Color primary100 = Color(0xFFDBEAFE);
  static const Color primary200 = Color(0xFFBFDBFE);
  static const Color primary500 = Color(0xFF3B82F6);
  static const Color primary600 = Color(0xFF2563EB);
  static const Color primary700 = Color(0xFF1D4ED8);

  // Semantic — Success
  static const Color success50 = Color(0xFFECFDF5);
  static const Color success500 = Color(0xFF10B981);
  static const Color success600 = Color(0xFF059669);

  // Semantic — Warning
  static const Color warning50 = Color(0xFFFFFBEB);
  static const Color warning500 = Color(0xFFF59E0B);
  static const Color warning600 = Color(0xFFD97706);

  // Semantic — Danger
  static const Color danger50 = Color(0xFFFEF2F2);
  static const Color danger500 = Color(0xFFEF4444);
  static const Color danger600 = Color(0xFFDC2626);

  // Neutral — Light
  static const Color lightBg = Color(0xFFFAFAFA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E4E8);
  static const Color lightBorderSubtle = Color(0xFFF2F4F7);
  static const Color lightTextPrimary = Color(0xFF1B1B1F);
  static const Color lightTextSecondary = Color(0xFF63666E);
  static const Color lightTextTertiary = Color(0xFFA1A5AD);

  // Neutral — Dark
  static const Color darkBg = Color(0xFF0F0F11);
  static const Color darkSurface = Color(0xFF1A1A1E);
  static const Color darkSurfaceElevated = Color(0xFF242428);
  static const Color darkBorder = Color(0xFF2E2E33);
  static const Color darkBorderSubtle = Color(0xFF1F1F23);
  static const Color darkTextPrimary = Color(0xFFF0F0F5);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);
  static const Color darkTextTertiary = Color(0xFF6B7280);

  // Primary — Dark
  static const Color darkPrimary500 = Color(0xFF60A5FA);
  static const Color darkPrimary600 = Color(0xFF3B82F6);
  static const Color darkPrimary700 = Color(0xFF2563EB);

  // Semantic — Dark
  static const Color darkSuccess50 = Color(0xFF064E3B);
  static const Color darkSuccess500 = Color(0xFF34D399);
  static const Color darkSuccess600 = Color(0xFF10B981);
  static const Color darkWarning50 = Color(0xFF78350F);
  static const Color darkWarning500 = Color(0xFFFBBF24);
  static const Color darkWarning600 = Color(0xFFF59E0B);
  static const Color darkDanger50 = Color(0xFF7F1D1D);
  static const Color darkDanger500 = Color(0xFFF87171);
  static const Color darkDanger600 = Color(0xFFEF4444);

  // Transaction direction — Light
  static const Color expense = Color(0xFFDC2626);
  static const Color income = Color(0xFF059669);
  static const Color transfer = Color(0xFF2563EB);

  // Transaction direction — Dark
  static const Color darkExpense = Color(0xFFEF4444);
  static const Color darkIncome = Color(0xFF10B981);
  static const Color darkTransfer = Color(0xFF3B82F6);
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
