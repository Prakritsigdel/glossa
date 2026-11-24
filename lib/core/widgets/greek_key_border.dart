import 'package:flutter/material.dart';
import '../../app/theme/glossa_colors.dart';

/// Decorative Greek key (meander) border pattern used on blue screens.
class GreekKeyBorder extends StatelessWidget {
  final double height;
  final Color patternColor;
  final Color backgroundColor;

  const GreekKeyBorder({
    super.key,
    this.height = 24,
    this.patternColor = GlossaColors.yellowPrimary,
    this.backgroundColor = GlossaColors.blueDeep,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _GreekKeyPainter(
          patternColor: patternColor,
          backgroundColor: backgroundColor,
        ),
      ),
    );
  }
}

class _GreekKeyPainter extends CustomPainter {
  final Color patternColor;
  final Color backgroundColor;

  _GreekKeyPainter({
    required this.patternColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = patternColor
      ..style = PaintingStyle.fill;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    // Fill background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Draw repeating meander/greek key pattern
    final unitSize = size.height;
    final halfUnit = unitSize / 2;
    final quarterUnit = unitSize / 4;
    final numUnits = (size.width / unitSize).ceil() + 1;

    for (int i = 0; i < numUnits; i++) {
      final x = i * unitSize;

      // Outer L shape
      // Horizontal top bar
      canvas.drawRect(
        Rect.fromLTWH(x, 0, unitSize, quarterUnit),
        paint,
      );
      // Vertical right bar
      canvas.drawRect(
        Rect.fromLTWH(x + unitSize - quarterUnit, 0, quarterUnit, halfUnit + quarterUnit),
        paint,
      );
      // Horizontal middle bar
      canvas.drawRect(
        Rect.fromLTWH(x + quarterUnit, halfUnit, halfUnit, quarterUnit),
        paint,
      );
      // Vertical left inner bar
      canvas.drawRect(
        Rect.fromLTWH(x + quarterUnit, halfUnit, quarterUnit, halfUnit),
        paint,
      );
      // Bottom bar
      canvas.drawRect(
        Rect.fromLTWH(x, size.height - quarterUnit, halfUnit + quarterUnit, quarterUnit),
        paint,
      );

      // Inner cutouts (draw background color to create the key pattern)
      canvas.drawRect(
        Rect.fromLTWH(x + quarterUnit, quarterUnit, halfUnit - quarterUnit, quarterUnit),
        bgPaint,
      );
      canvas.drawRect(
        Rect.fromLTWH(x + halfUnit, halfUnit + quarterUnit, quarterUnit, quarterUnit),
        bgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GreekKeyPainter oldDelegate) =>
      patternColor != oldDelegate.patternColor ||
      backgroundColor != oldDelegate.backgroundColor;
}
