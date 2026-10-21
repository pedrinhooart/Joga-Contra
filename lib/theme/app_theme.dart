import 'package:flutter/material.dart';

abstract final class AppColors {
  static const forest = Color(0xFF123D2B);
  static const forestDark = Color(0xFF103927);
  static const lime = Color(0xFFC3F35A);
  static const green = Color(0xFF297243);
  static const ink = Color(0xFF222B26);
  static const muted = Color(0xFF818982);
  static const border = Color(0xFFE8ECE8);
  static const canvas = Color(0xFFF6F8F6);
}

class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.canvas,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.forest,
      primary: AppColors.forest,
      secondary: AppColors.lime,
      surface: Colors.white,
    ),
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.ink,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.green, width: 1.5),
      ),
    ),
  );
}
