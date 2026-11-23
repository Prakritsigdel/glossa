import 'package:material_ui/material_ui.dart';
import '../../app/theme/glossa_colors.dart';

/// Simple flat illustrations drawn with CustomPainter.
/// Used in lesson screens for picture-to-word and word-to-picture exercises.
class SimpleIllustration extends StatelessWidget {
  final String imageKey; // 'house', 'droplet', 'bowl', 'person'
  final double size;

  const SimpleIllustration({
    super.key,
    required this.imageKey,
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _IllustrationPainter(imageKey: imageKey),
      ),
    );
  }
}

class _IllustrationPainter extends CustomPainter {
  final String imageKey;

  _IllustrationPainter({required this.imageKey});

  @override
  void paint(Canvas canvas, Size size) {
    switch (imageKey) {
      case 'house':
        _drawHouse(canvas, size);
      case 'droplet':
        _drawDroplet(canvas, size);
      case 'bowl':
        _drawBowl(canvas, size);
      case 'person':
        _drawPerson(canvas, size);
      default:
        _drawHouse(canvas, size);
    }
  }

  void _drawHouse(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Roof (red triangle)
    final roofPath = Path()
      ..moveTo(w * 0.5, h * 0.1)
      ..lineTo(w * 0.1, h * 0.45)
      ..lineTo(w * 0.9, h * 0.45)
      ..close();
    canvas.drawPath(roofPath, Paint()..color = GlossaColors.redAction);

    // Outline
    canvas.drawPath(
      roofPath,
      Paint()
        ..color = GlossaColors.blueNavy
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Body (cream/beige)
    final bodyRect = Rect.fromLTWH(w * 0.15, h * 0.45, w * 0.7, h * 0.45);
    canvas.drawRect(bodyRect, Paint()..color = const Color(0xFFFFF5D1));
    canvas.drawRect(
      bodyRect,
      Paint()
        ..color = GlossaColors.blueNavy
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Door (blue)
    final doorRect = Rect.fromLTWH(w * 0.38, h * 0.55, w * 0.24, h * 0.35);
    canvas.drawRect(doorRect, Paint()..color = GlossaColors.blueDeep);
    canvas.drawRect(
      doorRect,
      Paint()
        ..color = GlossaColors.blueNavy
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawDroplet(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final dropPath = Path()
      ..moveTo(w * 0.5, h * 0.1)
      ..cubicTo(w * 0.5, h * 0.1, w * 0.15, h * 0.55, w * 0.15, h * 0.65)
      ..cubicTo(w * 0.15, h * 0.85, w * 0.35, h * 0.95, w * 0.5, h * 0.95)
      ..cubicTo(w * 0.65, h * 0.95, w * 0.85, h * 0.85, w * 0.85, h * 0.65)
      ..cubicTo(w * 0.85, h * 0.55, w * 0.5, h * 0.1, w * 0.5, h * 0.1)
      ..close();

    canvas.drawPath(dropPath, Paint()..color = GlossaColors.blueDeep);
    canvas.drawPath(
      dropPath,
      Paint()
        ..color = GlossaColors.blueNavy
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  void _drawBowl(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Bowl body (red)
    final bowlPath = Path()
      ..moveTo(w * 0.1, h * 0.45)
      ..lineTo(w * 0.25, h * 0.85)
      ..quadraticBezierTo(w * 0.5, h * 0.95, w * 0.75, h * 0.85)
      ..lineTo(w * 0.9, h * 0.45)
      ..close();

    canvas.drawPath(bowlPath, Paint()..color = GlossaColors.redAction);
    canvas.drawPath(
      bowlPath,
      Paint()
        ..color = GlossaColors.blueNavy
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Rice / content (white semi-circle)
    canvas.drawArc(
      Rect.fromLTWH(w * 0.15, h * 0.2, w * 0.7, h * 0.5),
      3.14159, 3.14159, true,
      Paint()..color = GlossaColors.white,
    );
    canvas.drawArc(
      Rect.fromLTWH(w * 0.15, h * 0.2, w * 0.7, h * 0.5),
      3.14159, 3.14159, false,
      Paint()
        ..color = GlossaColors.blueNavy
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawPerson(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..color = GlossaColors.blueDeep;
    final outlinePaint = Paint()
      ..color = GlossaColors.blueNavy
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Head
    canvas.drawCircle(Offset(w * 0.5, h * 0.25), w * 0.15, paint);
    canvas.drawCircle(Offset(w * 0.5, h * 0.25), w * 0.15, outlinePaint);

    // Inner face circle (skin)
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.25),
      w * 0.1,
      Paint()..color = const Color(0xFFE8B87A),
    );

    // Body
    final bodyPath = Path()
      ..moveTo(w * 0.3, h * 0.45)
      ..quadraticBezierTo(w * 0.5, h * 0.4, w * 0.7, h * 0.45)
      ..lineTo(w * 0.75, h * 0.85)
      ..quadraticBezierTo(w * 0.5, h * 0.9, w * 0.25, h * 0.85)
      ..close();

    canvas.drawPath(bodyPath, paint);
    canvas.drawPath(bodyPath, outlinePaint);
  }

  @override
  bool shouldRepaint(covariant _IllustrationPainter oldDelegate) =>
      imageKey != oldDelegate.imageKey;
}
