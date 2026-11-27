import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/typography.dart';

class DashboardSectionHeader extends StatelessWidget {
  const DashboardSectionHeader({
    super.key,
    required this.title,
    required this.actionLabel,
    required this.onPressed,
    this.actionText = 'See all',
  });

  final String title;
  final String actionLabel;
  final VoidCallback onPressed;
  final String actionText;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Semantics(
            header: true,
            child: Text(title, style: AppTypography.h2),
          ),
        ),
        const SizedBox(width: AppSpacing.space1),
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: onPressed,
              child: Text(
                actionText,
                semanticsLabel: actionLabel,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
