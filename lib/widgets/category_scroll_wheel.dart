import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/category_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_themes.dart';

/// Corner-mounted retro cog wheel for switching scan categories.
/// Only the top-left quarter of the wheel is visible, peeking from
/// the bottom-right corner of the screen.
class CategoryScrollWheel extends ConsumerStatefulWidget {
  final VoidCallback onAddPressed;

  const CategoryScrollWheel({super.key, required this.onAddPressed});

  @override
  ConsumerState<CategoryScrollWheel> createState() =>
      _CategoryScrollWheelState();
}

class _CategoryScrollWheelState extends ConsumerState<CategoryScrollWheel>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;
  double _currentRotation = 0.0;
  double _targetRotation = 0.0;

  // Pan tracking
  double _panAccum = 0.0;
  static const double _panThreshold = 40.0;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeOutBack,
    ));
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _rotateTo(double targetRotation) {
    _rotationAnimation = Tween<double>(
      begin: _currentRotation,
      end: targetRotation,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeOutBack,
    ));
    _rotationController.forward(from: 0);
    _currentRotation = targetRotation;
  }

  void _goNext() {
    final state = ref.read(categoryProvider);
    final step = (2 * math.pi) / state.categories.length;
    _targetRotation += step;
    _rotateTo(_targetRotation);
    ref.read(categoryProvider.notifier).nextCategory();
  }

  void _goPrev() {
    final state = ref.read(categoryProvider);
    final step = (2 * math.pi) / state.categories.length;
    _targetRotation -= step;
    _rotateTo(_targetRotation);
    ref.read(categoryProvider.notifier).prevCategory();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    // Accumulate vertical and horizontal delta — swipe up-left = next
    _panAccum += (-details.delta.dy + -details.delta.dx) * 0.5;
    if (_panAccum > _panThreshold) {
      _panAccum = 0;
      _goNext();
    } else if (_panAccum < -_panThreshold) {
      _panAccum = 0;
      _goPrev();
    }
  }

  void _onPanEnd(DragEndDetails details) {
    _panAccum = 0;
  }

  @override
  Widget build(BuildContext context) {
    final categoryState = ref.watch(categoryProvider);
    final settings = ref.watch(themeProvider);
    final isPokedex = settings.isPokedex;
    final activeCategory = categoryState.activeCategory;

    const double wheelSize = 150.0;
    const double labelHeight = 28.0;
    const double totalHeight = wheelSize + labelHeight + 8;

    return SizedBox(
      width: wheelSize,
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Category label tag — above the wheel
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _CategoryLabel(
              name: activeCategory.name,
              emoji: activeCategory.emoji,
              isPokedex: isPokedex,
            ),
          ),

          // The cog wheel itself
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              onTap: _goNext,
              child: SizedBox(
                width: wheelSize,
                height: wheelSize,
                child: Stack(
                  children: [
                    // Animated cog
                    AnimatedBuilder(
                      animation: _rotationAnimation,
                      builder: (context, _) {
                        return CustomPaint(
                          size: const Size(wheelSize, wheelSize),
                          painter: _CogWheelPainter(
                            rotation: _rotationAnimation.value,
                            isPokedex: isPokedex,
                            categoryCount: categoryState.categories.length,
                            activeIndex: categoryState.activeIndex,
                          ),
                        );
                      },
                    ),

                    // Plus button near the corner (center of cog)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: GestureDetector(
                        onTap: widget.onAddPressed,
                        behavior: HitTestBehavior.opaque,
                        child: _PlusButton(isPokedex: isPokedex),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Category name label with retro styling
class _CategoryLabel extends StatelessWidget {
  final String name;
  final String emoji;
  final bool isPokedex;

  const _CategoryLabel({
    required this.name,
    required this.emoji,
    required this.isPokedex,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isPokedex
              ? AppThemes.pokedexDarkRed.withValues(alpha: 0.95)
              : const Color(0xFF1A1A3E).withValues(alpha: 0.95),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(8),
            bottomLeft: Radius.circular(8),
          ),
          border: Border.all(
            color: isPokedex
                ? AppThemes.pokedexRed.withValues(alpha: 0.8)
                : Colors.blueAccent.withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isPokedex
                  ? AppThemes.pokedexRed.withValues(alpha: 0.3)
                  : Colors.blueAccent.withValues(alpha: 0.2),
              blurRadius: 6,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 5),
            Text(
              name.toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: isPokedex ? 1.5 : 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Plus button that sits at the cog center (screen corner)
class _PlusButton extends StatelessWidget {
  final bool isPokedex;

  const _PlusButton({required this.isPokedex});

  @override
  Widget build(BuildContext context) {
    final color = isPokedex ? AppThemes.pokedexRed : Colors.blueAccent;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.6),
            blurRadius: 10,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 4,
            offset: const Offset(-1, -1),
          ),
        ],
      ),
      child: const Icon(Icons.add, color: Colors.white, size: 20),
    );
  }
}

/// Custom painter for the retro gear/cog wheel.
/// The cog center is drawn at (size.width, size.height) — the bottom-right
/// corner of the widget — so only the top-left quadrant is visible.
class _CogWheelPainter extends CustomPainter {
  final double rotation;
  final bool isPokedex;
  final int categoryCount;
  final int activeIndex;

  static const double _outerRadius = 135.0;
  static const double _innerRadius = 52.0;
  static const double _toothHeight = 16.0;
  static const double _hubRadius = 28.0;
  static const int _numTeeth = 22;

  _CogWheelPainter({
    required this.rotation,
    required this.isPokedex,
    required this.categoryCount,
    required this.activeIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width, size.height);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    _drawCogBody(canvas);
    _drawCogTeeth(canvas);
    _drawInnerRing(canvas);
    _drawCategoryDots(canvas);
    _drawHubHighlight(canvas);

    canvas.restore();

    // Outer glow / rim (not rotated)
    _drawRimGlow(canvas, center);
  }

  void _drawCogBody(Canvas canvas) {
    final baseColor = isPokedex
        ? const Color(0xFF1A1A2E)
        : const Color(0xFF18182E);
    final edgeColor = isPokedex
        ? AppThemes.pokedexBlue.withValues(alpha: 0.7)
        : Colors.blueAccent.withValues(alpha: 0.5);

    // Build the cog path (circle with teeth)
    final path = _buildCogPath();

    // Main fill with radial gradient
    final fillPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF2E2E4E),
          baseColor,
          const Color(0xFF0E0E1E),
        ],
        stops: const [0.0, 0.5, 1.0],
        center: const Alignment(-0.3, -0.3),
      ).createShader(
        Rect.fromCircle(center: Offset.zero, radius: _outerRadius + _toothHeight),
      )
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, fillPaint);

    // Edge stroke
    final strokePaint = Paint()
      ..color = edgeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawPath(path, strokePaint);

    // Metallic sheen — arc highlight on top-left
    final sheenPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.08),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.15, 0.3],
        startAngle: math.pi,
        endAngle: math.pi * 1.7,
      ).createShader(
        Rect.fromCircle(center: Offset.zero, radius: _outerRadius),
      )
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, sheenPaint);
  }

  Path _buildCogPath() {
    final path = Path();
    final angleStep = (2 * math.pi) / _numTeeth;
    final halfTooth = angleStep * 0.28;

    for (int i = 0; i < _numTeeth; i++) {
      final angle = i * angleStep;

      // Four points per tooth (trapezoidal teeth)
      final a1 = angle - halfTooth * 1.1; // outer left base
      final a2 = angle - halfTooth * 0.7; // outer left tip
      final a3 = angle + halfTooth * 0.7; // outer right tip
      final a4 = angle + halfTooth * 1.1; // outer right base

      final p1 = Offset(
        math.cos(a1) * _outerRadius,
        math.sin(a1) * _outerRadius,
      );
      final p2 = Offset(
        math.cos(a2) * (_outerRadius + _toothHeight),
        math.sin(a2) * (_outerRadius + _toothHeight),
      );
      final p3 = Offset(
        math.cos(a3) * (_outerRadius + _toothHeight),
        math.sin(a3) * (_outerRadius + _toothHeight),
      );
      final p4 = Offset(
        math.cos(a4) * _outerRadius,
        math.sin(a4) * _outerRadius,
      );

      if (i == 0) {
        path.moveTo(p1.dx, p1.dy);
      } else {
        path.lineTo(p1.dx, p1.dy);
      }
      path.lineTo(p2.dx, p2.dy);
      path.lineTo(p3.dx, p3.dy);
      path.lineTo(p4.dx, p4.dy);
    }
    path.close();
    return path;
  }

  void _drawCogTeeth(Canvas canvas) {
    // Draw tooth edge highlights for metallic feel
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final angleStep = (2 * math.pi) / _numTeeth;
    final halfTooth = angleStep * 0.28;

    for (int i = 0; i < _numTeeth; i++) {
      final angle = i * angleStep;
      final a2 = angle - halfTooth * 0.7;
      final a3 = angle + halfTooth * 0.7;

      final p2 = Offset(
        math.cos(a2) * (_outerRadius + _toothHeight),
        math.sin(a2) * (_outerRadius + _toothHeight),
      );
      final p3 = Offset(
        math.cos(a3) * (_outerRadius + _toothHeight),
        math.sin(a3) * (_outerRadius + _toothHeight),
      );

      canvas.drawLine(p2, p3, highlightPaint);
    }
  }

  void _drawInnerRing(Canvas canvas) {
    final ringColor = isPokedex
        ? AppThemes.pokedexBlue.withValues(alpha: 0.5)
        : Colors.blueAccent.withValues(alpha: 0.4);

    // Inner track groove
    final groovePaint = Paint()
      ..color = const Color(0xFF0A0A18)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset.zero, _innerRadius, groovePaint);

    final grooveRingPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(Offset.zero, _innerRadius, grooveRingPaint);

    // Inner groove line
    final innerGroovePaint = Paint()
      ..color = ringColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(Offset.zero, _innerRadius - 6, innerGroovePaint);
  }

  void _drawCategoryDots(Canvas canvas) {
    if (categoryCount <= 0) return;

    final dotRadius = _innerRadius - 14;
    final anglePerCategory = (2 * math.pi) / categoryCount;

    for (int i = 0; i < categoryCount; i++) {
      final angle = i * anglePerCategory;
      final pos = Offset(
        math.cos(angle) * dotRadius,
        math.sin(angle) * dotRadius,
      );

      final isActive = i == activeIndex;
      final dotColor = isActive
          ? (isPokedex ? AppThemes.pokedexYellow : Colors.blueAccent)
          : Colors.white.withValues(alpha: 0.2);

      final dotPaint = Paint()
        ..color = dotColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(pos, isActive ? 4.5 : 3.0, dotPaint);

      if (isActive) {
        final glowPaint = Paint()
          ..color = dotColor.withValues(alpha: 0.4)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, 7.0, glowPaint);
      }
    }
  }

  void _drawHubHighlight(Canvas canvas) {
    // Hub circle (center knob area)
    final hubGradient = RadialGradient(
      colors: [
        Colors.white.withValues(alpha: 0.15),
        Colors.transparent,
      ],
      stops: const [0.0, 1.0],
      center: const Alignment(-0.3, -0.3),
    );

    final hubPaint = Paint()
      ..shader = hubGradient.createShader(
        Rect.fromCircle(center: Offset.zero, radius: _hubRadius),
      )
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset.zero, _hubRadius, hubPaint);

    final hubRingPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(Offset.zero, _hubRadius, hubRingPaint);
  }

  void _drawRimGlow(Canvas canvas, Offset center) {
    final rimColor = isPokedex
        ? AppThemes.pokedexBlue.withValues(alpha: 0.15)
        : Colors.blueAccent.withValues(alpha: 0.1);

    final rimPaint = Paint()
      ..color = rimColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    // Draw just the visible arc (top-left quarter from center)
    const startAngle = math.pi; // left
    const sweepAngle = -math.pi / 2; // counterclockwise to up

    canvas.drawArc(
      Rect.fromCircle(
        center: center,
        radius: _outerRadius + _toothHeight + 2,
      ),
      startAngle,
      sweepAngle,
      false,
      rimPaint,
    );
  }

  @override
  bool shouldRepaint(_CogWheelPainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.isPokedex != isPokedex ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.categoryCount != categoryCount;
  }
}
