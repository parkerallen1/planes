import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/theme_provider.dart';
import '../providers/category_provider.dart';
import '../models/scan_category.dart';
import '../theme/app_themes.dart';
import '../services/sound_service.dart';
import '../services/storage_service.dart';

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

            // Categories Section
            _buildSectionHeader(context, 'Categories', isPokedex),
            const SizedBox(height: 16),
            _CategoryManager(isPokedex: isPokedex),

            const SizedBox(height: 32),

            // Data Section
            _buildSectionHeader(context, 'Data', isPokedex),
            const SizedBox(height: 16),
            _ExportButton(isPokedex: isPokedex),

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

/// Category manager widget — lists all categories with add/edit/delete
class _CategoryManager extends ConsumerWidget {
  final bool isPokedex;

  const _CategoryManager({required this.isPokedex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(categoryProvider);
    final categories = state.categories;

    return Column(
      children: [
        // Category list
        ...categories.asMap().entries.map((entry) {
          final idx = entry.key;
          final cat = entry.value;
          final isActive = idx == state.activeIndex;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              decoration: BoxDecoration(
                color: isActive
                    ? (isPokedex
                          ? AppThemes.pokedexCard
                          : const Color(0xFF1E2A5A))
                    : (isPokedex
                          ? AppThemes.pokedexDarkGray.withValues(alpha: 0.7)
                          : const Color(0xFF1E1E1E)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive
                      ? (isPokedex
                            ? AppThemes.pokedexRed
                            : Colors.blueAccent)
                      : (isPokedex
                            ? AppThemes.pokedexBlue.withValues(alpha: 0.3)
                            : Colors.white12),
                  width: isActive ? 2 : 1,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: (isPokedex
                                  ? AppThemes.pokedexRed
                                  : Colors.blueAccent)
                              .withValues(alpha: 0.25),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: ListTile(
                leading: Text(cat.emoji, style: const TextStyle(fontSize: 24)),
                title: Text(
                  isPokedex ? cat.name.toUpperCase() : cat.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.white : Colors.white70,
                    letterSpacing: isPokedex ? 1 : 0,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  '${cat.validTags.length} tags · ${cat.geminiContext}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isPokedex
                              ? AppThemes.pokedexRed
                              : Colors.blueAccent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isPokedex ? 'ACTIVE' : 'Active',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: Icon(
                        Icons.edit,
                        size: 18,
                        color: isPokedex
                            ? AppThemes.pokedexLightBlue
                            : Colors.white54,
                      ),
                      onPressed: () =>
                          _showEditDialog(context, ref, idx, cat),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: categories.length > 1
                            ? (isPokedex
                                  ? AppThemes.pokedexRed.withValues(alpha: 0.8)
                                  : Colors.red.withValues(alpha: 0.6))
                            : Colors.white12,
                      ),
                      onPressed: categories.length > 1
                          ? () => _confirmDelete(context, ref, idx, cat)
                          : null,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                onTap: () =>
                    ref.read(categoryProvider.notifier).setActiveIndex(idx),
              ),
            ),
          );
        }),

        // Add new category button
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showAddDialog(context, ref),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isPokedex
                    ? AppThemes.pokedexBlue.withValues(alpha: 0.5)
                    : Colors.blueAccent.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_circle_outline,
                  color: isPokedex
                      ? AppThemes.pokedexLightBlue
                      : Colors.blueAccent,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  isPokedex ? 'ADD NEW CATEGORY' : 'Add New Category',
                  style: TextStyle(
                    color: isPokedex
                        ? AppThemes.pokedexLightBlue
                        : Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                    letterSpacing: isPokedex ? 1 : 0,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Reset to defaults button
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _confirmReset(context, ref),
          icon: const Icon(Icons.restore, size: 16),
          label: Text(
            isPokedex ? 'RESET TO DEFAULTS' : 'Reset to Defaults',
            style: TextStyle(letterSpacing: isPokedex ? 0.5 : 0, fontSize: 12),
          ),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white38,
          ),
        ),
      ],
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    _showCategoryDialog(context, ref, null, null);
  }

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    int index,
    ScanCategory category,
  ) {
    _showCategoryDialog(context, ref, index, category);
  }

