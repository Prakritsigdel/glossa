import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTextStyles {
  static const display = TextStyle(
    fontFamily: 'PressStart2P',
    fontSize: 36,
    height: 1.2,
    color: AppColors.butter,
  );

  static const button = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w800,
  );

  static const body = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 14,
    height: 1.35,
    fontWeight: FontWeight.w500,
    color: AppColors.cream,
  );
}

abstract final class AppTheme {
  static ThemeData get theme {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.red,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.red,
      onPrimary: Colors.white,
      secondary: AppColors.butter,
      onSecondary: AppColors.navyDeep,
      surface: AppColors.navy,
      onSurface: AppColors.cream,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.navy,
      fontFamily: 'DMSans',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.cream,
        elevation: 0,
      ),
    );
  }
}
