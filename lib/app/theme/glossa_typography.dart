import 'package:flutter/material.dart';
import 'glossa_colors.dart';

/// Typography constants calibrated against the 390×844 reference designs.
/// Uses Nunito (bundled) for Latin text and Noto Sans Devanagari for scripts.
abstract final class GlossaTypography {
  static const String _fontFamily = 'Nunito';
  static const String devanagariFontFamily = 'NotoSansDevanagari';

  // ─── Display / Hero headings ──────────────────────────────
  static const TextStyle displayLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 36,
    fontWeight: FontWeight.w800,
    color: GlossaColors.textDark,
    height: 1.15,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: GlossaColors.textDark,
    height: 1.2,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: GlossaColors.textDark,
    height: 1.25,
  );

  // ─── Headings ─────────────────────────────────────────────
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: GlossaColors.textDark,
    height: 1.25,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: GlossaColors.textDark,
    height: 1.3,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: GlossaColors.textDark,
    height: 1.3,
  );

  // ─── Body ─────────────────────────────────────────────────
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: GlossaColors.textDark,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: GlossaColors.textDark,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: GlossaColors.textSubtle,
    height: 1.5,
  );

  // ─── Labels / Buttons ─────────────────────────────────────
  static const TextStyle labelLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: GlossaColors.white,
    height: 1.3,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: GlossaColors.textDark,
    height: 1.3,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: GlossaColors.textSubtle,
    letterSpacing: 0.5,
    height: 1.4,
  );

  // ─── Devanagari ───────────────────────────────────────────
  static const TextStyle devanagariLarge = TextStyle(
    fontFamily: devanagariFontFamily,
    fontSize: 48,
    fontWeight: FontWeight.w700,
    color: GlossaColors.yellowPrimary,
    height: 1.2,
  );

  static const TextStyle devanagariMedium = TextStyle(
    fontFamily: devanagariFontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: GlossaColors.textDark,
    height: 1.3,
  );

  static const TextStyle devanagariSmall = TextStyle(
    fontFamily: devanagariFontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: GlossaColors.textDark,
    height: 1.3,
  );

  // ─── On-dark variants ─────────────────────────────────────
  static TextStyle get displayLargeOnDark =>
      displayLarge.copyWith(color: GlossaColors.white);

  static TextStyle get displayMediumOnDark =>
      displayMedium.copyWith(color: GlossaColors.white);

  static TextStyle get headlineLargeOnDark =>
      headlineLarge.copyWith(color: GlossaColors.white);

  static TextStyle get bodyLargeOnDark =>
      bodyLarge.copyWith(color: GlossaColors.white);

  static TextStyle get bodyMediumOnDark =>
      bodyMedium.copyWith(color: Colors.white70);

  static TextStyle get bodySmallOnDark =>
      bodySmall.copyWith(color: Colors.white60);
}
