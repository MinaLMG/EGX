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

  String _themeSetting = 'system';
  Locale _locale = const Locale('en');

  String get themeSetting => _themeSetting;
  Locale get locale => _locale;
  bool get isArabic => _locale.languageCode == 'ar';

  ThemeMode get themeMode {
    if (_themeSetting == 'phosphor') return ThemeMode.dark;
    if (_themeSetting == 'dark') return ThemeMode.dark;
    if (_themeSetting == 'light') return ThemeMode.light;
    return ThemeMode.system;
  }

  /// Call once on startup to restore saved settings.
  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    _themeSetting = prefs.getString(_themeKey) ?? 'system';

    final lang = prefs.getString(_langKey) ?? 'en';
    _locale = Locale(lang);

    notifyListeners();
  }

  Future<void> setTheme(String themeStr) async {
    if (_themeSetting == themeStr) return;
    _themeSetting = themeStr;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, themeStr);
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale.languageCode == locale.languageCode) return;
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, locale.languageCode);
  }

  String themeString() => _themeSetting;
}
