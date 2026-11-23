import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/theme/glossa_colors.dart';
import '../../core/constants/spacing.dart';
import '../motion/glossa_motion.dart';

/// Primary action button (red), secondary (yellow), dark (navy).
enum GlossaButtonStyle { primary, secondary, dark }

typedef GlossaButtonCallback = FutureOr<void> Function();

class GlossaButton extends StatefulWidget {
  final String label;
  final GlossaButtonCallback? onPressed;
  final GlossaButtonStyle style;
  final bool isLoading;
  final String? loadingLabel;
  final double? width;

  const GlossaButton({
    super.key,
    required this.label,
    this.onPressed,
    this.style = GlossaButtonStyle.primary,
    this.isLoading = false,
    this.loadingLabel,
    this.width,
  });

  @override
  State<GlossaButton> createState() => _GlossaButtonState();
}

class _GlossaButtonState extends State<GlossaButton> {
  bool _isPressed = false;
  bool _isDebouncing = false;
  bool _isProcessing = false;

  bool get _effectiveLoading => widget.isLoading || _isProcessing;
  bool get _isEnabled => widget.onPressed != null && !_effectiveLoading;

  Color get _backgroundColor {
    if (!_isEnabled) return GlossaColors.disabledGray;
    switch (widget.style) {
      case GlossaButtonStyle.primary:
        return GlossaColors.redAction;
      case GlossaButtonStyle.secondary:
        return GlossaColors.yellowPrimary;
      case GlossaButtonStyle.dark:
        return GlossaColors.blueNavy;
    }
  }

  Color get _foregroundColor {
    if (!_isEnabled) return const Color(0xFF777777);
    switch (widget.style) {
      case GlossaButtonStyle.primary:
        return GlossaColors.white;
      case GlossaButtonStyle.secondary:
        return GlossaColors.textDark;
      case GlossaButtonStyle.dark:
        return GlossaColors.white;
    }
  }

  Color get _shadowColor {
    if (!_isEnabled) return Colors.transparent;
    switch (widget.style) {
      case GlossaButtonStyle.primary:
        return const Color(0xFFB00E24);
      case GlossaButtonStyle.secondary:
        return const Color(0xFFCCB866);
      case GlossaButtonStyle.dark:
        return GlossaColors.blueDarkest;
    }
  }

  void _handleTapDown(TapDownDetails _) {
    if (!_isEnabled) return;
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    if (!_isEnabled) return;
    setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    if (!_isEnabled) return;
    setState(() => _isPressed = false);
  }

  void _handleTap() async {
    if (!_isEnabled || _isDebouncing) return;
    _isDebouncing = true;
    final callback = widget.onPressed;
    if (callback == null) return;

    final result = callback();
    if (result is Future) {
      if (mounted) setState(() => _isProcessing = true);
      try {
        await result;
      } catch (error) {
        // Prevent unhandled exceptions from crashing the UI and ensure button recovery
        debugPrint('[GlossaButton] Action error: $error');
      } finally {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _isDebouncing = false;
          });
        }
      }
    } else {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _isDebouncing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = GlossaMotion.shouldReduceMotion(context);
    final isDepressed = _isPressed && !reduceMotion;

    // Physical button depression values
    final topOffset = isDepressed ? 3.0 : 0.0;
    final shadowHeight = isDepressed ? 1.0 : (_isEnabled ? 4.0 : 0.0);
    final scale = isDepressed ? 0.985 : 1.0;

    return SizedBox(
      width: widget.width ?? double.infinity,
      height: 56,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: reduceMotion ? Duration.zero : GlossaMotion.buttonPress,
          curve: GlossaMotion.snappy,
          transform: Matrix4.translationValues(0.0, topOffset, 0.0)
            ..multiply(Matrix4.diagonal3Values(scale, scale, 1.0)),
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(Spacing.buttonRadius),
            boxShadow: [
              BoxShadow(
                color: _shadowColor,
                offset: Offset(0, shadowHeight),
                blurRadius: 0,
              ),
            ],
          ),
          child: Center(
            child: _effectiveLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: _foregroundColor,
                        ),
                      ),
                      if (widget.loadingLabel != null) ...[
                        const SizedBox(width: Spacing.sm),
                        Text(
                          widget.loadingLabel!,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _foregroundColor,
                          ),
                        ),
                      ],
                    ],
                  )
                : Text(
                    widget.label,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _foregroundColor,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
