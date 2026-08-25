import 'package:flutter/material.dart';

/// Premium financial look — deep navy surfaces, gold accent.
abstract final class AppTheme {
  static const gold = Color(0xFFD4A942);
  static const green = Color(0xFF2EAE6C);
  static const red = Color(0xFFE5484D);
  static const navy = Color(0xFF0B1220);

  static ThemeData light() => _base(
    brightness: Brightness.light,
    scaffold: const Color(0xFFF6F7FB),
    surface: Colors.white,
    text: const Color(0xFF101828),
    subtext: const Color(0xFF5A6474),
  );

  static ThemeData dark() => _base(
    brightness: Brightness.dark,
    scaffold: navy,
    surface: const Color(0xFF141C2F),
    text: const Color(0xFFF2F5FA),
    subtext: const Color(0xFF98A2B3),
  );

  static ThemeData _base({
    required Brightness brightness,
    required Color scaffold,
    required Color surface,
    required Color text,
    required Color subtext,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: gold,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(surface: surface),
      scaffoldBackgroundColor: scaffold,
      fontFamily: 'Vazirmatn',
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: text,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: subtext.withValues(alpha: 0.15)),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: gold.withValues(alpha: 0.25),
        iconTheme: WidgetStatePropertyAll(IconThemeData(color: text)),
      ),
      dividerColor: subtext.withValues(alpha: 0.15),
    );
  }
}
