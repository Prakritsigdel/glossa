import 'package:flutter/material.dart';

/// Steps its child up and down (a two-frame "idle" bob that suits pixel art).
/// Stays still when the system "reduce motion" setting is on.
class Bobbing extends StatefulWidget {
  const Bobbing({super.key, required this.child, this.distance = 10});

  final Widget child;
  final double distance;

  @override
  State<Bobbing> createState() => _BobbingState();
}

class _BobbingState extends State<Bobbing> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
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
      child: widget.child,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _controller.value < 0.5 ? 0 : -widget.distance),
        child: child,
      ),
    );
  }
}
