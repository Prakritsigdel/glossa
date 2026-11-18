import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Retro button: rounded, cream outline, hard shadow that "presses in".
/// Pass a null [onPressed] to disable it.
class PixelButton extends StatefulWidget {
  const PixelButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.fill = AppColors.red,
    this.foreground = AppColors.cream,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color fill;
  final Color foreground;

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: FocusableActionDetector(
          enabled: enabled,
          mouseCursor:
              enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onPressed?.call();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
            onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
            onTapCancel:
                enabled ? () => setState(() => _pressed = false) : null,
            onTap: widget.onPressed,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: _focused ? AppColors.butter : Colors.transparent,
                  width: 3,
                ),
              ),
              child: Transform.translate(
                offset: Offset(0, _pressed ? 4 : 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.fill,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cream, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.navyDeep,
                        offset: Offset(0, _pressed ? 1 : 5),
                      ),
                    ],
                  ),
                  child: Text(
                    widget.label,
                    style:
                        AppTextStyles.button.copyWith(color: widget.foreground),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
