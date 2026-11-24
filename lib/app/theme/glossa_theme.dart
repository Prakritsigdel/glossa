import 'package:flutter/material.dart';
import 'glossa_colors.dart';

/// App-wide ThemeData for Glossa, applying the RPG visual identity.
ThemeData glossaTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: GlossaColors.creamBackground,
    colorScheme: const ColorScheme.light(
      primary: GlossaColors.blueDeep,
      secondary: GlossaColors.yellowPrimary,
      error: GlossaColors.redAction,
      surface: GlossaColors.creamBackground,
      onPrimary: GlossaColors.white,
      onSecondary: GlossaColors.textDark,
      onError: GlossaColors.white,
      onSurface: GlossaColors.textDark,
    ),
    fontFamily: 'Nunito',
    appBarTheme: const AppBarTheme(
      backgroundColor: GlossaColors.creamBackground,
      foregroundColor: GlossaColors.textDark,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: GlossaColors.redAction,
        foregroundColor: GlossaColors.white,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: GlossaColors.inputBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: GlossaColors.inputBorder, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: GlossaColors.inputBorder, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: GlossaColors.blueDeep, width: 2.5),
      ),
      hintStyle: const TextStyle(
        fontFamily: 'Nunito',
        color: GlossaColors.disabledGray,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return GlossaColors.blueDeep;
        }
        return GlossaColors.white;
      }),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: GlossaColors.creamPale,
      selectedItemColor: GlossaColors.textDark,
      unselectedItemColor: GlossaColors.textSubtle,
      type: BottomNavigationBarType.fixed,
    ),
  );
}
