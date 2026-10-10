import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeService {
  const AppThemeService();

  Future<ThemeMode> loadThemeMode() async {
    final preferences = await SharedPreferences.getInstance();
    final savedMode = preferences.getString('theme_mode');

    if (savedMode == 'dark') return ThemeMode.dark;
    if (savedMode == 'light') return ThemeMode.light;
    if (savedMode == 'system') return ThemeMode.system;

    final legacyDark = preferences.getBool('dark_theme');
    if (legacyDark != null) {
      return legacyDark ? ThemeMode.dark : ThemeMode.light;
    }

    return ThemeMode.system;
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      'theme_mode',
      switch (mode) {
        ThemeMode.dark => 'dark',
        ThemeMode.light => 'light',
        ThemeMode.system => 'system',
      },
    );
    await preferences.setBool('dark_theme', mode == ThemeMode.dark);
  }
}
