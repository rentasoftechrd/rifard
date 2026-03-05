import 'package:flutter/material.dart';

/// Misma paleta que el backoffice: fondo oscuro, superficie, primary, etc.
class AppColors {
  static const primary = Color(0xFF2563EB);
  static const secondary = Color(0xFF10B981);
  static const background = Color(0xFF0B1220);
  static const surface = Color(0xFF111827);
  static const border = Color(0xFF1F2937);
  static const textPrimary = Color(0xFFE5E7EB);
  static const textMuted = Color(0xFF94A3B8);
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const success = Color(0xFF22C55E);
}

ThemeData get darkTheme {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      error: AppColors.danger,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.textPrimary,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    dividerColor: AppColors.border,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      labelStyle: const TextStyle(color: AppColors.textMuted),
      hintStyle: const TextStyle(color: AppColors.textMuted),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.textPrimary),
      bodyMedium: TextStyle(color: AppColors.textPrimary),
      titleMedium: TextStyle(color: AppColors.textPrimary),
      titleLarge: TextStyle(color: AppColors.textPrimary),
    ),
  );
}
