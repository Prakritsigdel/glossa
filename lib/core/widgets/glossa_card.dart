import 'package:flutter/material.dart';
import '../../app/theme/glossa_colors.dart';
import '../../core/constants/spacing.dart';

/// Rounded card with thick navy outline, matching the RPG design.
class GlossaCard extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool isSelected;

  const GlossaCard({
    super.key,
    required this.child,
    this.backgroundColor,
    this.borderColor = GlossaColors.blueNavy,
    this.borderWidth = Spacing.borderWidth,
    this.borderRadius = Spacing.cardRadius,
    this.padding,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBg = isSelected
        ? GlossaColors.yellowPrimary
        : (backgroundColor ?? GlossaColors.white);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: effectiveBg,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: borderColor,
            width: borderWidth,
          ),
          boxShadow: const [
            BoxShadow(
              color: GlossaColors.cardShadow,
              offset: Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
