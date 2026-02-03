import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/theme_provider.dart';
import '../theme/app_themes.dart';
import '../services/sound_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(themeProvider);
    final isPokedex = settings.isPokedex;

    return Scaffold(
      appBar: AppBar(title: Text(isPokedex ? 'SETTINGS' : 'Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Theme Section
            _buildSectionHeader(context, 'Theme', isPokedex),
            const SizedBox(height: 16),
            _ThemeToggleCard(isPokedex: isPokedex, settings: settings),

            const SizedBox(height: 32),

            // Font Section (only in Pokedex mode)
            if (isPokedex) ...[
              _buildSectionHeader(context, 'Font Style', isPokedex),
              const SizedBox(height: 16),
              _FontSelector(currentFont: settings.font),
              const SizedBox(height: 32),
            ],

            // Visual Effects Section
            _buildSectionHeader(context, 'Visual Effects', isPokedex),
            const SizedBox(height: 16),
            _ToggleTile(
              icon: Icons.crop_free,
              title: 'Screen Frame',
              subtitle: 'Pokedex device bezel effect',
              value: settings.screenFrame,
              enabled: isPokedex,
              onChanged: (v) =>
                  ref.read(themeProvider.notifier).setScreenFrame(v),
              isPokedex: isPokedex,
            ),
            _ToggleTile(
              icon: Icons.blur_linear,
              title: 'CRT Scanlines',
              subtitle: 'Retro screen line overlay',
              value: settings.crtScanlines,
              enabled: isPokedex,
              onChanged: (v) =>
                  ref.read(themeProvider.notifier).setCrtScanlines(v),
              isPokedex: isPokedex,
            ),
            _ToggleTile(
              icon: Icons.lightbulb,
              title: 'Animated LEDs',
              subtitle: 'Pulsing LED indicators',
              value: settings.animatedLeds,
              enabled: isPokedex,
              onChanged: (v) =>
                  ref.read(themeProvider.notifier).setAnimatedLeds(v),
              isPokedex: isPokedex,
            ),
            _ToggleTile(
              icon: Icons.auto_awesome,
              title: 'Entry Animations',
              subtitle: 'Animated card reveals',
              value: settings.entryAnimation,
              enabled: isPokedex,
              onChanged: (v) =>
                  ref.read(themeProvider.notifier).setEntryAnimation(v),
              isPokedex: isPokedex,
            ),

            const SizedBox(height: 32),

            // Audio Section
            _buildSectionHeader(context, 'Audio', isPokedex),
            const SizedBox(height: 16),
            _ToggleTile(
              icon: Icons.volume_up,
              title: 'Sound Effects',
              subtitle: 'Scan beeps and chimes',
              value: settings.soundEffects,
              enabled: isPokedex,
              onChanged: (v) {
                ref.read(themeProvider.notifier).setSoundEffects(v);
                if (v) {
                  // Play a sample sound when enabling
                  ref.read(soundServiceProvider).play(PokedexSound.select);
                }
              },
              isPokedex: isPokedex,
            ),

            const SizedBox(height: 32),

            // Startup Section
            _buildSectionHeader(context, 'Startup', isPokedex),
            const SizedBox(height: 16),
            _ToggleTile(
              icon: Icons.play_circle_outline,
              title: 'Boot Animation',
              subtitle: 'Pokedex startup sequence',
              value: settings.bootAnimation,
              enabled: isPokedex,
              onChanged: (v) =>
                  ref.read(themeProvider.notifier).setBootAnimation(v),
              isPokedex: isPokedex,
            ),

            const SizedBox(height: 32),

            // About Section
            _buildSectionHeader(context, 'About', isPokedex),
            const SizedBox(height: 16),
            _buildAboutCard(context, isPokedex),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    bool isPokedex,
  ) {
    return Row(
      children: [
        if (isPokedex) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppThemes.pokedexBlue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppThemes.pokedexBlue.withValues(alpha: 0.6),
                  blurRadius: 6,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
        ],
        Text(
          isPokedex ? title.toUpperCase() : title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            letterSpacing: isPokedex ? 3 : 0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildAboutCard(BuildContext context, bool isPokedex) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: isPokedex
            ? Border.all(
                color: AppThemes.pokedexBlue.withValues(alpha: 0.5),
                width: 2,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.airplanemode_active,
                color: isPokedex
                    ? AppThemes.pokedexLightBlue
                    : Colors.blueAccent,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                isPokedex ? 'PLANEDEX' : 'Plane Tracker',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  letterSpacing: isPokedex ? 2 : 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isPokedex
                ? 'Advanced aircraft identification and logging system. Scan, identify, and catalog aircraft in your area.'
                : 'Scan and identify aircraft using AI-powered image recognition.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Version 1.0.0',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

/// Theme selection card with toggle
class _ThemeToggleCard extends ConsumerWidget {
  final bool isPokedex;
  final PokedexSettings settings;

  const _ThemeToggleCard({required this.isPokedex, required this.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: _ThemeCard(
            title: 'Classic',
            subtitle: 'Original dark theme',
            isSelected: !isPokedex,
            previewColors: [
              const Color(0xFF121212),
              Colors.blueAccent,
              const Color(0xFF1E1E1E),
            ],
            onTap: () =>
                ref.read(themeProvider.notifier).setTheme(AppThemeMode.classic),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _ThemeCard(
            title: 'Pokédex',
            subtitle: 'Scanner mode',
            isSelected: isPokedex,
            previewColors: [
              AppThemes.pokedexBlack,
              AppThemes.pokedexRed,
              AppThemes.pokedexBlue,
            ],
            onTap: () =>
                ref.read(themeProvider.notifier).setTheme(AppThemeMode.pokedex),
            isPokedexStyle: true,
          ),
        ),
      ],
    );
  }
}

/// Individual theme preview card
class _ThemeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final List<Color> previewColors;
  final VoidCallback onTap;
  final bool isPokedexStyle;

  const _ThemeCard({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.previewColors,
    required this.onTap,
    this.isPokedexStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: previewColors[0],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? (isPokedexStyle ? AppThemes.pokedexRed : Colors.blueAccent)
                : Colors.white24,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color:
                        (isPokedexStyle
                                ? AppThemes.pokedexRed
                                : Colors.blueAccent)
                            .withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (int i = 0; i < previewColors.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: previewColors[i],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white30, width: 2),
                    ),
                  ),
                ],
                const Spacer(),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: isPokedexStyle
                        ? AppThemes.pokedexRed
                        : Colors.blueAccent,
                    size: 22,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }
}

/// Font selector widget
class _FontSelector extends ConsumerWidget {
  final PokedexFont currentFont;

  const _FontSelector({required this.currentFont});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: PokedexFont.values.map((font) {
        final isSelected = currentFont == font;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _FontTile(
            font: font,
            isSelected: isSelected,
            onTap: () {
              ref.read(themeProvider.notifier).setFont(font);
              if (ref.read(themeProvider).soundEffects) {
                ref.read(soundServiceProvider).play(PokedexSound.select);
              }
            },
          ),
        );
      }).toList(),
    );
  }
}

