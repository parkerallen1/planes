import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/image_store.dart';
import '../services/storage_service.dart';
import '../services/sound_service.dart';
import '../models/plane.dart';
import '../providers/theme_provider.dart';
import '../providers/category_provider.dart';
import '../theme/app_themes.dart';
import '../widgets/dexicon_logo.dart';

import 'plane_detail_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  String? selectedTag;
  String? _lastCategoryId;
  late AnimationController _ledController;
  late Animation<double> _ledAnimation;

  @override
  void initState() {
    super.initState();
    _ledController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _ledAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ledController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ledController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storageService = ref.watch(storageServiceProvider);
    final settings = ref.watch(themeProvider);
    final isRetro = settings.isRetro;
    final categoryState = ref.watch(categoryProvider);
    final activeCategory = categoryState.activeCategory;

    // Reset tag filter when category changes
    if (_lastCategoryId != activeCategory.id) {
      _lastCategoryId = activeCategory.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => selectedTag = null);
      });
    }

    final allStoredPlanes = storageService.getAllPlanes();
    // Filter by active category
    final allPlanes = allStoredPlanes
        .where((p) => p.categoryId == activeCategory.id)
        .toList();
    final allTags = <String>{};
    for (final p in allPlanes) {
      allTags.addAll(p.tags);
    }

    final filteredPlanes = selectedTag == null
        ? allPlanes
        : allPlanes.where((p) => p.tags.contains(selectedTag)).toList();

    final identifyingCount = allPlanes
        .where((p) => p.status == PlaneStatus.identifying)
        .length;
    final confirmedCount = allPlanes
        .where((p) => p.status == PlaneStatus.finalized)
        .length;

    Widget content = Scaffold(
      // No AppBar for Retro mode - we use custom header
      appBar: isRetro
          ? null
          : AppBar(
              title: Text(
                '${activeCategory.emoji} My ${activeCategory.name}',
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => Navigator.pushNamed(context, '/settings'),
                ),
              ],
            ),
      floatingActionButton: _buildScanFab(context, ref, isRetro, settings),
      body: Stack(
        children: [
          Column(
            children: [
              // Classic Mode Category selector
              if (!isRetro) _buildClassicCategoryBar(context, ref),

              // Retro header & category bar
              if (isRetro) ...[
                _RetroHeader(
                  scannedCount: allPlanes.length,
                  identifyingCount: identifyingCount,
                  confirmedCount: confirmedCount,
                  animatedLeds: settings.animatedLeds,
                  ledAnimation: _ledAnimation,
                  onSettingsTap: () =>
                      Navigator.pushNamed(context, '/settings'),
                ),
                _buildRetroCategoryBar(context, ref),
              ],

              // Tag Filter
              if (isRetro) const SizedBox(height: 4),
              if (allTags.isNotEmpty)
                SizedBox(
                  height: 60,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    children: [
                      _buildFilterChip('All', selectedTag == null, () {
                        setState(() => selectedTag = null);
                        _playSelectSound();
                      }, isRetro),
                      const SizedBox(width: 8),
                      ...allTags.map(
                        (tag) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildFilterChip(tag, selectedTag == tag, () {
                            setState(
                              () =>
                                  selectedTag = selectedTag == tag ? null : tag,
                            );
                            _playSelectSound();
                          }, isRetro),
                        ),
                      ),
                    ],
                  ),
                ),

              // Plane List
              Expanded(
                child: filteredPlanes.isEmpty
                    ? _buildEmptyState(isRetro)
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.75,
                            ),
                        itemCount: filteredPlanes.length,
                        itemBuilder: (context, index) {
                          final plane = filteredPlanes[index];
                          final planeNumber = filteredPlanes.length - index;
                          return _buildPlaneCard(plane, planeNumber, index, settings);
                        },
                      ),
              ),
            ],
          ),

          // CRT Scanlines overlay
          if (isRetro && settings.crtScanlines)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: CrtScanlinesPainter()),
              ),
            ),
        ],
      ),
    );

    // Wrap with screen frame if enabled
    if (isRetro && settings.screenFrame) {
      content = _RetroFrame(child: content);
    }

    return content;
  }

  Widget _buildClassicCategoryBar(BuildContext context, WidgetRef ref) {
    final categoryState = ref.watch(categoryProvider);
    return Container(
      height: 50,
      margin: const EdgeInsets.only(top: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categoryState.categories.length,
        itemBuilder: (context, index) {
          final cat = categoryState.categories[index];
          final isSelected = index == categoryState.activeIndex;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('${cat.emoji} ${cat.name}'),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  ref.read(categoryProvider.notifier).setActiveIndex(index);
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildRetroCategoryBar(BuildContext context, WidgetRef ref) {
    final categoryState = ref.watch(categoryProvider);
    final settings = ref.watch(themeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cyber decoration label row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SYSTEM DATABANK CHANNELS',
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppThemes.retroLightBlue.withValues(alpha: 0.6),
                  letterSpacing: 1.5,
                ),
              ),
              Row(
                children: List.generate(
                  4,
                  (i) => Container(
                    width: 6,
                    height: 2,
                    margin: const EdgeInsets.only(left: 3),
                    color: AppThemes.retroLightBlue.withValues(alpha: 0.3 + (i * 0.15)),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 54,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: categoryState.categories.length,
            itemBuilder: (context, index) {
              final cat = categoryState.categories[index];
              final isSelected = index == categoryState.activeIndex;
              return GestureDetector(
                onTap: () {
                  ref.read(categoryProvider.notifier).setActiveIndex(index);
                  if (settings.soundEffects) {
                    ref.read(soundServiceProvider).play(RetroSound.select);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.only(right: 8, top: 2, bottom: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppThemes.retroBlue.withValues(alpha: 0.15)
                        : AppThemes.retroBlack,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected
                          ? AppThemes.retroLightBlue
                          : AppThemes.retroBlue.withValues(alpha: 0.3),
                      width: isSelected ? 1.8 : 1.2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppThemes.retroLightBlue.withValues(alpha: 0.25),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Blinking neon LED indicator dot for selected channel
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? AppThemes.retroLightBlue : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? Colors.transparent : Colors.white24,
                            width: 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppThemes.retroLightBlue.withValues(alpha: 0.8),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Opacity(
                        opacity: isSelected ? 1.0 : 0.6,
                        child: Text(
                          cat.emoji,
                          style: const TextStyle(
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CH.0${index + 1}',
                            style: TextStyle(
                              fontFamily: 'Courier',
                              fontWeight: FontWeight.bold,
                              fontSize: 8,
                              color: isSelected
                                  ? AppThemes.retroLightBlue.withValues(alpha: 0.8)
                                  : Colors.white24,
                            ),
                          ),
                          Text(
                            cat.name.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'Courier',
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 1.2,
                              color: isSelected ? Colors.white : Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget? _buildScanFab(BuildContext context, WidgetRef ref, bool isRetro, AppSettings settings) {
    if (isRetro) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16, right: 8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppThemes.retroRed.withValues(alpha: 0.6),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: FloatingActionButton.large(
          onPressed: () async {
            if (settings.soundEffects) {
              ref.read(soundServiceProvider).play(RetroSound.select);
            }
            await Navigator.pushNamed(context, '/add');
            setState(() {});
          },
          backgroundColor: AppThemes.retroRed,
          foregroundColor: Colors.white,
          shape: const CircleBorder(
            side: BorderSide(color: Colors.white70, width: 3),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.radar, size: 28),
              SizedBox(height: 2),
              Text(
                'SCAN',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontFamily: 'Courier',
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return FloatingActionButton(
        onPressed: () async {
          await Navigator.pushNamed(context, '/add');
          setState(() {});
        },
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      );
    }
  }

  void _playSelectSound() {
    final settings = ref.read(themeProvider);
    if (settings.isRetro && settings.soundEffects) {
      ref.read(soundServiceProvider).play(RetroSound.select);
    }
  }

  Widget _buildFilterChip(
    String label,
    bool selected,
    VoidCallback onTap,
    bool isRetro,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? (isRetro ? AppThemes.retroRed : Colors.blueAccent)
              : (isRetro ? AppThemes.retroDarkGray : Colors.grey[800]),
          borderRadius: BorderRadius.circular(20),
          border: isRetro
              ? Border.all(
                  color: selected
                      ? Colors.white30
                      : AppThemes.retroBlue.withValues(alpha: 0.5),
                  width: 2,
                )
              : null,
          boxShadow: selected && isRetro
              ? [
                  BoxShadow(
                    color: AppThemes.retroRed.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Text(
          isRetro ? label.toUpperCase() : label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            letterSpacing: isRetro ? 1 : 0,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isRetro) {
    final categoryState = ref.read(categoryProvider);
    final activeCategory = categoryState.activeCategory;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            activeCategory.emoji,
            style: TextStyle(
              fontSize: 72,
              color: isRetro
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isRetro
                ? 'NO ${activeCategory.name.toUpperCase()} DETECTED'
                : 'No ${activeCategory.name.toLowerCase()} found. Add one!',
            style: TextStyle(
              color: Colors.white54,
              fontSize: isRetro ? 16 : 14,
              letterSpacing: isRetro ? 2 : 0,
              fontWeight: isRetro ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isRetro) ...[
            const SizedBox(height: 8),
            const Text(
              'Tap + on the cog wheel to begin scanning',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaneCard(Plane plane, int planeNumber, int gridIndex, AppSettings settings) {
    final isIdentifying = plane.status == PlaneStatus.identifying;
    final isRetro = settings.isRetro;

    Widget card = Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: isIdentifying
            ? BorderSide(
                color: isRetro ? AppThemes.retroYellow : Colors.yellow,
                width: 3,
              )
            : (isRetro
                  ? BorderSide(
                      color: AppThemes.retroBlue.withValues(alpha: 0.5),
                      width: 2,
                    )
                  : BorderSide.none),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () async {
          if (settings.soundEffects) {
            ref.read(soundServiceProvider).play(RetroSound.select);
          }
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlaneDetailScreen(plane: plane),
            ),
          );
          setState(() {});
        },
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image with overlay
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        plane.imagePath.startsWith('assets/')
                            ? Image.asset(
                                plane.imagePath,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Center(child: Icon(Icons.broken_image)),
                              )
                            : Image.file(
                                File(ImageStore.resolve(plane.imagePath)),
                                width: double.infinity,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Center(child: Icon(Icons.broken_image)),
                              ),
                        if (isRetro) ...[
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  AppThemes.retroBlack.withValues(alpha: 0.8),
                                ],
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: CustomPaint(
                              painter: ViewfinderBracketsPainter(
                                color: isIdentifying
                                    ? AppThemes.retroYellow.withValues(alpha: 0.8)
                                    : AppThemes.retroBlue.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                          if (isIdentifying)
                            const Positioned.fill(child: _ScanningOverlay()),
                        ],
                      ],
                    ),
                  ),
                ),

                // Info section
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  decoration: isRetro
                      ? BoxDecoration(
                          color: AppThemes.retroCard,
                          border: Border(
                            top: BorderSide(
                              color: AppThemes.retroBlue.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                        )
                      : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isRetro)
                        Text(
                          '#${planeNumber.toString().padLeft(3, '0')}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppThemes.retroBlue,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      Text(
                        isIdentifying
                            ? (isRetro ? 'SCANNING...' : 'Identifying...')
                            : (isRetro
                                  ? plane.identification.toUpperCase()
                                  : plane.identification),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(letterSpacing: isRetro ? 0.5 : 0),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (!isIdentifying && plane.tags.isNotEmpty)
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: plane.tags
                              .take(2)
                              .map((tag) => _buildTag(tag, isRetro))
                              .toList(),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // Scanning indicator for Retro mode
            if (isIdentifying && isRetro)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppThemes.retroYellow.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.black87),
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'SCAN',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    // Apply entry animation if enabled
    if (isRetro && settings.entryAnimation) {
      card = _AnimatedEntry(index: gridIndex, child: card);
    }

    return card;
  }

  Widget _buildTag(String tag, bool isRetro) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isRetro ? AppThemes.retroDarkGray : Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
        border: isRetro
            ? Border.all(color: AppThemes.retroBlue.withValues(alpha: 0.5))
            : null,
      ),
      child: Text(
        isRetro ? tag.toUpperCase() : tag,
        style: TextStyle(
          fontSize: 10,
          color: isRetro ? AppThemes.retroLightBlue : Colors.black87,
          letterSpacing: isRetro ? 0.5 : 0,
        ),
      ),
    );
  }

}

/// Custom Retro header widget with curved diagonal design
class _RetroHeader extends StatelessWidget {
  final int scannedCount;
  final int identifyingCount;
  final int confirmedCount;
  final bool animatedLeds;
  final Animation<double> ledAnimation;
  final VoidCallback onSettingsTap;

  const _RetroHeader({
    required this.scannedCount,
    required this.identifyingCount,
    required this.confirmedCount,
    required this.animatedLeds,
    required this.ledAnimation,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      children: [
        // Solid black status bar cap
        Container(
          height: topPadding,
          color: Colors.black,
        ),
        SizedBox(
          height: 110,
          child: Stack(
            children: [
              // Background with custom shape
              ClipPath(
                clipper: _RetroHeaderClipper(),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppThemes.retroDarkRed,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),

              // Border line along the curved edge
              CustomPaint(
                painter: _RetroHeaderBorderPainter(),
                size: Size(screenWidth, 110),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Glassy Blue Camera/Scanner Lens
                    _buildMainLed(),
                    const SizedBox(width: 14),

                    // LCD Count Display & Status Indicators
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          // LCD Counter screen
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F140C),
                              border: Border.all(
                                color: AppThemes.retroBlue.withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: AppThemes.retroBlue.withValues(alpha: 0.15),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Text(
                              'INDEXED: ${scannedCount.toString().padLeft(3, '0')}',
                              style: TextStyle(
                                color: AppThemes.retroLightBlue,
                                fontFamily: 'Courier',
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 1.5,
                                shadows: [
                                  Shadow(
                                    color: AppThemes.retroLightBlue.withValues(alpha: 0.8),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Status Indicators row
                          Row(
                            children: [
                              _buildHorizontalLed(
                                color: AppThemes.retroRed,
                                isActive: identifyingCount > 0,
                                label: 'SCAN',
                              ),
                              const SizedBox(width: 12),
                              _buildHorizontalLed(
                                color: AppThemes.retroYellow,
                                isActive: true,
                                label: 'STBY',
                              ),
                              const SizedBox(width: 12),
                              _buildHorizontalLed(
                                color: AppThemes.retroGreen,
                                isActive: confirmedCount > 0,
                                label: 'SYNC',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Right side: Logo and settings
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Transform.translate(
                              offset: const Offset(0, -6),
                              child: const DexiconLogo(fontSize: 22),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: onSettingsTap,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppThemes.retroBlack.withValues(alpha: 0.8),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppThemes.retroBlue.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.settings,
                                  size: 20,
                                  color: AppThemes.retroLightBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainLed() {
    return animatedLeds
        ? AnimatedBuilder(
            animation: ledAnimation,
            builder: (context, child) =>
                _buildMainLedContent(ledAnimation.value),
          )
        : _buildMainLedContent(1.0);
  }

  Widget _buildMainLedContent(double glowIntensity) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppThemes.retroBlack,
        border: Border.all(
          color: Colors.white70,
          width: 4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 4,
            offset: const Offset(1.5, 1.5),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              AppThemes.retroLightBlue,
              AppThemes.retroBlue,
              AppThemes.retroBlue.withValues(alpha: 0.8),
            ],
            stops: const [0.0, 0.45, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: AppThemes.retroLightBlue.withValues(
                alpha: glowIntensity * 0.75,
              ),
              blurRadius: 12 * glowIntensity,
              spreadRadius: 2 * glowIntensity,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalLed({
    required Color color,
    required bool isActive,
    required String label,
  }) {
    Widget led = animatedLeds && isActive
        ? AnimatedBuilder(
            animation: ledAnimation,
            builder: (context, child) =>
                _buildSmallLedContent(color, isActive, ledAnimation.value),
          )
        : _buildSmallLedContent(color, isActive, 1.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        led,
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: isActive ? Colors.white : Colors.white30,
            fontWeight: FontWeight.bold,
            fontFamily: 'Courier',
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSmallLedContent(
    Color color,
    bool isActive,
    double glowIntensity,
  ) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? color : color.withValues(alpha: 0.2),
        border: Border.all(color: Colors.black45, width: 1.5),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: color.withValues(alpha: glowIntensity * 0.8),
                  blurRadius: 5 * glowIntensity,
                  spreadRadius: 0.5,
                ),
              ]
            : null,
      ),
    );
  }
}

/// Custom clipper for the Retro header diagonal shape
class _RetroHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    // Start from top-left
    path.moveTo(0, 0);

    // Top edge
    path.lineTo(size.width, 0);

    // Right edge - go down to the logo level
    path.lineTo(size.width, size.height - 40);

    // Diagonal transition going down-left
    path.lineTo(size.width * 0.40, size.height - 40);
    path.lineTo(size.width * 0.30, size.height - 12);

    // Bottom left horizontal (LED/LCD section is lower)
    path.lineTo(0, size.height - 12);

    // Close back to start
    path.lineTo(0, 0);

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Custom painter for the diagonal border line
class _RetroHeaderBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppThemes.retroBlack
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final path = Path();

    // Draw the bottom edge line
    path.moveTo(0, size.height - 12);
    path.lineTo(size.width * 0.30, size.height - 12);
    path.lineTo(size.width * 0.40, size.height - 40);
    path.lineTo(size.width, size.height - 40);

    canvas.drawPath(path, paint);

    // Inner highlight line
    final glowPaint = Paint()
      ..color = AppThemes.retroBlue.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final glowPath = Path();
    glowPath.moveTo(0, size.height - 14);
    glowPath.lineTo(size.width * 0.29, size.height - 14);
    glowPath.lineTo(size.width * 0.39, size.height - 42);
    glowPath.lineTo(size.width, size.height - 42);

    canvas.drawPath(glowPath, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Animated entry widget for staggered card appearance
class _AnimatedEntry extends StatefulWidget {
  final int index;
  final Widget child;

  const _AnimatedEntry({required this.index, required this.child});

  @override
  State<_AnimatedEntry> createState() => _AnimatedEntryState();
}

class _AnimatedEntryState extends State<_AnimatedEntry>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeIn = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _slideIn = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Stagger the animation based on index
    Future.delayed(Duration(milliseconds: widget.index * 60), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeIn,
      child: SlideTransition(position: _slideIn, child: widget.child),
    );
  }
}

/// High-tech cyber grid scanline custom painter
class CrtScanlinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Cyber-grid pattern: very subtle horizontal and vertical gridlines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 0.5;

    // Horizontal lines
    for (double y = 0; y < size.height; y += 16) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    // Vertical lines
    for (double x = 0; x < size.width; x += 16) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // 2. Subtle horizontal scanline strips
    final scanlinePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.04)
      ..strokeWidth = 1.0;

    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanlinePaint);
    }

    // 3. Curved CRT glass vignette/gradient shadow
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final vignettePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.15,
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.22),
        ],
        stops: const [0.65, 1.0],
      ).createShader(rect);

    canvas.drawRect(rect, vignettePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Viewfinder corner brackets custom painter for grid card image overlays
class ViewfinderBracketsPainter extends CustomPainter {
  final Color color;
  ViewfinderBracketsPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    const length = 12.0;
    const margin = 8.0;

    // Top Left
    canvas.drawLine(
      const Offset(margin, margin),
      const Offset(margin + length, margin),
      paint,
    );
    canvas.drawLine(
      const Offset(margin, margin),
      const Offset(margin, margin + length),
      paint,
    );

    // Top Right
    canvas.drawLine(
      Offset(size.width - margin, margin),
      Offset(size.width - margin - length, margin),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - margin, margin),
      Offset(size.width - margin, margin + length),
      paint,
    );

    // Bottom Left
    canvas.drawLine(
      Offset(margin, size.height - margin),
      Offset(margin + length, size.height - margin),
      paint,
    );
    canvas.drawLine(
      Offset(margin, size.height - margin),
      Offset(margin, size.height - margin - length),
      paint,
    );

    // Bottom Right
    canvas.drawLine(
      Offset(size.width - margin, size.height - margin),
      Offset(size.width - margin - length, size.height - margin),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - margin, size.height - margin),
      Offset(size.width - margin, size.height - margin - length),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant ViewfinderBracketsPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Sliding laser scanner animation overlay for currently identifying cards
class _ScanningOverlay extends StatefulWidget {
  const _ScanningOverlay();

  @override
  State<_ScanningOverlay> createState() => _ScanningOverlayState();
}

class _ScanningOverlayState extends State<_ScanningOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        return AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Stack(
              children: [
                // Glowing laser scan line
                Positioned(
                  top: height * _animation.value,
                  left: 4,
                  right: 4,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppThemes.retroYellow,
                      boxShadow: [
                        BoxShadow(
                          color: AppThemes.retroYellow.withValues(alpha: 0.8),
                          blurRadius: 8,
                          spreadRadius: 1.5,
                        ),
                      ],
                    ),
                  ),
                ),
                // Scanner window tint
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppThemes.retroYellow.withValues(alpha: 0.03),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Retro device frame wrapper that respects SafeArea boundaries
class _RetroFrame extends StatelessWidget {
  final Widget child;

  const _RetroFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: AppThemes.retroBlack,
            border: Border.all(color: AppThemes.retroDarkRed, width: 4),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              // Main screen viewport
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppThemes.retroBlue.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: child,
                  ),
                ),
              ),
              // Bottom hardware bar with bezel LEDs
              Container(
                height: 16,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
                  gradient: LinearGradient(
                    colors: [
                      AppThemes.retroDarkRed.withValues(alpha: 0.8),
                      AppThemes.retroDarkRed,
                      AppThemes.retroDarkRed.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildBezelLed(Colors.white38),
                    const SizedBox(width: 12),
                    _buildBezelLed(Colors.white38),
                    const SizedBox(width: 12),
                    _buildBezelLed(Colors.white38),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBezelLed(Color color) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
