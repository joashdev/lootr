import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radius.dart';

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final lootrColors = context.lootrColors;

    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 8),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: lootrColors.textTertiary,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
      ),
    );
  }
}
