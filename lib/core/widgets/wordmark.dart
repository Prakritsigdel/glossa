import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// "GLOSSA" in the pixel display face with a hard red offset shadow.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    final offset = size * 0.1;
    return Semantics(
      header: true,
      label: 'Glossa',
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.only(right: offset, bottom: offset),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Transform.translate(
              offset: Offset(offset, offset),
              child: Text(
                'GLOSSA',
                style: AppTextStyles.display.copyWith(
                  fontSize: size,
                  color: AppColors.red,
                ),
              ),
            ),
            Text(
              'GLOSSA',
              style: AppTextStyles.display.copyWith(fontSize: size),
            ),
          ],
        ),
      ),
    );
  }
}
