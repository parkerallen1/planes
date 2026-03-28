import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/category_provider.dart';

/// Corner-mounted retro skeuomorphic cog wheel for switching scan categories.
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
  static const double _panThreshold = 20.0;

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
    HapticFeedback.lightImpact();
    final state = ref.read(categoryProvider);
    final step = (2 * math.pi) / state.categories.length;
    _targetRotation += step;
    _rotateTo(_targetRotation);
    ref.read(categoryProvider.notifier).nextCategory();
  }

  void _goPrev() {
    HapticFeedback.lightImpact();
    final state = ref.read(categoryProvider);
    final step = (2 * math.pi) / state.categories.length;
    _targetRotation -= step;
    _rotateTo(_targetRotation);
    ref.read(categoryProvider.notifier).prevCategory();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    // Intuitive corner wheel interaction: 
    // Swipe UP (-dy) or RIGHT (+dx) rotates clockwise (Next).
    _panAccum += (-details.delta.dy + details.delta.dx) * 0.5;
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
    final activeCategory = categoryState.activeCategory;

    const double size = 180.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // BOTTOM: Animated cog wheel layer
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              onTap: _goNext,
              child: SizedBox(
                width: size,
                height: size,
                child: AnimatedBuilder(
                  animation: _rotationAnimation,
                  builder: (context, _) {
                    return CustomPaint(
                      size: const Size(size, size),
                      painter: _CogWheelPainter(
                        rotation: _rotationAnimation.value,
                        categoryCount: categoryState.categories.length,
                        activeIndex: categoryState.activeIndex,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // MIDDLE: The charcoal plastic casing with arc cutout
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _CasingShellPainter(),
              ),
            ),
          ),

          // TOP: UI Elements (Text, Window, Button)
          // MODE Text
          Positioned(
            top: 36,
            left: 20,
            child: Transform.rotate(
              angle: -math.pi / 4, // 45 degrees diagonal
              child: const Text(
                'MODE',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                ),
              ),
            ),
          ),

          // Settings Film Counter Window
          Positioned(
            top: 14,
            right: 14,
            child: _SkeuomorphicCounterWindow(
              index: categoryState.activeIndex + 1,
              emoji: activeCategory.emoji,
            ),
          ),

          // Physical Plus button near the corner
          Positioned(
            right: 12,
            bottom: 12,
            child: GestureDetector(
              onTap: widget.onAddPressed,
              behavior: HitTestBehavior.opaque,
              child: const _PlusButton(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws the solid black casing shell *over* the gear, with a circular cutout.
class _CasingShellPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Base Casing Path
    const cornerRadius = 70.0;
    final casingPath = Path()
      ..addRRect(RRect.fromRectAndCorners(
        Rect.fromLTWH(0, 0, size.width, size.height),
        topLeft: const Radius.circular(cornerRadius),
      ));

    // 2. The Hole Cutout (Radius 162 ensures it fits the gear's 157 radius nicely)
    const holeRadius = 162.0;
    final holeCenter = Offset(size.width, size.height);
    final holePath = Path()
      ..addOval(Rect.fromCircle(center: holeCenter, radius: holeRadius));

    // Fill the casing (everything in casingPath EXCEPT holePath)
    final combinedPath = Path.combine(PathOperation.difference, casingPath, holePath);

    // 3. Drop Shadow of outer casing frame
    canvas.drawShadow(combinedPath, Colors.black87, 8.0, false);

    // 4. Fill Casing Material
    final fillPaint = Paint()
      ..color = const Color(0xFF222222) // Matte charcoal plastic
      ..style = PaintingStyle.fill;
    canvas.drawPath(combinedPath, fillPaint);

    // 5. Casing Bevel Highlight
    final casingBevel = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(combinedPath, casingBevel);

    // 6. Hole Cutout Inner Shadow (Cast onto the gear below)
    canvas.save();
    canvas.clipPath(holePath); // Constrain painting to inside the hole only

    final holeShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    
    // Draw the stroke exactly on the rim of the hole; half will expand inwards creating a shadow.
    canvas.drawPath(holePath, holeShadowPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A recessed "film counter" style indicator showing the current category
class _SkeuomorphicCounterWindow extends StatelessWidget {
  final int index;
  final String emoji;

  const _SkeuomorphicCounterWindow({
    required this.index,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0), // White plastic background
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        border: Border.all(color: Colors.black87, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            offset: const Offset(1, 1),
            blurRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Text(
          '${index.toString().padLeft(2, '0')} $emoji',
          style: const TextStyle(
            color: Color(0xFF111111), // Bold ink black
            fontSize: 12,
            fontWeight: FontWeight.w900,
            fontFamily: 'Courier', // Gives it a stamped serial number feel
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}

/// A chunky, matte gray physical button that replaces the neon one.
class _PlusButton extends StatelessWidget {
  const _PlusButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF888888), // Medium grey plastic
        boxShadow: [
          // White bevel on top-left
          BoxShadow(color: Colors.white70, offset: Offset(-1, -1), blurRadius: 1),
          // Dark drop shadow on bottom-right
          BoxShadow(color: Colors.black87, offset: Offset(1.5, 1.5), blurRadius: 2),
        ],
      ),
      child: const Center(
        child: Text(
          '+',
          style: TextStyle(
            color: Color(0xFF333333), // Dark engraved ink
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

/// Custom painter for the 90s gray plastic gear.
/// The cog center is drawn at (size.width, size.height) — the bottom-right
/// corner of the widget — so only the top-left quadrant is visible.
class _CogWheelPainter extends CustomPainter {
  final double rotation;
  final int categoryCount;
  final int activeIndex;

  static const double _outerRadius = 135.0;
  static const double _innerRadius = 55.0;
  static const double _toothHeight = 22.0;
  static const double _hubRadius = 32.0;
  static const int _numTeeth = 18;

  _CogWheelPainter({
    required this.rotation,
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
    _drawCategoryDimples(canvas);
    _drawHubHighlight(canvas);

    canvas.restore();
  }

  void _drawCogBody(Canvas canvas) {
    final path = _buildCogPath();

    // Matte plastic linear gradient giving consistent lighting
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF888888),
          Color(0xFF7A7A7A),
          Color(0xFF5A5A5A),
        ],
      ).createShader(
        Rect.fromCircle(
            center: Offset.zero, radius: _outerRadius + _toothHeight),
      )
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, fillPaint);

    // Embossed edge stroke
    final strokePaint = Paint()
      ..color = const Color(0xFF555555) // Dark outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawPath(path, strokePaint);
  }

  Path _buildCogPath() {
    final path = Path();
    final angleStep = (2 * math.pi) / _numTeeth;
    final halfTooth = angleStep * 0.35; // Chunkier, broader teeth for plastic

    for (int i = 0; i < _numTeeth; i++) {
      final angle = i * angleStep;

      final a1 = angle - halfTooth * 1.0;
      final a2 = angle - halfTooth * 0.7;
      final a3 = angle + halfTooth * 0.7;
      final a4 = angle + halfTooth * 1.0;

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
    // Add specular white highlights on the leading edges of the plastic teeth
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final angleStep = (2 * math.pi) / _numTeeth;
    final halfTooth = angleStep * 0.35;

    for (int i = 0; i < _numTeeth; i++) {
      final angle = i * angleStep;

      // Leading tip
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

      // Trailing side dip down to base
      final a4 = angle + halfTooth * 1.0;
      final p4 = Offset(
        math.cos(a4) * _outerRadius,
        math.sin(a4) * _outerRadius,
      );

      // Draw light hitting the top left surfaces
      if (angle > math.pi && angle < 1.6 * math.pi) {
         canvas.drawLine(p2, p3, highlightPaint);
      } else {
         canvas.drawLine(p3, p4, shadowPaint);
      }
    }
  }

  void _drawInnerRing(Canvas canvas) {
    // Inner track groove - carved in dark grey
    final groovePaint = Paint()
      ..color = const Color(0xFF666666)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset.zero, _innerRadius, groovePaint);

    final shadowRingPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawCircle(Offset.zero, _innerRadius, shadowRingPaint);

    // Inner groove distinct line
    final innerGroovePaint = Paint()
      ..color = const Color(0xFF555555)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(Offset.zero, _innerRadius - 6, innerGroovePaint);
  }

  void _drawCategoryDimples(Canvas canvas) {
    if (categoryCount <= 0) return;

    final dotRadius = _innerRadius - 16;
    final anglePerCategory = (2 * math.pi) / categoryCount;

    for (int i = 0; i < categoryCount; i++) {
      final angle = i * anglePerCategory;
      final pos = Offset(
        math.cos(angle) * dotRadius,
        math.sin(angle) * dotRadius,
      );

      // Recessed hole dimple
      final dotPaint = Paint()..color = const Color(0xFF333333); // Dark shadow in hole
      canvas.drawCircle(pos, 4.0, dotPaint);

      final glowPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      
      canvas.drawCircle(pos, 4.5, glowPaint); // Bevel edge
    }
  }

  void _drawHubHighlight(Canvas canvas) {
    final hubPaint = Paint()
      ..color = const Color(0xFF7A7A7A)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset.zero, _hubRadius, hubPaint);

    // Elevated hub ring
    final hubRingPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(Offset.zero, _hubRadius, hubRingPaint);
    
    // Bottom right drop shadow on the hub
    final hubShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawArc(
       Rect.fromCircle(center: Offset.zero, radius: _hubRadius),
       0, math.pi / 2, false, hubShadowPaint,
    );
  }

  @override
  bool shouldRepaint(_CogWheelPainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.categoryCount != categoryCount;
  }
}
