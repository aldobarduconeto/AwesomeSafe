import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeService {
  const AppThemeService();

  static final _preferences = SharedPreferencesAsync();

  Future<ThemeMode> loadThemeMode() async {
    final savedMode = await _preferences.getString('theme_mode');

    if (savedMode == 'dark') return ThemeMode.dark;
    if (savedMode == 'light') return ThemeMode.light;
    if (savedMode == 'system') return ThemeMode.system;

    final legacyDark = await _preferences.getBool('dark_theme');
    if (legacyDark != null) {
      return legacyDark ? ThemeMode.dark : ThemeMode.light;
    }

    return ThemeMode.system;
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    await _preferences.setString(
      'theme_mode',
      switch (mode) {
        ThemeMode.dark => 'dark',
        ThemeMode.light => 'light',
        ThemeMode.system => 'system',
      },
    );
    await _preferences.setBool('dark_theme', mode == ThemeMode.dark);
  }
}