/// Individual font tile with preview
class _FontTile extends StatelessWidget {
  final PokedexFont font;
  final bool isSelected;
  final VoidCallback onTap;

  const _FontTile({
    required this.font,
    required this.isSelected,
    required this.onTap,
  });

  TextStyle _getFontStyle() {
    const baseStyle = TextStyle(fontSize: 16, color: Colors.white);
    switch (font) {
      case PokedexFont.pressStart:
        return GoogleFonts.pressStart2p(
          textStyle: baseStyle.copyWith(fontSize: 10),
        );
      case PokedexFont.vt323:
        return GoogleFonts.vt323(textStyle: baseStyle.copyWith(fontSize: 20));
      case PokedexFont.orbitron:
        return GoogleFonts.orbitron(textStyle: baseStyle);
      case PokedexFont.audiowide:
        return GoogleFonts.audiowide(textStyle: baseStyle);
      case PokedexFont.system:
        return baseStyle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppThemes.pokedexCard
              : AppThemes.pokedexDarkGray.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppThemes.pokedexRed
                : AppThemes.pokedexBlue.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppThemes.pokedexRed.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    font.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    font.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppThemes.pokedexLightBlue.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Font preview
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppThemes.pokedexBlack,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppThemes.pokedexBlue.withValues(alpha: 0.3),
                ),
              ),
              child: Text('PLANEDEX', style: _getFontStyle()),
            ),
            const SizedBox(width: 12),
            if (isSelected)
              Icon(Icons.check_circle, color: AppThemes.pokedexGreen, size: 24)
            else
              Icon(
                Icons.radio_button_unchecked,
                color: AppThemes.pokedexBlue.withValues(alpha: 0.5),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}

/// Toggle tile for settings
class _ToggleTile extends ConsumerWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final bool isPokedex;

  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.isPokedex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveEnabled = enabled && isPokedex;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: effectiveEnabled ? 1.0 : 0.5,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(12),
            border: isPokedex
                ? Border.all(
                    color: value && effectiveEnabled
                        ? AppThemes.pokedexGreen.withValues(alpha: 0.5)
                        : AppThemes.pokedexBlue.withValues(alpha: 0.3),
                    width: 1,
                  )
                : null,
          ),
          child: ListTile(
            leading: Icon(
              icon,
              color: effectiveEnabled && value
                  ? (isPokedex ? AppThemes.pokedexGreen : Colors.blueAccent)
                  : (isPokedex
                        ? AppThemes.pokedexBlue.withValues(alpha: 0.5)
                        : Colors.grey),
            ),
            title: Text(
              isPokedex ? title.toUpperCase() : title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: isPokedex ? 0.5 : 0,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
                letterSpacing: isPokedex ? 0.3 : 0,
              ),
            ),
            trailing: Switch(
              value: value,
              onChanged: effectiveEnabled ? onChanged : null,
              activeColor: AppThemes.pokedexGreen,
              activeTrackColor: AppThemes.pokedexGreen.withValues(alpha: 0.5),
              inactiveThumbColor: Colors.grey,
              inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
            ),
            onTap: effectiveEnabled ? () => onChanged(!value) : null,
          ),
        ),
      ),
    );
  }
}
