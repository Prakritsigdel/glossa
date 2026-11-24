import 'package:material_ui/material_ui.dart';
import '../../app/theme/glossa_colors.dart';
import '../constants/assets.dart';

/// The Glossa concentric-circle logo widget.
class GlossaLogo extends StatelessWidget {
  final double size;

  const GlossaLogo({super.key, this.size = 160});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LogoPainter(),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Outer ring (darkest blue)
    canvas.drawCircle(
      center,
      maxRadius,
      Paint()..color = const Color(0xFF0A3D7A),
    );

    // Second ring
    canvas.drawCircle(
      center,
      maxRadius * 0.85,
      Paint()..color = GlossaColors.blueDeep,
    );

    // Third ring
    canvas.drawCircle(
      center,
      maxRadius * 0.72,
      Paint()..color = GlossaColors.blueBright,
    );

    // Yellow ring
    canvas.drawCircle(
      center,
      maxRadius * 0.52,
      Paint()..color = GlossaColors.yellowPrimary,
    );

    // White center circle
    canvas.drawCircle(
      center,
      maxRadius * 0.38,
      Paint()..color = GlossaColors.white,
    );

    // Red speech bubble
    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - maxRadius * 0.04),
        width: maxRadius * 0.42,
        height: maxRadius * 0.32,
      ),
      Radius.circular(maxRadius * 0.08),
    );
    canvas.drawRRect(
      bubbleRect,
      Paint()..color = GlossaColors.redAction,
    );

    // Speech bubble tail
    final tailPath = Path()
      ..moveTo(center.dx - maxRadius * 0.06, center.dy + maxRadius * 0.12)
      ..lineTo(center.dx - maxRadius * 0.12, center.dy + maxRadius * 0.2)
      ..lineTo(center.dx + maxRadius * 0.02, center.dy + maxRadius * 0.12)
      ..close();
    canvas.drawPath(tailPath, Paint()..color = GlossaColors.redAction);

    // Three sound wave bars inside the bubble
    final barPaint = Paint()
      ..color = GlossaColors.white
      ..style = PaintingStyle.fill;

    final barWidth = maxRadius * 0.04;
    final barHeights = [maxRadius * 0.12, maxRadius * 0.18, maxRadius * 0.12];
    final barStartX = center.dx - barWidth * 2;
    final barCenterY = center.dy - maxRadius * 0.02;

    for (int i = 0; i < 3; i++) {
      final x = barStartX + i * barWidth * 2;
      final h = barHeights[i];
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, barCenterY),
            width: barWidth,
            height: h,
          ),
          Radius.circular(barWidth / 2),
        ),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Small app icon, loaded from the real logo image.
class GlossaAppIcon extends StatelessWidget {
  final double size;

  const GlossaAppIcon({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.25),
      child: Image.asset(
        AssetPaths.logo,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

