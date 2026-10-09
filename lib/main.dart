import 'screens/home_page.dart';
import 'services/app_theme_service.dart';
import 'services/vault_service.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AwesomeSafeApp());
}

class AwesomeSafeApp extends StatefulWidget {
  const AwesomeSafeApp({super.key});

  @override
  State<AwesomeSafeApp> createState() => _AwesomeSafeAppState();
}

class _AwesomeSafeAppState extends State<AwesomeSafeApp> {
  final _vaultService = VaultService();
  final _themeService = const AppThemeService();
  ThemeMode _themeMode = ThemeMode.system;

  // Temas estáticos e cacheados para evitar alocações constantes de ThemeData
  static final ThemeData _androidTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1D6B62), brightness: Brightness.light),
    scaffoldBackgroundColor: const Color(0xFFF6F7F4),
    cardColor: Colors.white,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
          borderSide: BorderSide.none, borderRadius: BorderRadius.circular(14)),
    ),
  );

  static final ThemeData _androidDarkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF56B8A7),
      brightness: Brightness.dark,
      surface: Colors.black,
      onSurface: Colors.white,
      surfaceContainerHighest: const Color(0xFF111111),
      surfaceContainer: const Color(0xFF0D0D0D),
      surfaceContainerLow: const Color(0xFF080808),
      surfaceContainerHigh: const Color(0xFF161616),
    ),
    scaffoldBackgroundColor: Colors.black,
    cardColor: const Color(0xFF111111),
    dividerColor: const Color(0xFF222222),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF111111),
      border: OutlineInputBorder(
          borderSide: BorderSide.none, borderRadius: BorderRadius.circular(14)),
    ),
  );

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
        theme: _androidTheme,
        darkTheme: _androidDarkTheme,
        themeMode: _themeMode,
        home: HomePage(
            vaultService: _vaultService,
            themeMode: _themeMode,
            onThemeModeChanged: _setThemeMode));
  }
}
