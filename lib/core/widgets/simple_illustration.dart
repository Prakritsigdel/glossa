import 'package:flutter/material.dart';
import '../../app/theme/glossa_colors.dart';

/// Simple flat illustrations drawn with CustomPainter.
/// Used in lesson screens for picture-to-word and word-to-picture exercises.
class SimpleIllustration extends StatelessWidget {
  final String imageKey; // Stable concept ID from the lesson illustration catalog.
  final double size;

  static const Set<String> supportedImageKeys = {
    'hello', 'thanks', 'yes', 'no', 'good', 'fine', 'self', 'you', 'name',
    'what', 'who', 'formal_people', 'mother', 'father', 'elder_sister',
    'elder_brother', 'younger_brother', 'younger_sister', 'son', 'daughter',
    'child', 'person', 'woman', 'man', 'number_1', 'number_2', 'number_3',
    'number_4', 'number_5', 'number_6', 'number_7', 'number_8', 'number_9',
    'number_10', 'how_many', 'red', 'white', 'house', 'droplet', 'bowl',
    'book', 'cooked_rice', 'tea', 'meat', 'fish', 'beaten_rice', 'to_eat',
    'to_drink', 'to_give', 'to_take', 'big', 'small', 'door', 'road', 'place',
    'work', 'fire', 'where', 'to_read', 'to_go', 'to_come', 'to_do', 'to_sit',
    'to_see', 'today', 'to_write',
  };

  static bool supports(String? key) =>
      key != null && supportedImageKeys.contains(key);

  const SimpleIllustration({
    super.key,
    required this.imageKey,
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    if (!supports(imageKey)) return const SizedBox.shrink();
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
        _drawNewConcept(canvas, size);
    }
  }

