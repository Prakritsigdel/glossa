import 'package:flutter/material.dart';

/// Draws pixel art from rows of characters. Each character maps to a colour
/// in [palette]; any character not in the palette (e.g. '.') is transparent.
class PixelSprite extends StatelessWidget {
  const PixelSprite({
    super.key,
    required this.rows,
    required this.palette,
    this.pixelSize = 10,
  });

  final List<String> rows;
  final Map<String, Color> palette;
  final double pixelSize;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size(rows.first.length * pixelSize, rows.length * pixelSize),
        painter: _SpritePainter(rows, palette, pixelSize),
      ),
    );
  }
}

class _SpritePainter extends CustomPainter {
  _SpritePainter(this.rows, this.palette, this.pixelSize);

  final List<String> rows;
  final Map<String, Color> palette;
  final double pixelSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < rows.length; y++) {
      final row = rows[y];
      for (var x = 0; x < row.length; x++) {
        final color = palette[row[x]];
        if (color == null) continue;
        paint.color = color;
        // Tiny overlap avoids hairline seams on fractional pixel ratios.
        canvas.drawRect(
          Rect.fromLTWH(x * pixelSize, y * pixelSize, pixelSize + 0.6,
              pixelSize + 0.6),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SpritePainter old) =>
      old.rows != rows || old.palette != palette || old.pixelSize != pixelSize;
}
