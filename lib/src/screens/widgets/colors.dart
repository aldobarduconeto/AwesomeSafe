import 'package:flutter/material.dart';

/// Centralização de todas as cores do aplicativo Awesome Safe.
/// Mantém o visual limpo, monocromático (preto e branco) com azul nos botões.
abstract final class AppColors {
  // ── Cores de Ação e Destaque ──
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color selectionBlue = Color(0x332563EB);
  static const Color error = Color(0xFFDC2626);
  static const Color deleteRed = Color(0xFFDC2626);
  // ── Paleta do Modo Claro ──
  static const Color lightScaffold = Colors.white;
  static const Color lightSurface = Colors.white;
  static const Color lightCard = Colors.white;
  static const Color lightText = Colors.black;
  static const Color lightTextSecondary = Color(0xFF52525B);
  static const Color lightBorder = Color(0xFFE4E4E7);
  static const Color lightOutline = Color(0xFFD4D4D8);
  static const Color lightOutlineVariant = Color(0xFFE4E4E7);
  static const Color lightInputFill = Color(0xFFF9FAFB);
  static const Color lightContainerLowest = Colors.white;
  static const Color lightContainerLow = Color(0xFFFAFAFA);
  static const Color lightContainer = Color(0xFFF4F4F5);
  static const Color lightContainerHigh = Color(0xFFEBEBEB);
  static const Color lightContainerHighest = Color(0xFFE4E4E7);
  static const Color lightPrimaryContainer = Color(0xFFF4F4F5);
  // ── Paleta do Modo Escuro ──
  static const Color darkScaffold = Colors.black;
  static const Color darkSurface = Colors.black;
  static const Color darkCard = Color(0xFF111111);
  static const Color darkText = Colors.white;
  static const Color darkTextSecondary = Color(0xFFA1A1AA);
  static const Color darkBorder = Color(0xFF222222);
  static const Color darkOutline = Color(0xFF3F3F46);
  static const Color darkOutlineVariant = Color(0xFF27272A);
  static const Color darkInputFill = Color(0xFF111111);
  static const Color darkContainerLowest = Colors.black;
  static const Color darkContainerLow = Color(0xFF0A0A0A);
  static const Color darkContainer = Color(0xFF121212);
  static const Color darkContainerHigh = Color(0xFF181818);
  static const Color darkContainerHighest = Color(0xFF202020);
  static const Color darkPrimaryContainer = Color(0xFF1E1E1E);
  // ── Overlays, Sombras e Transparências ──
  static const Color lightBarrier = Colors.black87;
  static const Color darkBarrier = Colors.black;
  static const Color cardShadow = Colors.black45;
  static const Color transparent = Colors.transparent;
  
  // ── Color Schemes ──
  static ColorScheme get lightColorScheme => ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.light,
        primary: primaryBlue,
        onPrimary: Colors.white,
        primaryContainer: lightPrimaryContainer,
        onPrimaryContainer: Colors.black,
        surface: lightSurface,
        onSurface: lightText,
        surfaceContainerLowest: lightContainerLowest,
        surfaceContainerLow: lightContainerLow,
        surfaceContainer: lightContainer,
        surfaceContainerHigh: lightContainerHigh,
        surfaceContainerHighest: lightContainerHighest,
        onSurfaceVariant: lightTextSecondary,
        outline: lightOutline,
        outlineVariant: lightOutlineVariant,
        surfaceTint: transparent,
      );

  static ColorScheme get darkColorScheme => ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.dark,
        primary: primaryBlue,
        onPrimary: Colors.white,
        primaryContainer: darkPrimaryContainer,
        onPrimaryContainer: Colors.white,
        surface: darkSurface,
        onSurface: darkText,
        surfaceContainerLowest: darkContainerLowest,
        surfaceContainerLow: darkContainerLow,
        surfaceContainer: darkContainer,
        surfaceContainerHigh: darkContainerHigh,
        surfaceContainerHighest: darkContainerHighest,
        onSurfaceVariant: darkTextSecondary,
        outline: darkOutline,
        outlineVariant: darkOutlineVariant,
        surfaceTint: transparent,
      );

  // ── Construção unificada de ThemeData (sem redundâncias) ──
  static ThemeData _buildTheme({
    required Brightness brightness,
    required ColorScheme scheme,
    required Color scaffoldBg,
    required Color cardBg,
    required Color borderColor,
    required Color inputFill,
  }) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      cardColor: cardBg,
      dividerColor: borderColor,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? darkSurface : lightSurface,
        foregroundColor: isDark ? darkText : lightText,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side: const BorderSide(color: primaryBlue, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: primaryBlue,
          selectedForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: primaryBlue,
        selectionColor: selectionBlue,
        selectionHandleColor: primaryBlue,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        border: OutlineInputBorder(
          borderSide: BorderSide(color: borderColor),
          borderRadius: BorderRadius.circular(14),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: borderColor),
          borderRadius: BorderRadius.circular(14),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  static final ThemeData lightTheme = _buildTheme(
    brightness: Brightness.light,
    scheme: lightColorScheme,
    scaffoldBg: lightScaffold,
    cardBg: lightCard,
    borderColor: lightBorder,
    inputFill: lightInputFill,
  );

  static final ThemeData darkTheme = _buildTheme(
    brightness: Brightness.dark,
    scheme: darkColorScheme,
    scaffoldBg: darkScaffold,
    cardBg: darkCard,
    borderColor: darkBorder,
    inputFill: darkInputFill,
  );
}