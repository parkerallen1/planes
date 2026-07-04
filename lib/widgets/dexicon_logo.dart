import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_themes.dart';

/// Retro "DEXICON" wordmark used on the boot screen and home header.
class DexiconLogo extends StatelessWidget {
  final double fontSize;

  const DexiconLogo({super.key, this.fontSize = 32});

  @override
  Widget build(BuildContext context) {
    return Text(
      'DEXICON',
      style: GoogleFonts.audiowide(
        fontSize: fontSize,
        color: Colors.white,
        letterSpacing: fontSize * 0.12,
        shadows: [
          Shadow(
            color: AppThemes.retroLightBlue.withValues(alpha: 0.8),
            blurRadius: 12,
          ),
          Shadow(
            color: AppThemes.retroBlue.withValues(alpha: 0.6),
            blurRadius: 24,
          ),
        ],
      ),
    );
  }
}
