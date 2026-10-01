import 'package:flutter/material.dart';

abstract final class AppColors {
  static const ink = Color(0xFF3B8719);
  static const paper = Color(0xFFE6EBC6);
  static const teal = Color(0xFF3E9B99);
  static const onTeal = Color(0xFF082D2C);
  static const sage = Color(0xFFD2E4B9);
  static const muted = Color(0xFF506B43);
  static const card = Color(0xFFF5F7E9);
  static const mint = Color(0xFFC5E5DA);
  static const forest = Color(0xFF214B22);
  static const deepTeal = Color(0xFF174B49);
  static const outline = Color(0xFF9DB88B);
}

ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.teal,
        surface: AppColors.paper,
      ).copyWith(
        primary: AppColors.deepTeal,
        onPrimary: AppColors.card,
        primaryContainer: AppColors.mint,
        onPrimaryContainer: AppColors.deepTeal,
        secondary: AppColors.teal,
        onSecondary: AppColors.deepTeal,
        secondaryContainer: AppColors.mint,
        onSecondaryContainer: AppColors.deepTeal,
        tertiary: AppColors.teal,
        onSurface: AppColors.ink,
        onSurfaceVariant: AppColors.muted,
        surfaceContainerHighest: AppColors.mint,
        outline: AppColors.outline,
        outlineVariant: AppColors.mint,
        surfaceTint: Colors.transparent,
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
      bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: AppColors.ink),
    ).apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
    iconTheme: const IconThemeData(color: AppColors.deepTeal),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.deepTeal,
      selectedColor: AppColors.deepTeal,
      selectedTileColor: AppColors.mint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.deepTeal,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.paper,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.paper,
      surfaceTintColor: Colors.transparent,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.teal,
        foregroundColor: AppColors.onTeal,
        minimumSize: const Size(double.infinity, 56),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        foregroundColor: AppColors.deepTeal,
        side: const BorderSide(color: AppColors.teal, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
  );
}
