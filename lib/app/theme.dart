import 'package:flutter/material.dart';

/// Shared visual system for the entire MOLIDO MARKET application.
abstract final class AppTheme {
  static const gold = Color(0xFFD6A84B);
  static const goldDeep = Color(0xFFB98524);
  static const green = Color(0xFF159B69);
  static const red = Color(0xFFE0525B);
  static const navy = Color(0xFF0B1424);
  static const lightCanvas = Color(0xFFF4F6FA);
  static const darkSurface = Color(0xFF131F32);

  static ThemeData light() => _base(
    brightness: Brightness.light,
    scaffold: lightCanvas,
    surface: Colors.white,
    text: const Color(0xFF172235),
    subtext: const Color(0xFF697589),
  );

  static ThemeData dark() => _base(
    brightness: Brightness.dark,
    scaffold: navy,
    surface: darkSurface,
    text: const Color(0xFFF4F6FA),
    subtext: const Color(0xFF9AA8BC),
  );

  static ThemeData _base({
    required Brightness brightness,
    required Color scaffold,
    required Color surface,
    required Color text,
    required Color subtext,
  }) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: gold,
      brightness: brightness,
      surface: surface,
    );
    final outline = subtext.withValues(alpha: dark ? 0.22 : 0.14);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme.copyWith(
        primary: dark ? const Color(0xFFE4B95E) : goldDeep,
        secondary: green,
        error: red,
        surface: surface,
      ),
      scaffoldBackgroundColor: scaffold,
      fontFamily: 'Vazirmatn',
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: text,
          fontFamily: 'Vazirmatn',
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: IconThemeData(color: text),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: outline),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        indicatorColor: gold.withValues(alpha: dark ? 0.22 : 0.16),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: states.contains(WidgetState.selected) ? 24 : 22,
            color: states.contains(WidgetState.selected) ? goldDeep : subtext,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? goldDeep : subtext,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF1B2940) : const Color(0xFFF8F9FC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: gold, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: goldDeep,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(color: outline),
        ),
      ),
      dividerColor: outline,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
