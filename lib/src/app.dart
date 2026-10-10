import 'screens/home_page.dart';
import 'services/app_theme_service.dart';
import 'services/vault_service.dart';
import 'screens/widgets/colors.dart';
import 'package:flutter/material.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final _vaultService = VaultService();
  final _themeService = const AppThemeService();
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final mode = await _themeService.loadThemeMode();
    if (!mounted) return;
    setState(() => _themeMode = mode);
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    await _themeService.saveThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Awesome Safe',
      theme: AppColors.lightTheme,
      darkTheme: AppColors.darkTheme,
      themeMode: _themeMode,
      home: HomePage(
        vaultService: _vaultService,
        themeMode: _themeMode,
        onThemeModeChanged: _setThemeMode
      ),
      );
  }
}
