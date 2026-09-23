import 'package:flutter/material.dart';

abstract final class AppColors {
  static const ink = Color(0xFF242527);
  static const paper = Color(0xFFF7F7EF);
  static const purple = Color(0xFF6250B5);
  static const lime = Color(0xFFD7EF81);
  static const muted = Color(0xFF63655C);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.purple,
    surface: AppColors.paper,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.paper,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.paper,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        fontSize: 42,
        height: 1.08,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.8,
        color: AppColors.ink,
      ),
      headlineMedium: TextStyle(
        fontSize: 30,
        height: 1.15,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: AppColors.ink,
      ),
      titleLarge: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: AppColors.ink),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: AppColors.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 56),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        foregroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
  );
}
