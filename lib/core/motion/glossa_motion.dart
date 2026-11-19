import 'package:flutter/material.dart';

/// Centralized motion tokens, durations, curves, and accessibility helpers for Glossa.
abstract final class GlossaMotion {
  // ─── Durations ─────────────────────────────────────────────
  /// Instant micro-interaction (button push down, tap feedback).
  static const Duration buttonPress = Duration(milliseconds: 100);

  /// Selection cards, checkboxes, tab switches.
  static const Duration selection = Duration(milliseconds: 180);

  /// Modal, dialogs, bottom sheets, snackbars.
  static const Duration modal = Duration(milliseconds: 220);

  /// Standard screen transitions (slide, fade).
  static const Duration pageTransition = Duration(milliseconds: 300);

  /// Loading screen preparation / battle setup duration.
  static const Duration loadingDuration = Duration(milliseconds: 1500);

  /// XP bar fill and counting animation.
  static const Duration xpFill = Duration(milliseconds: 700);

  /// Celebration, level-up confetti/particles, victory fanfare.
  static const Duration celebration = Duration(milliseconds: 1200);

  /// Answer shake duration for incorrect answers.
  static const Duration shake = Duration(milliseconds: 350);

  /// Subtle character idle breathing cycle.
  static const Duration idleCycle = Duration(milliseconds: 1600);

  // ─── Curves ────────────────────────────────────────────────
  /// Snappy curve for RPG button presses and physical interactions.
  static const Curve snappy = Curves.easeOutCubic;

  /// Smooth deceleration for incoming screens and cards.
  static const Curve enter = Curves.easeOutQuart;

  /// Smooth acceleration for outgoing screens.
  static const Curve exit = Curves.easeInQuart;

  /// Playful bounce for level up and hero unlocks.
  static const Curve bounce = Curves.elasticOut;

  /// Standard smooth curve for XP progression.
  static const Curve progress = Curves.easeInOutCubic;

  // ─── Accessibility ─────────────────────────────────────────
  /// Returns whether motion animations should be disabled or minimized.
  static bool shouldReduceMotion(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  /// Returns the given duration or Duration.zero if reduced motion is enabled.
  static Duration duration(BuildContext context, Duration original) {
    return shouldReduceMotion(context) ? Duration.zero : original;
  }
}
