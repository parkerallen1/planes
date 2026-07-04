import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/theme_provider.dart';

/// App theme definitions - Classic (current) and Retro theme
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
  // RETRO THEME
  // ============================================

  // Retro Color Palette
  static const Color retroRed = Color(0xFFDC0A2D);
  static const Color retroDarkRed = Color(0xFF9B1B30);
  static const Color retroBlack = Color(0xFF1A1A2E);
  static const Color retroDarkGray = Color(0xFF16213E);
  static const Color retroBlue = Color(0xFF3D7DCA);
  static const Color retroLightBlue = Color(0xFF50C4ED);
  static const Color retroYellow = Color(0xFFFFCB05);
  static const Color retroGreen = Color(0xFF4CAF50);
  static const Color retroSurface = Color(0xFF1E2A4A);
  static const Color retroCard = Color(0xFF0F3460);

  /// Get the appropriate TextTheme for the selected font
  static TextTheme _getRetroTextTheme(RetroFont font) {
    TextStyle Function(TextStyle?) fontApplier;

    switch (font) {
      case RetroFont.pressStart:
        fontApplier = (style) => GoogleFonts.pressStart2p(textStyle: style);
        break;
      case RetroFont.vt323:
        fontApplier = (style) => GoogleFonts.vt323(textStyle: style);
        break;
      case RetroFont.orbitron:
        fontApplier = (style) => GoogleFonts.orbitron(textStyle: style);
        break;
      case RetroFont.audiowide:
        fontApplier = (style) => GoogleFonts.audiowide(textStyle: style);
        break;
      case RetroFont.system:
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
    final bool isPixelFont = font == RetroFont.pressStart;
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

  /// Build the Retro theme with the selected font
  static ThemeData retroTheme({RetroFont font = RetroFont.system}) {
    final textTheme = _getRetroTextTheme(font);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      textTheme: textTheme,

      // Color Scheme
      colorScheme: ColorScheme.dark(
        primary: retroRed,
        onPrimary: Colors.white,
        primaryContainer: retroDarkRed,
        onPrimaryContainer: Colors.white,
        secondary: retroBlue,
        onSecondary: Colors.white,
        secondaryContainer: retroDarkGray,
        onSecondaryContainer: retroLightBlue,
        tertiary: retroYellow,
        onTertiary: Colors.black,
        surface: retroSurface,
        onSurface: Colors.white,
        error: const Color(0xFFFF5252),
        onError: Colors.white,
      ),

      // Scaffold
      scaffoldBackgroundColor: retroBlack,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: retroDarkRed,
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

      // Cards - Retro entry style
      cardTheme: CardThemeData(
        color: retroCard,
        elevation: 8,
        shadowColor: retroBlue.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: retroBlue.withValues(alpha: 0.5), width: 2),
        ),
        margin: const EdgeInsets.all(8),
      ),

      // Elevated Buttons - Device button style
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: retroRed,
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: retroRed.withValues(alpha: 0.5),
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
          foregroundColor: retroLightBlue,
          textStyle: textTheme.labelLarge,
        ),
      ),

      // Floating Action Button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: retroRed,
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
        fillColor: retroDarkGray.withValues(alpha: 0.7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: retroBlue.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: retroBlue.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: retroBlue, width: 2),
        ),
        labelStyle: TextStyle(color: retroLightBlue.withValues(alpha: 0.8)),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        prefixIconColor: retroBlue,
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: retroDarkGray,
        selectedColor: retroRed,
        disabledColor: retroDarkGray.withValues(alpha: 0.5),
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
          side: BorderSide(color: retroBlue.withValues(alpha: 0.5)),
        ),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: retroSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: retroBlue.withValues(alpha: 0.5), width: 2),
        ),
        titleTextStyle: textTheme.titleLarge,
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: retroBlue.withValues(alpha: 0.3),
        thickness: 1,
        space: 24,
      ),

      // Icon Theme
      iconTheme: const IconThemeData(color: retroLightBlue),

      // Progress Indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: retroLightBlue,
        linearTrackColor: retroDarkGray,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: retroCard,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: retroBlue),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Extension to check if current theme is Retro
extension ThemeChecker on ThemeData {
  bool get isRetroTheme => colorScheme.primary == AppThemes.retroRed;
}
