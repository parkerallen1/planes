import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/theme_provider.dart';
import '../providers/category_provider.dart';
import '../models/scan_category.dart';
import '../theme/app_themes.dart';
import '../services/gemini_service.dart';
import '../services/sound_service.dart';
import '../services/storage_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(themeProvider);
    final isRetro = settings.isRetro;

    return Scaffold(
      appBar: AppBar(title: Text(isRetro ? 'SETTINGS' : 'Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Theme Section
            _buildSectionHeader(context, 'Theme', isRetro),
            const SizedBox(height: 16),
            _ThemeToggleCard(isRetro: isRetro, settings: settings),

            const SizedBox(height: 32),

            // Font Section (only in Retro mode)
            if (isRetro) ...[
              _buildSectionHeader(context, 'Font Style', isRetro),
              const SizedBox(height: 16),
              _FontSelector(currentFont: settings.font),
              const SizedBox(height: 32),
            ],

            // Visual Effects Section
            _buildSectionHeader(context, 'Visual Effects', isRetro),
            const SizedBox(height: 16),
            _ToggleTile(
              icon: Icons.crop_free,
              title: 'Screen Frame',
              subtitle: 'Retro device bezel effect',
              value: settings.screenFrame,
              enabled: isRetro,
              onChanged: (v) =>
                  ref.read(themeProvider.notifier).setScreenFrame(v),
              isRetro: isRetro,
            ),
            _ToggleTile(
              icon: Icons.blur_linear,
              title: 'CRT Scanlines',
              subtitle: 'Retro screen line overlay',
              value: settings.crtScanlines,
              enabled: isRetro,
              onChanged: (v) =>
                  ref.read(themeProvider.notifier).setCrtScanlines(v),
              isRetro: isRetro,
            ),
            _ToggleTile(
              icon: Icons.lightbulb,
              title: 'Animated LEDs',
              subtitle: 'Pulsing LED indicators',
              value: settings.animatedLeds,
              enabled: isRetro,
              onChanged: (v) =>
                  ref.read(themeProvider.notifier).setAnimatedLeds(v),
              isRetro: isRetro,
            ),
            _ToggleTile(
              icon: Icons.auto_awesome,
              title: 'Entry Animations',
              subtitle: 'Animated card reveals',
              value: settings.entryAnimation,
              enabled: isRetro,
              onChanged: (v) =>
                  ref.read(themeProvider.notifier).setEntryAnimation(v),
              isRetro: isRetro,
            ),

            const SizedBox(height: 32),

            // Audio Section
            _buildSectionHeader(context, 'Audio', isRetro),
            const SizedBox(height: 16),
            _ToggleTile(
              icon: Icons.volume_up,
              title: 'Sound Effects',
              subtitle: 'Scan beeps and chimes',
              value: settings.soundEffects,
              enabled: isRetro,
              onChanged: (v) {
                ref.read(themeProvider.notifier).setSoundEffects(v);
                if (v) {
                  // Play a sample sound when enabling
                  ref.read(soundServiceProvider).play(RetroSound.select);
                }
              },
              isRetro: isRetro,
            ),

            const SizedBox(height: 32),

            // Startup Section
            _buildSectionHeader(context, 'Startup', isRetro),
            const SizedBox(height: 16),
            _ToggleTile(
              icon: Icons.play_circle_outline,
              title: 'Boot Animation',
              subtitle: 'Retro startup sequence',
              value: settings.bootAnimation,
              enabled: isRetro,
              onChanged: (v) =>
                  ref.read(themeProvider.notifier).setBootAnimation(v),
              isRetro: isRetro,
            ),

            const SizedBox(height: 32),

            // Categories Section
            _buildSectionHeader(context, 'Categories', isRetro),
            const SizedBox(height: 16),
            _CategoryManager(isRetro: isRetro),

            const SizedBox(height: 32),

            // Data Section
            _buildSectionHeader(context, 'Data', isRetro),
            const SizedBox(height: 16),
            _ExportButton(isRetro: isRetro),

            const SizedBox(height: 32),

            // About Section
            _buildSectionHeader(context, 'About', isRetro),
            const SizedBox(height: 16),
            _buildAboutCard(context, isRetro),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    bool isRetro,
  ) {
    return Row(
      children: [
        if (isRetro) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppThemes.retroBlue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppThemes.retroBlue.withValues(alpha: 0.6),
                  blurRadius: 6,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
        ],
        Text(
          isRetro ? title.toUpperCase() : title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            letterSpacing: isRetro ? 3 : 0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildAboutCard(BuildContext context, bool isRetro) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: isRetro
            ? Border.all(
                color: AppThemes.retroBlue.withValues(alpha: 0.5),
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
                Icons.radar,
                color: isRetro
                    ? AppThemes.retroLightBlue
                    : Colors.blueAccent,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                isRetro ? 'DEXICON' : 'Dexicon',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  letterSpacing: isRetro ? 2 : 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isRetro
                ? 'Advanced visual identification and logging system. Scan, identify, and catalog anything you spot.'
                : 'Scan and identify anything using AI-powered image recognition.',
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
  final bool isRetro;
  final AppSettings settings;

  const _ThemeToggleCard({required this.isRetro, required this.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: _ThemeCard(
            title: 'Classic',
            subtitle: 'Original dark theme',
            isSelected: !isRetro,
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
            title: 'Retro',
            subtitle: 'Scanner mode',
            isSelected: isRetro,
            previewColors: [
              AppThemes.retroBlack,
              AppThemes.retroRed,
              AppThemes.retroBlue,
            ],
            onTap: () =>
                ref.read(themeProvider.notifier).setTheme(AppThemeMode.retro),
            isRetroStyle: true,
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
  final bool isRetroStyle;

  const _ThemeCard({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.previewColors,
    required this.onTap,
    this.isRetroStyle = false,
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
                ? (isRetroStyle ? AppThemes.retroRed : Colors.blueAccent)
                : Colors.white24,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color:
                        (isRetroStyle
                                ? AppThemes.retroRed
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
                    color: isRetroStyle
                        ? AppThemes.retroRed
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
  final RetroFont currentFont;

  const _FontSelector({required this.currentFont});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: RetroFont.values.map((font) {
        final isSelected = currentFont == font;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _FontTile(
            font: font,
            isSelected: isSelected,
            onTap: () {
              ref.read(themeProvider.notifier).setFont(font);
              if (ref.read(themeProvider).soundEffects) {
                ref.read(soundServiceProvider).play(RetroSound.select);
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
  final RetroFont font;
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
      case RetroFont.pressStart:
        return GoogleFonts.pressStart2p(
          textStyle: baseStyle.copyWith(fontSize: 10),
        );
      case RetroFont.vt323:
        return GoogleFonts.vt323(textStyle: baseStyle.copyWith(fontSize: 20));
      case RetroFont.orbitron:
        return GoogleFonts.orbitron(textStyle: baseStyle);
      case RetroFont.audiowide:
        return GoogleFonts.audiowide(textStyle: baseStyle);
      case RetroFont.system:
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
              ? AppThemes.retroCard
              : AppThemes.retroDarkGray.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppThemes.retroRed
                : AppThemes.retroBlue.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppThemes.retroRed.withValues(alpha: 0.3),
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
                      color: AppThemes.retroLightBlue.withValues(alpha: 0.7),
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
                color: AppThemes.retroBlack,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppThemes.retroBlue.withValues(alpha: 0.3),
                ),
              ),
              child: Text('DEXICON', style: _getFontStyle()),
            ),
            const SizedBox(width: 12),
            if (isSelected)
              Icon(Icons.check_circle, color: AppThemes.retroGreen, size: 24)
            else
              Icon(
                Icons.radio_button_unchecked,
                color: AppThemes.retroBlue.withValues(alpha: 0.5),
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
  final bool isRetro;

  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.isRetro,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveEnabled = enabled && isRetro;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: effectiveEnabled ? 1.0 : 0.5,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(12),
            border: isRetro
                ? Border.all(
                    color: value && effectiveEnabled
                        ? AppThemes.retroGreen.withValues(alpha: 0.5)
                        : AppThemes.retroBlue.withValues(alpha: 0.3),
                    width: 1,
                  )
                : null,
          ),
          child: ListTile(
            leading: Icon(
              icon,
              color: effectiveEnabled && value
                  ? (isRetro ? AppThemes.retroGreen : Colors.blueAccent)
                  : (isRetro
                        ? AppThemes.retroBlue.withValues(alpha: 0.5)
                        : Colors.grey),
            ),
            title: Text(
              isRetro ? title.toUpperCase() : title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: isRetro ? 0.5 : 0,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
                letterSpacing: isRetro ? 0.3 : 0,
              ),
            ),
            trailing: Switch(
              value: value,
              onChanged: effectiveEnabled ? onChanged : null,
              activeColor: AppThemes.retroGreen,
              activeTrackColor: AppThemes.retroGreen.withValues(alpha: 0.5),
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
  final bool isRetro;

  const _CategoryManager({required this.isRetro});

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
                    ? (isRetro
                          ? AppThemes.retroCard
                          : const Color(0xFF1E2A5A))
                    : (isRetro
                          ? AppThemes.retroDarkGray.withValues(alpha: 0.7)
                          : const Color(0xFF1E1E1E)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive
                      ? (isRetro
                            ? AppThemes.retroRed
                            : Colors.blueAccent)
                      : (isRetro
                            ? AppThemes.retroBlue.withValues(alpha: 0.3)
                            : Colors.white12),
                  width: isActive ? 2 : 1,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: (isRetro
                                  ? AppThemes.retroRed
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
                  isRetro ? cat.name.toUpperCase() : cat.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.white : Colors.white70,
                    letterSpacing: isRetro ? 1 : 0,
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
                          color: isRetro
                              ? AppThemes.retroRed
                              : Colors.blueAccent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isRetro ? 'ACTIVE' : 'Active',
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
                        color: isRetro
                            ? AppThemes.retroLightBlue
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
                            ? (isRetro
                                  ? AppThemes.retroRed.withValues(alpha: 0.8)
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
                color: isRetro
                    ? AppThemes.retroBlue.withValues(alpha: 0.5)
                    : Colors.blueAccent.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_circle_outline,
                  color: isRetro
                      ? AppThemes.retroLightBlue
                      : Colors.blueAccent,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  isRetro ? 'ADD NEW CATEGORY' : 'Add New Category',
                  style: TextStyle(
                    color: isRetro
                        ? AppThemes.retroLightBlue
                        : Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                    letterSpacing: isRetro ? 1 : 0,
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
            isRetro ? 'RESET TO DEFAULTS' : 'Reset to Defaults',
            style: TextStyle(letterSpacing: isRetro ? 0.5 : 0, fontSize: 12),
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
    final isNew = editIndex == null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final emojiCtrl = TextEditingController(text: existing?.emoji ?? '');
    final contextCtrl =
        TextEditingController(text: existing?.geminiContext ?? '');
    final tagsCtrl = TextEditingController(
      text: existing?.validTags.join(', ') ?? '',
    );

    bool isGenerating = false;
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          // Fills the tags (and emoji/context if left blank) from the
          // category name via Gemini.
          Future<GeneratedCategoryProfile?> generateProfile() async {
            final name = nameCtrl.text.trim();
            setState(() {
              isGenerating = true;
              errorText = null;
            });
            try {
              final profile = await ref
                  .read(geminiServiceProvider)
                  .generateCategoryProfile(name);
              if (!ctx.mounted) return null;
              setState(() => isGenerating = false);
              return profile;
            } catch (e) {
              if (!ctx.mounted) return null;
              setState(() {
                isGenerating = false;
                errorText = 'Tag generation failed: $e';
              });
              return null;
            }
          }

          Future<void> regenerateTagsField() async {
            if (nameCtrl.text.trim().isEmpty) {
              setState(() => errorText = 'Enter a name first.');
              return;
            }
            final profile = await generateProfile();
            if (profile == null) return;
            setState(() {
              tagsCtrl.text = profile.tags.join(', ');
              if (emojiCtrl.text.trim().isEmpty) emojiCtrl.text = profile.emoji;
              if (contextCtrl.text.trim().isEmpty) {
                contextCtrl.text = profile.geminiContext;
              }
            });
          }

          Future<void> save() async {
            final name = nameCtrl.text.trim();
            if (name.isEmpty) {
              setState(() => errorText = 'Name is required.');
              return;
            }

            var emoji = emojiCtrl.text.trim();
            var geminiContext = contextCtrl.text.trim();
            var tags = tagsCtrl.text
                .split(',')
                .map((t) => t.trim())
                .where((t) => t.isNotEmpty)
                .toList();

            // No tags typed (always the case for new categories) — generate
            // them from the name, along with an emoji/context if blank.
            if (tags.isEmpty) {
              final profile = await generateProfile();
              if (profile == null) return;
              tags = profile.tags;
              if (emoji.isEmpty) emoji = profile.emoji;
              if (geminiContext.isEmpty) geminiContext = profile.geminiContext;
            }
            if (emoji.isEmpty) emoji = '📷';

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

            if (ctx.mounted) Navigator.pop(ctx);
          }

          return AlertDialog(
            title: Text(
              isNew ? 'Add Category' : 'Edit Category',
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
                      labelText: 'Gemini Context (optional)',
                      hintText: 'aircraft or airplane',
                      helperText: 'How to describe this to Gemini AI',
                      helperStyle:
                          TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  if (isNew)
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          size: 16,
                          color: AppThemes.retroLightBlue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tags (and emoji, if blank) are generated '
                            'automatically — you can edit them later.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    )
                  else ...[
                    TextField(
                      controller: tagsCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Tags',
                        hintText: 'Fighter, Bomber, Transport/Cargo',
                        helperText:
                            'Comma-separated list of classification tags',
                        helperStyle:
                            TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: isGenerating ? null : regenerateTagsField,
                        icon: const Icon(Icons.auto_awesome, size: 14),
                        label: const Text(
                          'Regenerate with AI',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorText!,
                      style: const TextStyle(
                        color: AppThemes.retroRed,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isGenerating ? null : save,
                child: isGenerating
                    ? const SizedBox(
                        width: 60,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ],
                        ),
                      )
                    : Text(isNew ? 'Add' : 'Save'),
              ),
            ],
          );
        },
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
              backgroundColor: AppThemes.retroRed,
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
  final bool isRetro;

  const _ExportButton({required this.isRetro});

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
    final isRetro = widget.isRetro;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: isRetro
            ? Border.all(
                color: AppThemes.retroBlue.withValues(alpha: 0.3),
                width: 1,
              )
            : null,
      ),
      child: ListTile(
        leading: Icon(
          Icons.download,
          color: isRetro ? AppThemes.retroLightBlue : Colors.blueAccent,
        ),
        title: Text(
          isRetro ? 'EXPORT BACKUP' : 'Export Backup',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: isRetro ? 0.5 : 0,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          'Save all sightings as JSON',
          style: TextStyle(
            color: Colors.white60,
            fontSize: 12,
            letterSpacing: isRetro ? 0.3 : 0,
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
                color: isRetro ? AppThemes.retroBlue : Colors.blueAccent,
              ),
        onTap: _exporting ? null : _export,
      ),
    );
  }
}
