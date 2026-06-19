import 'package:flutter/material.dart';
import 'spacing.dart';

class ResponsivePagePadding extends StatelessWidget {
  const ResponsivePagePadding({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double horizontalPadding;
        if (constraints.maxWidth >= 900) {
          horizontalPadding = AppSpacing.pagePaddingDesktop;
        } else if (constraints.maxWidth >= 600) {
          horizontalPadding = AppSpacing.pagePaddingTablet;
        } else {
          horizontalPadding = AppSpacing.pagePaddingMobile;
        }

        final double contentMaxWidth = constraints.maxWidth >= 900
            ? AppSpacing.pageMaxWidth
            : double.infinity;

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
