import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Decorative audio-waveform bars (a recurring element in the Glossa UI).
/// Heights snap to 4px steps to keep the pixel feel. Respects the system
/// "reduce motion" setting.
class Waveform extends StatefulWidget {
  const Waveform({super.key, this.barCount = 21, this.height = 72});

  final int barCount;
  final double height;

  @override
  State<Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<Waveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0.25;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _barHeight(int index, double t) {
    final n = widget.barCount;
    final envelope = math.sin(math.pi * (index + 0.5) / n);
    final wave = 0.5 + 0.5 * math.sin(2 * math.pi * t + index * 0.75);
    final raw = widget.height * (0.16 + 0.84 * envelope * (0.35 + 0.65 * wave));
    return math.max(4.0, (raw / 4).round() * 4.0);
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: widget.height,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.barCount; i++)
                  Container(
                    width: 8,
                    height: _barHeight(i, _controller.value),
                    decoration: BoxDecoration(
                      color: i.isEven ? AppColors.red : AppColors.butter,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
