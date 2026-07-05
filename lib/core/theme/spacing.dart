abstract class AppSpacing {
  AppSpacing._();

  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;
  static const double space10 = 40;
  static const double space12 = 48;

  static const double pagePaddingMobile = 16;
  static const double pagePaddingTablet = 24;
  static const double pagePaddingDesktop = 40;
  static const double pageMaxWidth = 800;

  static const double cardPaddingStandard = 16;
  static const double cardPaddingCompact = 12;
  static const double sheetPaddingHorizontal = 20;
  static const double sheetPaddingVertical = 16;

  /// Bottom clearance for scrollable content so the last items are not hidden
  /// behind the floating bottom nav (56 pill + 16 gap + 16 breathing room).
  /// Add `MediaQuery.paddingOf(context).bottom` on top for the safe area.
  static const double bottomNavClearance = 88;
}
