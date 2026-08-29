import 'package:flutter/material.dart';

class AppTheme {
  // Soft-Bright palette details
  static const Color lightBg = Color(0xFFF5F3EF); // Warm cream/linen background
  static const Color lightSurface = Color(0xFFFFFFFF); // Pure white cards/dialogs
  static const Color lightBorder = Color(0xFFE5E7EB); // Subtle border
  static const Color lightTextPrimary = Color(0xFF1F2937); // Deep charcoal
  static const Color lightTextSecondary = Color(0xFF6B7280); // Secondary slate gray
  static const Color accentColor = Color(0xFF2563EB); // Royal Blue Accent

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      cardColor: lightSurface,
      dividerColor: lightBorder,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentColor,
        brightness: Brightness.light,
        surface: lightSurface,
        onSurface: lightTextPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: lightTextPrimary),
        titleTextStyle: TextStyle(
          color: lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: lightTextPrimary, fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(color: lightTextPrimary),
        bodyMedium: TextStyle(color: lightTextPrimary),
        bodySmall: TextStyle(color: lightTextSecondary),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightBorder),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: lightBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        labelStyle: const TextStyle(color: lightTextSecondary),
        hintStyle: const TextStyle(color: Colors.black26),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentColor, width: 2),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }
}
