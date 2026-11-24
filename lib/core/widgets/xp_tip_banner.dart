import 'package:flutter/material.dart';
import '../../app/theme/glossa_colors.dart';
import '../../app/theme/glossa_typography.dart';
import '../../core/constants/spacing.dart';

/// Yellow XP tip banner that appears in lesson screens.
/// Shows "+5 XP" badge and a motivational tip.
class XpTipBanner extends StatelessWidget {
  final String tip;
  final int xpAmount;

  const XpTipBanner({
    super.key,
    required this.tip,
    this.xpAmount = 5,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.md,
      ),
      decoration: BoxDecoration(
        color: GlossaColors.yellowPrimary.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(Spacing.cardRadius),
        border: Border.all(
          color: GlossaColors.yellowPrimary,
          width: Spacing.borderWidthThin,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: GlossaColors.redAction,
              borderRadius: BorderRadius.circular(Spacing.badgeRadius),
            ),
            child: Text(
              '+$xpAmount XP',
              style: GlossaTypography.labelSmall.copyWith(
                color: GlossaColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Text(
              tip,
              style: GlossaTypography.bodySmall.copyWith(
                color: GlossaColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
