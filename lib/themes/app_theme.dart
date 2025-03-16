import 'package:flutter/material.dart';

class AppTheme {
  static const Color _primaryLight = Color(0xFF1E88E5); // Blue
  static const Color _secondaryLight = Color(0xFF64B5F6); // Light Blue
  static const Color _backgroundLight = Color(0xFFF5F5F5); // Light Gray
  static const Color _surfaceLight = Colors.white;
  static const Color _textLight = Color(0xFF212121); // Dark Gray
  static const Color _textSecondaryLight = Color(0xFF757575); // Medium Gray
  static const Color _accentLight = Color(0xFFFFCA28); // Yellow

  static const Color _primaryDark = Color(0xFF42A5F5); // Lighter Blue
  static const Color _secondaryDark = Color(0xFF90CAF9); // Light Blue
  static const Color _backgroundDark = Color(0xFF121212); // Dark Gray
  static const Color _surfaceDark = Color(0xFF1E1E1E); // Darker Gray
  static const Color _textDark = Colors.white;
  static const Color _textSecondaryDark = Color(0xFFB0BEC5); // Light Gray
  static const Color _accentDark = Color(0xFFFFD54F); // Brighter Yellow

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: _primaryLight,
    colorScheme: const ColorScheme.light(
      primary: _primaryLight,
      secondary: _secondaryLight,
      surface: _surfaceLight,
      background: _backgroundLight,
      onPrimary: Colors.white,
      onSecondary: _textLight,
      onSurface: _textLight,
      onBackground: _textLight,
    ),
    scaffoldBackgroundColor: _backgroundLight,
    appBarTheme: const AppBarTheme(
      backgroundColor: _primaryLight,
      foregroundColor: Colors.white,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: _textLight),
      bodyMedium: TextStyle(color: _textSecondaryLight),
      titleLarge: TextStyle(color: _textLight, fontWeight: FontWeight.bold),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryLight,
        foregroundColor: Colors.white,
      ),
    ),
    useMaterial3: true,
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: _primaryDark,
    colorScheme: const ColorScheme.dark(
      primary: _primaryDark,
      secondary: _secondaryDark,
      surface: _surfaceDark,
      background: _backgroundDark,
      onPrimary: Colors.white,
      onSecondary: _textDark,
      onSurface: _textDark,
      onBackground: _textDark,
    ),
    scaffoldBackgroundColor: _backgroundDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: _primaryDark,
      foregroundColor: Colors.white,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: _textDark),
      bodyMedium: TextStyle(color: _textSecondaryDark),
      titleLarge: TextStyle(color: _textDark, fontWeight: FontWeight.bold),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryDark,
        foregroundColor: Colors.white,
      ),
    ),
    useMaterial3: true,
  );
}
