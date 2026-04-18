import 'package:flutter/material.dart';

class AppTheme {
  static const _black = Color(0xFF0A0A0A);
  static const _surface = Color(0xFF141414);
  static const _card = Color(0xFF1E1E1E);
  static const _accent = Color(0xFFFF6B35);
  static const _accentLight = Color(0xFFFF8C5A);
  static const _text = Color(0xFFF5F5F5);
  static const _textMuted = Color(0xFF888888);
  static const _border = Color(0xFF2A2A2A);

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _black,
        colorScheme: const ColorScheme.dark(
          primary: _accent,
          secondary: _accentLight,
          surface: _surface,
          onPrimary: Colors.white,
          onSurface: _text,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _black,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: _text,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
          iconTheme: IconThemeData(color: _text),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: _black,
          selectedItemColor: _accent,
          unselectedItemColor: _textMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        cardTheme: CardTheme(
          color: _card,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _border, width: 0.5),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _surface,
          hintStyle: const TextStyle(color: _textMuted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _accent, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(color: _text, fontSize: 28, fontWeight: FontWeight.w800),
          headlineMedium: TextStyle(color: _text, fontSize: 22, fontWeight: FontWeight.w700),
          titleLarge: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(color: _text, fontSize: 15),
          bodyMedium: TextStyle(color: _textMuted, fontSize: 13),
          labelSmall: TextStyle(color: _textMuted, fontSize: 11),
        ),
        dividerTheme: const DividerThemeData(color: _border, thickness: 0.5),
        extensions: const [VoxaColors()],
      );

  static const accent = _accent;
  static const surface = _surface;
  static const card = _card;
  static const textMuted = _textMuted;
  static const border = _border;
  static const black = _black;
}

class VoxaColors extends ThemeExtension<VoxaColors> {
  const VoxaColors();
  @override
  VoxaColors copyWith() => const VoxaColors();
  @override
  VoxaColors lerp(VoxaColors? other, double t) => const VoxaColors();
}
