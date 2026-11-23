import 'package:material_ui/material_ui.dart';
import '../../app/theme/glossa_colors.dart';
import '../../core/constants/spacing.dart';
import '../motion/glossa_motion.dart';

/// Rounded card with thick navy outline, matching the RPG design.
/// Animates color and border transitions when selection state changes.
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
    final reduceMotion = GlossaMotion.shouldReduceMotion(context);
    final effectiveBg = isSelected
        ? GlossaColors.yellowPrimary
        : (backgroundColor ?? GlossaColors.white);

    final effectiveBorderColor = isSelected ? GlossaColors.blueNavy : borderColor;
    final effectiveBorderWidth = isSelected ? (borderWidth + 0.5) : borderWidth;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: reduceMotion ? Duration.zero : GlossaMotion.selection,
        curve: GlossaMotion.snappy,
        padding: padding ?? const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: effectiveBg,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: effectiveBorderColor,
            width: effectiveBorderWidth,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? GlossaColors.blueNavy : GlossaColors.cardShadow,
              offset: isSelected ? const Offset(0, 3) : const Offset(0, 2),
              blurRadius: isSelected ? 0 : 4,
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
