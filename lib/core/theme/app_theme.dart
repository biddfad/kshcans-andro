import 'package:flutter/material.dart';

class AppTheme {
  static const Color oledBlack = Color(0xFF000000);
  static const Color surfaceDark = Color(0xFF121212);
  static const Color cardDark = Color(0xFF1E1E1E);
  static const Color accentCyan = Color(0xFF00E5FF);
  static const Color accentBlue = Color(0xFF29B6F6);
  static const Color unreadBadgeRed = Color(0xFFFF5252);
  static const Color textMuted = Color(0xFF9E9E9E);

  static ThemeData get oledTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: oledBlack,
      canvasColor: oledBlack,
      cardColor: cardDark,
      colorScheme: const ColorScheme.dark(
        primary: accentCyan,
        secondary: accentBlue,
        surface: surfaceDark,
        error: unreadBadgeRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: oledBlack,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: oledBlack,
        indicatorColor: const Color(0x3300E5FF),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: accentCyan,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            );
          }
          return const TextStyle(color: textMuted, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: accentCyan);
          }
          return const IconThemeData(color: textMuted);
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cardDark,
        selectedColor: const Color(0x4000E5FF),
        secondarySelectedColor: accentCyan,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        labelStyle: const TextStyle(fontSize: 13, color: Colors.white),
        secondaryLabelStyle: const TextStyle(fontSize: 13, color: accentCyan),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x1AFFFFFF)),
        ),
      ),
    );
  }
}
