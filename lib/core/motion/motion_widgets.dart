import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app/theme/glossa_colors.dart';
import 'glossa_motion.dart';

/// Shakes the child widget horizontally when triggered (used for incorrect answers).
class ShakeWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double deltaX;

  const ShakeWidget({
    super.key,
    required this.child,
    this.duration = GlossaMotion.shake,
    this.deltaX = 8.0,
  });

  @override
  State<ShakeWidget> createState() => ShakeWidgetState();
}

class ShakeWidgetState extends State<ShakeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Triggers a restrained horizontal shake.
  void shake() {
    if (GlossaMotion.shouldReduceMotion(context)) return;
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    if (GlossaMotion.shouldReduceMotion(context)) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Sine wave oscillation with dampening
        final progress = _controller.value;
        final count = 3.0; // 3 full shakes
        final offset = math.sin(progress * math.pi * 2 * count) *
            widget.deltaX *
            (1.0 - progress);
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Subtle vertical idle breathing/bobbing for pixel-art characters.
class IdleBobbing extends StatefulWidget {
  final Widget child;
  final double offsetDistance;
  final Duration duration;

  const IdleBobbing({
    super.key,
    required this.child,
    this.offsetDistance = 3.0,
    this.duration = GlossaMotion.idleCycle,
  });

  @override
  State<IdleBobbing> createState() => _IdleBobbingState();
}

class _IdleBobbingState extends State<IdleBobbing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = Tween<double>(begin: 0, end: -widget.offsetDistance).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutSine,
      ),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (GlossaMotion.shouldReduceMotion(context)) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Pixel-art style celebration star particles for Level Up.
class CelebrationParticles extends StatefulWidget {
  final double size;

  const CelebrationParticles({
    super.key,
    this.size = 240,
  });

  @override
  State<CelebrationParticles> createState() => _CelebrationParticlesState();
}

class _CelebrationParticlesState extends State<CelebrationParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: GlossaMotion.celebration,
    )..forward();

    final rng = math.Random(42);
    _particles = List.generate(24, (i) {
      final angle = (i / 24) * 2 * math.pi + (rng.nextDouble() * 0.2 - 0.1);
      final speed = 60.0 + rng.nextDouble() * 50.0;
      final size = 4.0 + rng.nextDouble() * 6.0;
      final colors = [
        GlossaColors.yellowPrimary,
        GlossaColors.white,
        GlossaColors.redAction,
        GlossaColors.blueBright,
      ];
      final color = colors[rng.nextInt(colors.length)];
      return _Particle(
        dx: math.cos(angle) * speed,
        dy: math.sin(angle) * speed,
        size: size,
        color: color,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (GlossaMotion.shouldReduceMotion(context)) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _ParticlePainter(
            progress: _controller.value,
            particles: _particles,
          ),
        );
      },
    );
  }
}

class _Particle {
  final double dx;
  final double dy;
  final double size;
  final Color color;

  _Particle({
    required this.dx,
    required this.dy,
    required this.size,
    required this.color,
  });
}

class _ParticlePainter extends CustomPainter {
  final double progress;
  final List<_Particle> particles;

  _ParticlePainter({required this.progress, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    for (final p in particles) {
      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      // Expand outward with deceleration
      final easeProgress = Curves.easeOutCubic.transform(progress);
      final currentPos = Offset(
        center.dx + p.dx * easeProgress,
        center.dy + p.dy * easeProgress,
      );

      // Pixel-art square sparkles
      final pSize = p.size * (1.0 - progress * 0.5);
      canvas.drawRect(
        Rect.fromCenter(center: currentPos, width: pSize, height: pSize),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      progress != oldDelegate.progress;
}