  void _showCategoryDialog(
    BuildContext context,
    WidgetRef ref,
    int? editIndex,
    ScanCategory? existing,
  ) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final emojiCtrl = TextEditingController(text: existing?.emoji ?? '');
    final contextCtrl =
        TextEditingController(text: existing?.geminiContext ?? '');
    final tagsCtrl = TextEditingController(
      text: existing?.validTags.join(', ') ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          editIndex == null ? 'Add Category' : 'Edit Category',
          style: const TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: emojiCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Emoji',
                        hintText: '✈️',
                      ),
                      style: const TextStyle(
                        fontSize: 24,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'Planes',
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contextCtrl,
                decoration: const InputDecoration(
                  labelText: 'Gemini Context',
                  hintText: 'aircraft or airplane',
                  helperText: 'How to describe this to Gemini AI',
                  helperStyle: TextStyle(color: Colors.white38, fontSize: 11),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tagsCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Tags',
                  hintText: 'Fighter, Bomber, Transport/Cargo',
                  helperText: 'Comma-separated list of classification tags',
                  helperStyle: TextStyle(color: Colors.white38, fontSize: 11),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final emoji = emojiCtrl.text.trim();
              final geminiContext = contextCtrl.text.trim();
              final tags = tagsCtrl.text
                  .split(',')
                  .map((t) => t.trim())
                  .where((t) => t.isNotEmpty)
                  .toList();

              if (name.isEmpty || emoji.isEmpty || tags.isEmpty) return;

              final category = ScanCategory(
                id: existing?.id ??
                    name.toLowerCase().replaceAll(RegExp(r'\s+'), '_'),
                name: name,
                emoji: emoji,
                geminiContext: geminiContext.isEmpty
                    ? name.toLowerCase()
                    : geminiContext,
                validTags: tags,
              );

              if (editIndex == null) {
                ref.read(categoryProvider.notifier).addCategory(category);
              } else {
                ref
                    .read(categoryProvider.notifier)
                    .updateCategory(editIndex, category);
              }

              Navigator.pop(ctx);
            },
            child: Text(editIndex == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    int index,
    ScanCategory category,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Delete Category?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Remove "${category.name}" from your categories? '
          'Your scanned items in this category will remain saved.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemes.pokedexRed,
            ),
            onPressed: () {
              ref.read(categoryProvider.notifier).removeCategory(index);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Reset Categories?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Restore all default categories (Planes, Cars, Flowers, Trees, Birds)? '
          'Your custom categories will be removed.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(categoryProvider.notifier).resetToDefaults();
              Navigator.pop(ctx);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _ExportButton extends ConsumerStatefulWidget {
  final bool isPokedex;

  const _ExportButton({required this.isPokedex});

  @override
  ConsumerState<_ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends ConsumerState<_ExportButton> {
  bool _exporting = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final storage = ref.read(storageServiceProvider);
      final file = await storage.exportToJson();
      final xFile = XFile(file.path, mimeType: 'application/json');
      await Share.shareXFiles([xFile]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPokedex = widget.isPokedex;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: isPokedex
            ? Border.all(
                color: AppThemes.pokedexBlue.withValues(alpha: 0.3),
                width: 1,
              )
            : null,
      ),
      child: ListTile(
        leading: Icon(
          Icons.download,
          color: isPokedex ? AppThemes.pokedexLightBlue : Colors.blueAccent,
        ),
        title: Text(
          isPokedex ? 'EXPORT BACKUP' : 'Export Backup',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: isPokedex ? 0.5 : 0,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          'Save all sightings as JSON',
          style: TextStyle(
            color: Colors.white60,
            fontSize: 12,
            letterSpacing: isPokedex ? 0.3 : 0,
          ),
        ),
        trailing: _exporting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                Icons.share,
                color: isPokedex ? AppThemes.pokedexBlue : Colors.blueAccent,
              ),
        onTap: _exporting ? null : _export,
      ),
    );
  }
}
