import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';
import '../services/sound_service.dart';
import '../models/plane.dart';
import '../providers/theme_provider.dart';
import '../theme/app_themes.dart';

import 'plane_detail_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  String? selectedTag;
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
    final isPokedex = settings.isPokedex;

    final allPlanes = storageService.getAllPlanes();
    final allTags = storageService.getAllTags();

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
      // No AppBar for Pokedex mode - we use custom header
      appBar: isPokedex
          ? null
          : AppBar(
              title: const Text('My Planes'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => Navigator.pushNamed(context, '/settings'),
                ),
              ],
            ),
      body: Stack(
        children: [
          Column(
            children: [
              // Custom Pokedex header
              if (isPokedex)
                _PokedexHeader(
                  scannedCount: allPlanes.length,
                  identifyingCount: identifyingCount,
                  confirmedCount: confirmedCount,
                  animatedLeds: settings.animatedLeds,
                  ledAnimation: _ledAnimation,
                  onSettingsTap: () =>
                      Navigator.pushNamed(context, '/settings'),
                ),

              // Tag Filter
              if (isPokedex) const SizedBox(height: 4),
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
                      }, isPokedex),
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
                          }, isPokedex),
                        ),
                      ),
                    ],
                  ),
                ),

              // Plane List
              Expanded(
                child: filteredPlanes.isEmpty
                    ? _buildEmptyState(isPokedex)
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
                          return _buildPlaneCard(plane, index, settings);
                        },
                      ),
              ),
            ],
          ),

          // CRT Scanlines overlay
          if (isPokedex && settings.crtScanlines)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: CrtScanlinesPainter()),
              ),
            ),
        ],
      ),
      floatingActionButton: _buildFAB(isPokedex),
    );

    // Wrap with screen frame if enabled
    if (isPokedex && settings.screenFrame) {
      content = _PokedexFrame(child: content);
    }

    return content;
  }

  void _playSelectSound() {
    final settings = ref.read(themeProvider);
    if (settings.isPokedex && settings.soundEffects) {
      ref.read(soundServiceProvider).play(PokedexSound.select);
    }
  }

  Widget _buildFilterChip(
    String label,
    bool selected,
    VoidCallback onTap,
    bool isPokedex,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? (isPokedex ? AppThemes.pokedexRed : Colors.blueAccent)
              : (isPokedex ? AppThemes.pokedexDarkGray : Colors.grey[800]),
          borderRadius: BorderRadius.circular(20),
          border: isPokedex
              ? Border.all(
                  color: selected
                      ? Colors.white30
                      : AppThemes.pokedexBlue.withValues(alpha: 0.5),
                  width: 2,
                )
              : null,
          boxShadow: selected && isPokedex
              ? [
                  BoxShadow(
                    color: AppThemes.pokedexRed.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Text(
          isPokedex ? label.toUpperCase() : label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            letterSpacing: isPokedex ? 1 : 0,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isPokedex) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isPokedex ? Icons.radar : Icons.airplanemode_active,
            size: 80,
            color: isPokedex
                ? AppThemes.pokedexBlue.withValues(alpha: 0.5)
                : Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            isPokedex ? 'NO AIRCRAFT DETECTED' : 'No planes found. Add one!',
            style: TextStyle(
              color: Colors.white54,
              fontSize: isPokedex ? 16 : 14,
              letterSpacing: isPokedex ? 2 : 0,
              fontWeight: isPokedex ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isPokedex) ...[
            const SizedBox(height: 8),
            const Text(
              'Tap + to begin scanning',
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

  Widget _buildPlaneCard(Plane plane, int index, PokedexSettings settings) {
    final isIdentifying = plane.status == PlaneStatus.identifying;
    final isPokedex = settings.isPokedex;

    Widget card = Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: isIdentifying
            ? BorderSide(
                color: isPokedex ? AppThemes.pokedexYellow : Colors.yellow,
                width: 3,
              )
            : (isPokedex
                  ? BorderSide(
                      color: AppThemes.pokedexBlue.withValues(alpha: 0.5),
                      width: 2,
                    )
                  : BorderSide.none),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () async {
          if (settings.soundEffects) {
            ref.read(soundServiceProvider).play(PokedexSound.select);
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
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        File(plane.imagePath),
                        width: double.infinity,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(child: Icon(Icons.broken_image)),
                      ),
                      if (isPokedex)
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                AppThemes.pokedexBlack.withValues(alpha: 0.8),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Info section
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  decoration: isPokedex
                      ? BoxDecoration(
                          color: AppThemes.pokedexCard,
                          border: Border(
                            top: BorderSide(
                              color: AppThemes.pokedexBlue.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                        )
                      : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isPokedex)
                        Text(
                          '#${(index + 1).toString().padLeft(3, '0')}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppThemes.pokedexBlue,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      Text(
                        isIdentifying
                            ? (isPokedex ? 'SCANNING...' : 'Identifying...')
                            : (isPokedex
                                  ? plane.identification.toUpperCase()
                                  : plane.identification),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(letterSpacing: isPokedex ? 0.5 : 0),
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
                              .map((tag) => _buildTag(tag, isPokedex))
                              .toList(),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // Scanning indicator for Pokedex mode
            if (isIdentifying && isPokedex)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppThemes.pokedexYellow.withValues(alpha: 0.9),
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
    if (isPokedex && settings.entryAnimation) {
      card = _AnimatedEntry(index: index, child: card);
    }

    return card;
  }

  Widget _buildTag(String tag, bool isPokedex) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isPokedex ? AppThemes.pokedexDarkGray : Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
        border: isPokedex
            ? Border.all(color: AppThemes.pokedexBlue.withValues(alpha: 0.5))
            : null,
      ),
      child: Text(
        isPokedex ? tag.toUpperCase() : tag,
        style: TextStyle(
          fontSize: 10,
          color: isPokedex ? AppThemes.pokedexLightBlue : Colors.black87,
          letterSpacing: isPokedex ? 0.5 : 0,
        ),
      ),
    );
  }

  Widget _buildFAB(bool isPokedex) {
    return FloatingActionButton(
      onPressed: () async {
        if (isPokedex && ref.read(themeProvider).soundEffects) {
          ref.read(soundServiceProvider).play(PokedexSound.select);
        }
        await Navigator.pushNamed(context, '/add');
        setState(() {});
      },
      backgroundColor: isPokedex ? AppThemes.pokedexRed : null,
      child: Icon(
        isPokedex ? Icons.camera_alt : Icons.add,
        color: Colors.white,
      ),
    );
  }
}

/// Custom Pokedex header widget with curved diagonal design
class _PokedexHeader extends StatelessWidget {
  final int scannedCount;
  final int identifyingCount;
  final int confirmedCount;
  final bool animatedLeds;
  final Animation<double> ledAnimation;
  final VoidCallback onSettingsTap;

  const _PokedexHeader({
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

    return SizedBox(
      height: topPadding + 140,
      child: Stack(
        children: [
          // Background with custom shape
          ClipPath(
            clipper: _PokedexHeaderClipper(),
            child: Container(
              decoration: BoxDecoration(
                color: AppThemes.pokedexDarkRed,
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
            painter: _PokedexHeaderBorderPainter(),
            size: Size(screenWidth, topPadding + 140),
          ),

          // Content
          Padding(
            padding: EdgeInsets.only(top: topPadding + 8, left: 16, right: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side: Row containing [Main LED Column] and [Vertical Status LEDs]
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main LED Column
                    Column(
                      children: [
                        _buildMainLed(),
                        const SizedBox(height: 4),
                        const Text(
                          'SCANNED',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white70,
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    // Vertical Status LEDs
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _buildStatusLeds(),
                    ),
                  ],
                ),

                const SizedBox(width: 16),

                // Right side: Logo and settings
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Planedex Logo
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Image.asset(
                              'assets/images/planedex_logo.png',
                              height: 80,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Settings gear icon (simplified)
                        GestureDetector(
                          onTap: onSettingsTap,
                          child: const Icon(
                            Icons.settings,
                            size: 28,
                            color: AppThemes.pokedexBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppThemes.pokedexBlack,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              AppThemes.pokedexLightBlue,
              AppThemes.pokedexBlue,
              AppThemes.pokedexBlue.withValues(alpha: 0.7),
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: AppThemes.pokedexLightBlue.withValues(
                alpha: glowIntensity * 0.7,
              ),
              blurRadius: 15 * glowIntensity,
              spreadRadius: 3 * glowIntensity,
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                scannedCount.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.0,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusLeds() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSmallLed(
              color: AppThemes.pokedexRed,
              isActive: identifyingCount > 0,
              tooltip: 'Scanning',
            ),
            const SizedBox(width: 8),
            const Text(
              'SCANNING',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSmallLed(
              color: AppThemes.pokedexYellow,
              isActive: true,
              tooltip: 'Ready',
            ),
            const SizedBox(width: 8),
            const Text(
              'READY',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSmallLed(
              color: AppThemes.pokedexGreen,
              isActive: confirmedCount > 0,
              tooltip: 'Confirmed',
            ),
            const SizedBox(width: 8),
            const Text(
              'CONFIRMED',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSmallLed({
    required Color color,
    required bool isActive,
    required String tooltip,
  }) {
    Widget led = animatedLeds && isActive
        ? AnimatedBuilder(
            animation: ledAnimation,
            builder: (context, child) =>
                _buildSmallLedContent(color, isActive, ledAnimation.value),
          )
        : _buildSmallLedContent(color, isActive, 1.0);

    return Tooltip(message: tooltip, child: led);
  }

  Widget _buildSmallLedContent(
    Color color,
    bool isActive,
    double glowIntensity,
  ) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? color : color.withValues(alpha: 0.3),
        border: Border.all(color: Colors.black54, width: 2),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: color.withValues(alpha: glowIntensity * 0.7),
                  blurRadius: 6 * glowIntensity,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}

/// Custom clipper for the Pokedex header diagonal shape
class _PokedexHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    // Start from top-left
    path.moveTo(0, 0);

    // Top edge
    path.lineTo(size.width, 0);

    // Right edge - go down to the upper level (logo section)
    path.lineTo(size.width, size.height - 55);

    // Diagonal line going down-left
    path.lineTo(size.width * 0.35, size.height - 55);

    // The angled transition
    path.lineTo(size.width * 0.25, size.height - 20);

    // Bottom left horizontal (LED section is lower)
    path.lineTo(0, size.height - 20);

    // Close back to start
    path.lineTo(0, 0);

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Custom painter for the diagonal border line
class _PokedexHeaderBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppThemes.pokedexBlack
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final path = Path();

    // Draw the bottom edge line
    path.moveTo(0, size.height - 20);
    path.lineTo(size.width * 0.25, size.height - 20);
    path.lineTo(size.width * 0.35, size.height - 55);
    path.lineTo(size.width, size.height - 55);

    canvas.drawPath(path, paint);

    // Inner glow line
    final glowPaint = Paint()
      ..color = AppThemes.pokedexBlue.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final glowPath = Path();
    glowPath.moveTo(0, size.height - 22);
    glowPath.lineTo(size.width * 0.24, size.height - 22);
    glowPath.lineTo(size.width * 0.34, size.height - 57);
    glowPath.lineTo(size.width, size.height - 57);

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
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeIn = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _slideIn = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Stagger the animation based on index
    Future.delayed(Duration(milliseconds: widget.index * 100), () {
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

/// CRT scanlines painter with heavier effect
class CrtScanlinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Scanlines
    final linePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..strokeWidth = 1;

    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Subtle color tint lines
    final tintPaint = Paint()
      ..color = AppThemes.pokedexBlue.withValues(alpha: 0.02)
      ..strokeWidth = 1;

    for (double y = 1; y < size.height; y += 6) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), tintPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Pokedex device frame wrapper
class _PokedexFrame extends StatelessWidget {
  final Widget child;

  const _PokedexFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppThemes.pokedexBlack,
        border: Border.all(color: AppThemes.pokedexDarkRed, width: 4),
      ),
      child: Column(
        children: [
          // Main content
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppThemes.pokedexBlue.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: child,
            ),
          ),
          // Bottom bezel with small LEDs
          Container(
            height: 12,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppThemes.pokedexDarkRed.withValues(alpha: 0.8),
                  AppThemes.pokedexDarkRed,
                  AppThemes.pokedexDarkRed.withValues(alpha: 0.8),
                ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildBezelLed(Colors.white54),
                const SizedBox(width: 12),
                _buildBezelLed(Colors.white54),
                const SizedBox(width: 12),
                _buildBezelLed(Colors.white54),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBezelLed(Color color) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
