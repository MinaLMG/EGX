import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global app settings singleton — manages theme and locale.
/// Call [AppSettings.instance] to access from anywhere.
/// Listen via [ListenableBuilder] or [AnimatedBuilder].
class AppSettings extends ChangeNotifier {
  static final AppSettings instance = AppSettings._();
  AppSettings._();

  static const _themeKey = 'app_theme';
  static const _langKey = 'app_language';

  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('en');

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  bool get isArabic => _locale.languageCode == 'ar';

  /// Call once on startup to restore saved settings.
  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final themeStr = prefs.getString(_themeKey) ?? 'system';
    _themeMode = _themeFromString(themeStr);

    final lang = prefs.getString(_langKey) ?? 'en';
    _locale = Locale(lang);

    notifyListeners();
  }

  Future<void> setTheme(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, _themeToString(mode));
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale.languageCode == locale.languageCode) return;
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, locale.languageCode);
  }

  String themeString() => _themeToString(_themeMode);

  static ThemeMode _themeFromString(String s) {
    switch (s) {
      case 'dark':   return ThemeMode.dark;
      case 'light':  return ThemeMode.light;
      default:       return ThemeMode.system;
    }
  }

  static String _themeToString(ThemeMode m) {
    switch (m) {
      case ThemeMode.dark:  return 'dark';
      case ThemeMode.light: return 'light';
      default:              return 'system';
    }
  }
}