  void _drawNewConcept(Canvas canvas, Size size) {
    final s = size.shortestSide / 64;
    canvas.save();
    canvas.scale(s);
    final navy = GlossaColors.blueNavy;
    final red = GlossaColors.redAction;
    final blue = GlossaColors.blueDeep;
    final gold = GlossaColors.yellowPrimary;
    final green = GlossaColors.successGreen;
    final p = Paint()..color = navy;

    void box(double x, double y, double w, double h, Color color) {
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h), const Radius.circular(3),
      );
      canvas.drawRRect(r, Paint()..color = color);
      canvas.drawRRect(r, Paint()..color = navy..style = PaintingStyle.stroke..strokeWidth = 2);
    }

    void dot(double x, double y, double radius, Color color) {
      canvas.drawCircle(Offset(x, y), radius, Paint()..color = color);
      canvas.drawCircle(Offset(x, y), radius, Paint()..color = navy..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }

    void stroke(double x1, double y1, double x2, double y2, Color color) {
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), Paint()..color = color..strokeWidth = 4..strokeCap = StrokeCap.round);
    }

    if (imageKey.startsWith('number_')) {
      final n = int.tryParse(imageKey.substring(7)) ?? 1;
      for (var i = 0; i < n; i++) {
        final x = 18 + (i % 5) * 7.0;
        final y = n > 5 ? 20 + (i ~/ 5) * 23.0 : 32.0;
        dot(x, y, 3.5, i.isEven ? red : blue);
      }
    } else if (_isPersonConcept(imageKey)) {
      _drawPersonConcept(canvas, imageKey, dot, box, stroke);
      if (imageKey == 'hello') stroke(44, 25, 55, 12, red);
      if (imageKey == 'self') stroke(40, 36, 31, 41, red);
      if (imageKey == 'you') stroke(43, 37, 58, 28, red);
      if (imageKey == 'formal_people') { dot(15, 20, 8, gold); dot(50, 20, 8, green); }
    } else if (imageKey == 'thanks') {
      box(12, 24, 40, 29, gold); stroke(32, 24, 32, 53, red); stroke(12, 34, 52, 34, red);
    } else if (imageKey == 'yes' || imageKey == 'good') {
      if (imageKey == 'yes') { stroke(14, 34, 26, 46, green); stroke(26, 46, 51, 17, green); }
      else { dot(32, 32, 21, gold); dot(25, 28, 2, navy); dot(39, 28, 2, navy); stroke(24, 39, 40, 39, navy); }
    } else if (imageKey == 'no') {
      dot(32, 32, 22, GlossaColors.white); stroke(18, 18, 46, 46, red); stroke(46, 18, 18, 46, red);
    } else if (imageKey == 'what' || imageKey == 'who' || imageKey == 'where' || imageKey == 'how_many') {
      dot(32, 32, 22, gold); stroke(32, 22, 38, 27, navy); stroke(38, 27, 32, 34, navy); dot(32, 43, 2, navy);
    } else if (imageKey == 'name') {
      box(9, 17, 46, 31, GlossaColors.white); dot(21, 32, 7, gold); box(32, 26, 16, 4, blue); box(32, 36, 13, 3, red);
    } else if (imageKey == 'red' || imageKey == 'white') {
      box(10, 10, 44, 44, imageKey == 'red' ? red : GlossaColors.white);
      box(18, 18, 28, 28, imageKey == 'red' ? const Color(0xFFE94345) : const Color(0xFFF8F5EC));
    } else if (imageKey == 'book' || imageKey == 'to_read') {
      box(10, 12, 22, 41, gold); box(32, 12, 22, 41, GlossaColors.white); stroke(32, 14, 32, 52, navy);
    } else if (imageKey == 'tea' || imageKey == 'to_drink') {
      box(16, 22, 31, 27, const Color(0xFFB87333)); stroke(47, 28, 56, 28, navy); stroke(56, 28, 56, 40, navy); stroke(56, 40, 47, 40, navy);
    } else if (imageKey == 'cooked_rice' || imageKey == 'bowl' || imageKey == 'beaten_rice') {
      box(12, 35, 40, 16, gold); canvas.drawArc(const Rect.fromLTWH(15, 17, 34, 25), 3.14, 3.14, true, Paint()..color = GlossaColors.white);
      for (var i = 0; i < (imageKey == 'beaten_rice' ? 7 : 4); i++) {
        dot(22 + (i % 4) * 7.0, 27 + (i ~/ 4) * 5.0, 2, GlossaColors.white);
      }
    } else if (imageKey == 'fish') {
      final path = Path()..moveTo(9, 32)..quadraticBezierTo(29, 10, 48, 32)..quadraticBezierTo(29, 54, 9, 32)..close();
      canvas.drawPath(path, Paint()..color = blue); canvas.drawPath(path, p..style = PaintingStyle.stroke..strokeWidth = 2);
      final tail = Path()..moveTo(47, 32)..lineTo(59, 20)..lineTo(59, 44)..close(); canvas.drawPath(tail, Paint()..color = gold); dot(19, 28, 2, navy);
    } else if (imageKey == 'meat') {
      box(15, 18, 34, 31, red); dot(45, 43, 6, GlossaColors.white);
    } else if (imageKey == 'big' || imageKey == 'small') {
      final side = imageKey == 'big' ? 40.0 : 22.0; box((64-side)/2, (64-side)/2, side, side, imageKey == 'big' ? red : blue);
    } else if (imageKey == 'door') {
      box(16, 8, 32, 49, const Color(0xFF9C653A)); dot(40, 34, 2.5, gold);
    } else if (imageKey == 'road' || imageKey == 'to_go' || imageKey == 'to_come') {
      final path = Path()..moveTo(23, 58)..lineTo(28, 7)..lineTo(38, 7)..lineTo(43, 58)..close(); canvas.drawPath(path, Paint()..color = const Color(0xFF777D82));
      for (var y = 14; y < 54; y += 13) {
        box(30, y.toDouble(), 4, 7, gold);
      }
      if (imageKey != 'road') { stroke(13, 32, 51, 32, red); stroke(51, 32, 41, 23, red); stroke(51, 32, 41, 41, red); }
    } else if (imageKey == 'place' || imageKey == 'fire') {
      if (imageKey == 'place') { dot(32, 25, 17, red); dot(32, 25, 6, GlossaColors.white); stroke(22, 37, 32, 57, red); stroke(42, 37, 32, 57, red); }
      else { final flame = Path()..moveTo(32, 7)..quadraticBezierTo(49, 29, 43, 39)..quadraticBezierTo(57, 29, 51, 47)..quadraticBezierTo(32, 62, 14, 46)..quadraticBezierTo(12, 29, 27, 20)..close(); canvas.drawPath(flame, Paint()..color = red); dot(32, 44, 7, gold); }
    } else if (imageKey == 'work' || imageKey == 'to_do' || imageKey == 'to_write') {
      box(12, 31, 40, 20, gold); stroke(18, 51, 16, 59, navy); stroke(46, 51, 48, 59, navy);
      if (imageKey == 'to_write') stroke(24, 21, 45, 12, red); if (imageKey == 'to_do') stroke(21, 39, 28, 45, green);
    } else if (imageKey == 'to_eat' || imageKey == 'to_give' || imageKey == 'to_take') {
      if (imageKey == 'to_eat') { dot(28, 32, 15, gold); stroke(42, 36, 55, 49, red); }
      else { stroke(13, 32, 50, 32, blue); stroke(50, 32, 41, 24, red); stroke(50, 32, 41, 40, red); dot(16, 32, 6, gold); }
    } else if (imageKey == 'to_sit') {
      box(18, 27, 30, 7, red); box(20, 34, 6, 21, blue); box(40, 34, 6, 21, blue);
    } else if (imageKey == 'to_see') {
      canvas.drawOval(const Rect.fromLTWH(6, 17, 52, 30), Paint()..color = GlossaColors.white..style = PaintingStyle.stroke..strokeWidth = 3); dot(32, 32, 10, blue); dot(32, 32, 3, navy);
    } else if (imageKey == 'today') {
      box(10, 14, 44, 40, GlossaColors.white); box(10, 14, 44, 12, red); box(20, 34, 7, 7, blue); box(37, 34, 7, 7, green);
    }
    canvas.restore();
  }

  bool _isPersonConcept(String key) => {
    'hello', 'self', 'you', 'formal_people', 'mother', 'father', 'elder_sister',
    'elder_brother', 'younger_brother', 'younger_sister', 'son', 'daughter',
    'child', 'woman', 'man',
  }.contains(key);

  void _drawPersonConcept(
    Canvas canvas, String key,
    void Function(double, double, double, Color) dot,
    void Function(double, double, double, double, Color) box,
    void Function(double, double, double, double, Color) stroke,
  ) {
    final child = key == 'child' || key == 'son' || key == 'daughter' || key.startsWith('younger');
    final feminine = key == 'mother' || key == 'daughter' || key == 'woman' || key.endsWith('sister');
    dot(32, child ? 20 : 17, child ? 9 : 11, const Color(0xFFF2C18D));
    box(21, child ? 29 : 30, 22, child ? 18 : 23, feminine ? const Color(0xFFE58A9A) : GlossaColors.blueDeep);
    stroke(25, 50, 21, 61, GlossaColors.blueNavy); stroke(39, 50, 43, 61, GlossaColors.blueNavy);
    if (feminine) { dot(21, 17, 5, const Color(0xFF4B2F2F)); dot(43, 17, 5, const Color(0xFF4B2F2F)); }
    else { box(23, 6, 18, 5, const Color(0xFF4B2F2F)); }
    if (key.startsWith('elder')) stroke(17, 55, 47, 55, GlossaColors.yellowPrimary);
    if (key == 'father' || key == 'man') stroke(27, 26, 37, 26, GlossaColors.blueNavy);
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
