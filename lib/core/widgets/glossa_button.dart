import 'package:flutter/material.dart';
import '../../app/theme/glossa_colors.dart';
import '../../core/constants/spacing.dart';

/// Primary action button (red), secondary (yellow), dark (navy).
enum GlossaButtonStyle { primary, secondary, dark }

class GlossaButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final GlossaButtonStyle style;
  final bool isLoading;
  final double? width;

  const GlossaButton({
    super.key,
    required this.label,
    this.onPressed,
    this.style = GlossaButtonStyle.primary,
    this.isLoading = false,
    this.width,
  });

  Color get _backgroundColor {
    switch (style) {
      case GlossaButtonStyle.primary:
        return GlossaColors.redAction;
      case GlossaButtonStyle.secondary:
        return GlossaColors.yellowPrimary;
      case GlossaButtonStyle.dark:
        return GlossaColors.blueNavy;
    }
  }

  Color get _foregroundColor {
    switch (style) {
      case GlossaButtonStyle.primary:
        return GlossaColors.white;
      case GlossaButtonStyle.secondary:
        return GlossaColors.textDark;
      case GlossaButtonStyle.dark:
        return GlossaColors.white;
    }
  }

  Color get _shadowColor {
    switch (style) {
      case GlossaButtonStyle.primary:
        return const Color(0xFFB00E24);
      case GlossaButtonStyle.secondary:
        return const Color(0xFFCCB866);
      case GlossaButtonStyle.dark:
        return GlossaColors.blueDarkest;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Spacing.buttonRadius),
          boxShadow: [
            BoxShadow(
              color: _shadowColor,
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: _backgroundColor,
            foregroundColor: _foregroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Spacing.buttonRadius),
            ),
            elevation: 0,
          ),
          child: isLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: _foregroundColor,
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _foregroundColor,
                  ),
                ),
        ),
      ),
    );
  }
}
