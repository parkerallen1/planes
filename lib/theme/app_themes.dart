import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/theme_provider.dart';

/// App theme definitions - Classic (current) and Pokedex theme
class AppThemes {
  // ============================================
  // CLASSIC THEME (Original dark blue theme)
  // ============================================
  static ThemeData get classicTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blueAccent,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // ============================================
  // POKEDEX THEME
  // ============================================

  // Pokedex Color Palette
  static const Color pokedexRed = Color(0xFFDC0A2D);
  static const Color pokedexDarkRed = Color(0xFF9B1B30);
  static const Color pokedexBlack = Color(0xFF1A1A2E);
  static const Color pokedexDarkGray = Color(0xFF16213E);
  static const Color pokedexBlue = Color(0xFF3D7DCA);
  static const Color pokedexLightBlue = Color(0xFF50C4ED);
  static const Color pokedexYellow = Color(0xFFFFCB05);
  static const Color pokedexGreen = Color(0xFF4CAF50);
  static const Color pokedexSurface = Color(0xFF1E2A4A);
  static const Color pokedexCard = Color(0xFF0F3460);

  /// Get the appropriate TextTheme for the selected font
  static TextTheme _getPokedexTextTheme(PokedexFont font) {
    TextStyle Function(TextStyle?) fontApplier;

    switch (font) {
      case PokedexFont.pressStart:
        fontApplier = (style) => GoogleFonts.pressStart2p(textStyle: style);
        break;
      case PokedexFont.vt323:
        fontApplier = (style) => GoogleFonts.vt323(textStyle: style);
        break;
      case PokedexFont.orbitron:
        fontApplier = (style) => GoogleFonts.orbitron(textStyle: style);
        break;
      case PokedexFont.audiowide:
        fontApplier = (style) => GoogleFonts.audiowide(textStyle: style);
        break;
      case PokedexFont.system:
        // Return default text theme
        return const TextTheme(
          headlineLarge: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
          headlineMedium: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
          titleLarge: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
          titleMedium: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
          labelLarge: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        );
    }

    // Apply the selected font to all text styles
    // For pixel fonts like Press Start 2P, we need smaller sizes
    final bool isPixelFont = font == PokedexFont.pressStart;
    final double sizeMultiplier = isPixelFont ? 0.6 : 1.0;

    return TextTheme(
      headlineLarge: fontApplier(
        TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          fontSize: 32 * sizeMultiplier,
        ),
      ),
      headlineMedium: fontApplier(
        TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          fontSize: 28 * sizeMultiplier,
        ),
      ),
      titleLarge: fontApplier(
        TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          fontSize: 22 * sizeMultiplier,
        ),
      ),
      titleMedium: fontApplier(
        TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 16 * sizeMultiplier,
        ),
      ),
      bodyLarge: fontApplier(
        TextStyle(color: Colors.white, fontSize: 16 * sizeMultiplier),
      ),
      bodyMedium: fontApplier(
        TextStyle(color: Colors.white70, fontSize: 14 * sizeMultiplier),
      ),
      bodySmall: fontApplier(
        TextStyle(color: Colors.white54, fontSize: 12 * sizeMultiplier),
      ),
      labelLarge: fontApplier(
        TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
          fontSize: 14 * sizeMultiplier,
        ),
      ),
      labelMedium: fontApplier(
        TextStyle(color: Colors.white, fontSize: 12 * sizeMultiplier),
      ),
      labelSmall: fontApplier(
        TextStyle(color: Colors.white70, fontSize: 10 * sizeMultiplier),
      ),
    );
  }

  /// Build the Pokedex theme with the selected font
  static ThemeData pokedexTheme({PokedexFont font = PokedexFont.system}) {
    final textTheme = _getPokedexTextTheme(font);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      textTheme: textTheme,

      // Color Scheme
      colorScheme: ColorScheme.dark(
        primary: pokedexRed,
        onPrimary: Colors.white,
        primaryContainer: pokedexDarkRed,
        onPrimaryContainer: Colors.white,
        secondary: pokedexBlue,
        onSecondary: Colors.white,
        secondaryContainer: pokedexDarkGray,
        onSecondaryContainer: pokedexLightBlue,
        tertiary: pokedexYellow,
        onTertiary: Colors.black,
        surface: pokedexSurface,
        onSurface: Colors.white,
        error: const Color(0xFFFF5252),
        onError: Colors.white,
      ),

      // Scaffold
      scaffoldBackgroundColor: pokedexBlack,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: pokedexDarkRed,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          letterSpacing: 2,
          color: Colors.white,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),

      // Cards - Pokedex entry style
      cardTheme: CardThemeData(
        color: pokedexCard,
        elevation: 8,
        shadowColor: pokedexBlue.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: pokedexBlue.withValues(alpha: 0.5), width: 2),
        ),
        margin: const EdgeInsets.all(8),
      ),

      // Elevated Buttons - Device button style
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: pokedexRed,
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: pokedexRed.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
            side: const BorderSide(color: Colors.white24, width: 2),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      // Text Buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: pokedexLightBlue,
          textStyle: textTheme.labelLarge,
        ),
      ),

      // Floating Action Button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: pokedexRed,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white30, width: 2),
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: pokedexDarkGray.withValues(alpha: 0.7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: pokedexBlue.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: pokedexBlue.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: pokedexBlue, width: 2),
        ),
        labelStyle: TextStyle(color: pokedexLightBlue.withValues(alpha: 0.8)),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        prefixIconColor: pokedexBlue,
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: pokedexDarkGray,
        selectedColor: pokedexRed,
        disabledColor: pokedexDarkGray.withValues(alpha: 0.5),
        labelStyle:
            textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ) ??
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: pokedexBlue.withValues(alpha: 0.5)),
        ),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: pokedexSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: pokedexBlue.withValues(alpha: 0.5), width: 2),
        ),
        titleTextStyle: textTheme.titleLarge,
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: pokedexBlue.withValues(alpha: 0.3),
        thickness: 1,
        space: 24,
      ),

      // Icon Theme
      iconTheme: const IconThemeData(color: pokedexLightBlue),

      // Progress Indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: pokedexLightBlue,
        linearTrackColor: pokedexDarkGray,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: pokedexCard,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: pokedexBlue),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Extension to check if current theme is Pokedex
extension ThemeChecker on ThemeData {
  bool get isPokedexTheme => colorScheme.primary == AppThemes.pokedexRed;
}
