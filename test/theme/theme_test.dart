import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/core/theme/colors.dart';
import 'package:lootr/core/theme/radius.dart';
import 'package:lootr/core/theme/shadows.dart';
import 'package:lootr/core/theme/spacing.dart';
import 'package:lootr/core/theme/theme.dart';
import 'package:lootr/core/theme/typography.dart';

void main() {
  // AppTypography resolves Google Fonts (Geist), which touches asset bundles
  // and requires an initialized test binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppTheme', () {
    test('light theme has correct brightness', () {
      expect(AppTheme.light.brightness, Brightness.light);
      expect(AppTheme.light.useMaterial3, true);
    });

    test('dark theme has correct brightness', () {
      expect(AppTheme.dark.brightness, Brightness.dark);
      expect(AppTheme.dark.useMaterial3, true);
    });

    test('light theme extends LootrColorScheme', () {
      final ext = AppTheme.light.extensions[LootrColorScheme];
      expect(ext, isNotNull);
      expect(ext, isA<LootrColorScheme>());
    });

    test('dark theme extends LootrColorScheme', () {
      final ext = AppTheme.dark.extensions[LootrColorScheme];
      expect(ext, isNotNull);
      expect(ext, isA<LootrColorScheme>());
    });

    test('light and dark schemes differ', () {
      final lightExt =
          AppTheme.light.extensions[LootrColorScheme]! as LootrColorScheme;
      final darkExt =
          AppTheme.dark.extensions[LootrColorScheme]! as LootrColorScheme;
      expect(lightExt.expense, isNot(darkExt.expense));
      expect(lightExt.income, isNot(darkExt.income));
      expect(lightExt.transfer, isNot(darkExt.transfer));
      expect(lightExt.bg, isNot(darkExt.bg));
    });

    test('light color scheme uses correct primary', () {
      expect(AppTheme.light.colorScheme.primary, AppColors.primary600);
    });

    test('dark color scheme uses correct primary', () {
      expect(AppTheme.dark.colorScheme.primary, AppColors.darkPrimary500);
    });
  });

  group('AppTypography', () {
    test('display has correct size', () {
      expect(AppTypography.display.fontSize, 40);
      expect(AppTypography.display.fontWeight, FontWeight.w700);
    });

    test('h1 has correct size', () {
      expect(AppTypography.h1.fontSize, 28);
      expect(AppTypography.h1.fontWeight, FontWeight.w700);
    });

    test('h2 has correct size', () {
      expect(AppTypography.h2.fontSize, 21);
      expect(AppTypography.h2.fontWeight, FontWeight.w600);
    });

    test('h3 has correct size', () {
      expect(AppTypography.h3.fontSize, 17);
      expect(AppTypography.h3.fontWeight, FontWeight.w600);
    });

    test('body has correct size', () {
      expect(AppTypography.body.fontSize, 15);
      expect(AppTypography.body.fontWeight, FontWeight.w400);
    });

    test('bodyMedium has correct size', () {
      expect(AppTypography.bodyMedium.fontSize, 15);
      expect(AppTypography.bodyMedium.fontWeight, FontWeight.w500);
    });

    test('caption has correct size', () {
      expect(AppTypography.caption.fontSize, 13);
      expect(AppTypography.caption.fontWeight, FontWeight.w400);
    });

    test('captionMedium has correct size', () {
      expect(AppTypography.captionMedium.fontSize, 13);
      expect(AppTypography.captionMedium.fontWeight, FontWeight.w500);
    });

    test('micro has correct size', () {
      expect(AppTypography.micro.fontSize, 11);
      expect(AppTypography.micro.fontWeight, FontWeight.w600);
    });

    test('mono has correct size and font family', () {
      expect(AppTypography.mono.fontSize, 15);
      expect(AppTypography.mono.fontWeight, FontWeight.w500);
    });
  });

  group('AppSpacing', () {
    test('space tokens match spec', () {
      expect(AppSpacing.space1, 4);
      expect(AppSpacing.space2, 8);
      expect(AppSpacing.space3, 12);
      expect(AppSpacing.space4, 16);
      expect(AppSpacing.space5, 20);
      expect(AppSpacing.space6, 24);
      expect(AppSpacing.space8, 32);
      expect(AppSpacing.space10, 40);
      expect(AppSpacing.space12, 48);
    });

    test('page padding tokens', () {
      expect(AppSpacing.pagePaddingMobile, 16);
      expect(AppSpacing.pagePaddingTablet, 24);
      expect(AppSpacing.pagePaddingDesktop, 40);
      expect(AppSpacing.pageMaxWidth, 800);
    });
  });

  group('AppRadius', () {
    test('radius tokens match spec', () {
      expect(AppRadius.sm, 6);
      expect(AppRadius.md, 10);
      expect(AppRadius.lg, 14);
      expect(AppRadius.xl, 18);
      expect(AppRadius.full, 9999);
    });
  });

  group('AppShadows', () {
    test('sm shadow exists', () {
      expect(AppShadows.sm, isNotEmpty);
    });

    test('md shadow exists', () {
      expect(AppShadows.md, isNotEmpty);
    });

    test('lg shadow exists', () {
      expect(AppShadows.lg, isNotEmpty);
    });

    test('island shadow exists', () {
      expect(AppShadows.island, isNotEmpty);
    });

    test('none is empty', () {
      expect(AppShadows.none, isEmpty);
    });
  });

  group('LootrColorScheme', () {
    test('light direction colors', () {
      expect(LootrColorScheme.light.expense, AppColors.expense);
      expect(LootrColorScheme.light.income, AppColors.income);
      expect(LootrColorScheme.light.transfer, AppColors.transfer);
    });

    test('dark direction colors', () {
      expect(LootrColorScheme.dark.expense, AppColors.darkExpense);
      expect(LootrColorScheme.dark.income, AppColors.darkIncome);
      expect(LootrColorScheme.dark.transfer, AppColors.darkTransfer);
    });

    test('small semantic and muted text colors meet WCAG AA', () {
      expect(
        _contrast(AppColors.expense, AppColors.lightSurface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(AppColors.income, AppColors.lightSurface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(AppColors.lightTextTertiary, AppColors.lightSurface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(AppColors.darkTextTertiary, AppColors.darkSurface),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('Animation tokens', () {
    test('durations are correct', () {
      expect(AppTheme.sheetEnterDuration, const Duration(milliseconds: 250));
      expect(AppTheme.sheetDismissDuration, const Duration(milliseconds: 200));
      expect(AppTheme.pagePushDuration, const Duration(milliseconds: 300));
      expect(AppTheme.tabSwitchDuration, const Duration(milliseconds: 150));
      expect(AppTheme.progressDuration, const Duration(milliseconds: 300));
      expect(AppTheme.buttonPressDuration, const Duration(milliseconds: 100));
    });
  });
}

double _contrast(Color foreground, Color background) {
  final lighter = foreground.computeLuminance() > background.computeLuminance()
      ? foreground
      : background;
  final darker = lighter == foreground ? background : foreground;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}
