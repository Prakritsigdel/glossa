import 'package:material_ui/material_ui.dart';
import '../../app/theme/glossa_colors.dart';

/// Animated audio waveform visualization (decorative — no real audio).
class AudioWaveform extends StatefulWidget {
  final Color barColor;
  final double height;
  final double width;
  final bool isPlaying;

  const AudioWaveform({
    super.key,
    this.barColor = GlossaColors.redAction,
    this.height = 24,
    this.width = 120,
    this.isPlaying = false,
  });

  @override
  State<AudioWaveform> createState() => _AudioWaveformState();
}

class _AudioWaveformState extends State<AudioWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    if (widget.isPlaying) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(AudioWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.width, widget.height),
          painter: _WaveformPainter(
            progress: widget.isPlaying ? _controller.value : 0.5,
            barColor: widget.barColor,
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double progress;
  final Color barColor;

  _WaveformPainter({required this.progress, required this.barColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    const barCount = 12;
    final barWidth = size.width / (barCount * 2 - 1);
    final maxHeight = size.height;

    // Static waveform pattern heights
    final heights = [0.3, 0.6, 0.8, 1.0, 0.7, 0.9, 0.5, 0.8, 1.0, 0.6, 0.4, 0.7];

    for (int i = 0; i < barCount; i++) {
      final baseH = heights[i % heights.length];
      final animOffset = (progress - 0.5).abs() * 0.3;
      final h = (baseH + animOffset * (i.isEven ? 1 : -1)).clamp(0.2, 1.0);
      final barHeight = h * maxHeight;
      final x = i * barWidth * 2;
      final y = (maxHeight - barHeight) / 2;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      progress != oldDelegate.progress || barColor != oldDelegate.barColor;
}

/// Small audio waveform icon (static).
class AudioWaveformIcon extends StatelessWidget {
  final Color color;
  final double size;

  const AudioWaveformIcon({
    super.key,
    this.color = GlossaColors.redAction,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _WaveformIconPainter(color: color),
    );
  }
}

class _WaveformIconPainter extends CustomPainter {
  final Color color;

  _WaveformIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final barWidth = size.width / 7;
    final heights = [0.4, 0.7, 1.0, 0.6, 0.8];

    for (int i = 0; i < 5; i++) {
      final barHeight = heights[i] * size.height * 0.8;
      final x = (i * 1.4 + 0.3) * barWidth;
      final y = (size.height - barHeight) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth * 0.7, barHeight),
          Radius.circular(barWidth / 3),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformIconPainter oldDelegate) =>
      color != oldDelegate.color;
}
