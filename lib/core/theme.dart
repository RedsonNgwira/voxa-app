import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const _black = Color(0xFF0A0A0A);
  static const _surface = Color(0xFF141414);
  static const _card = Color(0xFF1E1E1E);
  static const _accent = Color(0xFFE8622A);   // ember per spec 8.1
  static const _accentLight = Color(0xFFC9A84C); // gold per spec 8.1
  static const _text = Color(0xFFF0E6D3);     // textPrimary per spec 8.1
  static const _textMuted = Color(0xFF8A7565); // textDim per spec 8.1
  static const _border = Color(0xFF1E1812);

  static ThemeData get dark {
    // DM Sans for all body text (spec 8.2)
    final dmSans = GoogleFonts.dmSansTextTheme(const TextTheme(
      headlineLarge: TextStyle(color: _text, fontSize: 28, fontWeight: FontWeight.w800),
      headlineMedium: TextStyle(color: _text, fontSize: 22, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(color: _text, fontSize: 15),
      bodyMedium: TextStyle(color: _textMuted, fontSize: 13),
      labelSmall: TextStyle(color: _textMuted, fontSize: 11),
    ));

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _black,
      colorScheme: const ColorScheme.dark(
        primary: _accent,
        secondary: _accentLight,
        surface: _surface,
        onPrimary: Colors.white,
        onSurface: _text,
      ),
      textTheme: dmSans,
      appBarTheme: AppBarTheme(
        backgroundColor: _black,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.dmSans(
          color: _text, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0.5,
        ),
        iconTheme: const IconThemeData(color: _text),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _black,
        selectedItemColor: _accent,
        unselectedItemColor: _textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
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
        hintStyle: GoogleFonts.dmSans(color: _textMuted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _accent, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(color: _border, thickness: 0.5),
      extensions: const [VoxaColors()],
    );
  }

  static const accent = _accent;
  static const gold = _accentLight;
  static const surface = _surface;
  static const card = _card;
  static const textMuted = _textMuted;
  static const border = _border;
  static const black = _black;
}

/// Playfair Display — logo/wordmark only (spec 8.2)
class VoxaLogo extends StatelessWidget {
  final double fontSize;
  final Color? color;
  const VoxaLogo({super.key, this.fontSize = 28, this.color});

  @override
  Widget build(BuildContext context) => Text(
    'Voxa',
    style: GoogleFonts.playfairDisplay(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: color ?? AppTheme.accent,
    ),
  );
}

class VoxaColors extends ThemeExtension<VoxaColors> {
  const VoxaColors();
  @override VoxaColors copyWith() => const VoxaColors();
  @override VoxaColors lerp(VoxaColors? other, double t) => const VoxaColors();
}
