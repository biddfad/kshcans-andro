import 'package:flutter/material.dart';
import '../core/database/db_helper.dart';

class ThemeProvider with ChangeNotifier {
  String _accentName = 'Cyan Neon';
  Color _accentColor = const Color(0xFF00E5FF);
  String _styleName = 'OLED Hitam Pekat';
  Color _bgDark = const Color(0xFF000000);
  Color _surfaceDark = const Color(0xFF121212);
  Color _cardDark = const Color(0xFF1E1E1E);

  ThemeProvider() {
    _loadSavedSettings();
  }

  String get accentName => _accentName;
  Color get accentColor => _accentColor;
  String get styleName => _styleName;

  Future<void> _loadSavedSettings() async {
    try {
      final savedStyle = await DBHelper.instance.getSetting('theme_style');
      final savedAccent = await DBHelper.instance.getSetting('theme_accent');
      if (savedStyle != null && savedStyle.isNotEmpty) {
        setStyle(savedStyle, save: false);
      }
      if (savedAccent != null && savedAccent.isNotEmpty) {
        final color = _getAccentColorFromName(savedAccent);
        setAccent(savedAccent, color, save: false);
      }
    } catch (_) {}
  }

  static Color _getAccentColorFromName(String name) {
    switch (name) {
      case 'Pink KsH Katana':
        return const Color(0xFFFF2E93);
      case 'Ungu Cyber':
        return const Color(0xFF9D00FF);
      case 'Hijau Emerald':
        return const Color(0xFF00E676);
      default:
        return const Color(0xFF00E5FF);
    }
  }

  void setAccent(String name, Color color, {bool save = true}) {
    _accentName = name;
    _accentColor = color;
    if (save) {
      DBHelper.instance.saveSetting('theme_accent', name);
    }
    notifyListeners();
  }

  void setStyle(String style, {bool save = true}) {
    _styleName = style;
    if (style == 'Dark Charcoal') {
      _bgDark = const Color(0xFF161618);
      _surfaceDark = const Color(0xFF222226);
      _cardDark = const Color(0xFF2A2A30);
    } else {
      // OLED Hitam Pekat
      _bgDark = const Color(0xFF000000);
      _surfaceDark = const Color(0xFF121212);
      _cardDark = const Color(0xFF1E1E1E);
    }
    if (save) {
      DBHelper.instance.saveSetting('theme_style', style);
    }
    notifyListeners();
  }

  ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _bgDark,
      canvasColor: _bgDark,
      cardColor: _cardDark,
      colorScheme: ColorScheme.dark(
        primary: _accentColor,
        secondary: _accentColor.withValues(alpha: 0.8),
        surface: _surfaceDark,
        error: const Color(0xFFFF5252),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _bgDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _bgDark,
        indicatorColor: _accentColor.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: _accentColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            );
          }
          return const TextStyle(color: Color(0xFF9E9E9E), fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: _accentColor);
          }
          return const IconThemeData(color: Color(0xFF9E9E9E));
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: _accentColor,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _cardDark,
        selectedColor: _accentColor.withValues(alpha: 0.2),
        labelStyle: const TextStyle(color: Colors.white, fontSize: 13),
        secondaryLabelStyle: TextStyle(color: _accentColor, fontWeight: FontWeight.bold),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
