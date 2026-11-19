import 'package:flutter/material.dart';
import '../../app/theme/glossa_colors.dart';
import '../../core/constants/spacing.dart';

/// Pixel-art style hero avatar drawn with CustomPainter.
/// Renders a simplified pixel character appropriate for the hero level.
class HeroAvatar extends StatelessWidget {
  final int heroIndex; // 0 = boy, 1 = girl
  final int level;
  final double size;
  final bool showBorder;

  const HeroAvatar({
    super.key,
    this.heroIndex = 0,
    this.level = 1,
    this.size = 60,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: GlossaColors.yellowPrimary.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(Spacing.cardRadius),
        border: showBorder
            ? Border.all(color: GlossaColors.blueNavy, width: 2)
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Spacing.cardRadius - 2),
        child: CustomPaint(
          painter: _PixelHeroPainter(
            heroIndex: heroIndex,
            level: level,
          ),
        ),
      ),
    );
  }
}

/// Large hero avatar for character selection and profile views.
class HeroAvatarLarge extends StatelessWidget {
  final int heroIndex;
  final int level;
  final double size;

  const HeroAvatarLarge({
    super.key,
    this.heroIndex = 0,
    this.level = 1,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size + 20,
      decoration: BoxDecoration(
        color: GlossaColors.yellowPrimary.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(Spacing.cardRadius),
      ),
      child: CustomPaint(
        painter: _PixelHeroPainter(
          heroIndex: heroIndex,
          level: level,
        ),
      ),
    );
  }
}

class _PixelHeroPainter extends CustomPainter {
  final int heroIndex;
  final int level;

  _PixelHeroPainter({required this.heroIndex, required this.level});

  @override
  void paint(Canvas canvas, Size size) {
    final px = size.width / 16; // pixel unit

    // Colors based on hero and level
    final skinColor = heroIndex == 0
        ? const Color(0xFFE8B87A)
        : const Color(0xFFD4A06A);
    final hairColor = heroIndex == 0
        ? const Color(0xFF5C3317)
        : const Color(0xFF2C1810);
    final outfitColor = level >= 5
        ? const Color(0xFFC8A855) // Gold armor
        : level >= 3
            ? const Color(0xFF1469BC) // Blue outfit
            : const Color(0xFFD4A06A); // Basic tunic
    final outfitDark = level >= 5
        ? const Color(0xFF8B7735)
        : level >= 3
            ? const Color(0xFF0B4A8C)
            : const Color(0xFFA67B4A);

    // Hat/helmet for higher levels
    if (level >= 5) {
      _drawPixelRect(canvas, px, 6, 1, 4, 2, const Color(0xFFE8112D)); // Red hat
    }

    // Hair
    _drawPixelRect(canvas, px, 5, level >= 5 ? 3 : 2, 6, 2, hairColor);

    // Head / face
    _drawPixelRect(canvas, px, 6, 4, 4, 3, skinColor);

    // Eyes
    _drawPixelRect(canvas, px, 7, 5, 1, 1, const Color(0xFF1A1A1A));
    _drawPixelRect(canvas, px, 9, 5, 1, 1, const Color(0xFF1A1A1A));

    // Body / outfit
    _drawPixelRect(canvas, px, 5, 7, 6, 3, outfitColor);
    _drawPixelRect(canvas, px, 6, 7, 4, 3, outfitDark);

    // Belt detail
    if (level >= 3) {
      _drawPixelRect(canvas, px, 5, 9, 6, 1, const Color(0xFF8B4513));
    }

    // Arms
    _drawPixelRect(canvas, px, 4, 7, 1, 3, skinColor);
    _drawPixelRect(canvas, px, 11, 7, 1, 3, skinColor);

    // Shield for level 5+
    if (level >= 5) {
      _drawPixelRect(canvas, px, 2, 7, 2, 3, GlossaColors.blueDeep);
      _drawPixelRect(canvas, px, 3, 8, 1, 1, GlossaColors.white);
    }

    // Legs
    _drawPixelRect(canvas, px, 6, 10, 2, 2, const Color(0xFF8B6914));
    _drawPixelRect(canvas, px, 9, 10, 2, 2, const Color(0xFF8B6914));

    // Feet
    _drawPixelRect(canvas, px, 5, 12, 3, 1, const Color(0xFF5C3317));
    _drawPixelRect(canvas, px, 9, 12, 3, 1, const Color(0xFF5C3317));

    // Girl has a bow
    if (heroIndex == 1 && level < 5) {
      _drawPixelRect(canvas, px, 10, 2, 2, 1, const Color(0xFFE8112D));
    }

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height - px),
        width: 8 * px,
        height: 2 * px,
      ),
      shadowPaint,
    );
  }

  void _drawPixelRect(Canvas canvas, double px, int x, int y, int w, int h, Color color) {
    canvas.drawRect(
      Rect.fromLTWH(x * px, y * px, w * px, h * px),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _PixelHeroPainter oldDelegate) =>
      heroIndex != oldDelegate.heroIndex || level != oldDelegate.level;
}
