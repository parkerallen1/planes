import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_themes.dart';
import '../providers/theme_provider.dart';
import '../services/sound_service.dart';
import '../widgets/dexicon_logo.dart';
import 'home_screen.dart';

/// Boot screen with Retro-style startup animation
class BootScreen extends ConsumerStatefulWidget {
  const BootScreen({super.key});

  @override
  ConsumerState<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends ConsumerState<BootScreen>
    with TickerProviderStateMixin {
  late AnimationController _bootController;
  late AnimationController _glowController;
  late Animation<double> _fadeIn;
  late Animation<double> _ledSequence;
  late Animation<double> _textReveal;
  late Animation<double> _glow;

  bool _bootComplete = false;

  @override
  void initState() {
    super.initState();

    _bootController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _bootController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    _ledSequence = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _bootController,
        curve: const Interval(0.2, 0.6, curve: Curves.easeInOut),
      ),
    );

    _textReveal = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _bootController,
        curve: const Interval(0.5, 0.8, curve: Curves.easeOut),
      ),
    );

    _glow = Tween<double>(begin: 0.3, end: 1.0).animate(_glowController);

    _startBootSequence();
  }

  Future<void> _startBootSequence() async {
    final settings = ref.read(themeProvider);

    // Play boot sound if enabled
    if (settings.soundEffects) {
      final soundService = ref.read(soundServiceProvider);
      soundService.play(RetroSound.bootUp);
    }

    await _bootController.forward();

    // Brief pause before transitioning
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() => _bootComplete = true);

    // Navigate to home
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  void dispose() {
    _bootController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemes.retroBlack,
      body: AnimatedBuilder(
        animation: _bootController,
        builder: (context, child) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // LED indicators row
                Opacity(
                  opacity: _fadeIn.value,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildBootLed(0, AppThemes.retroBlue),
                      const SizedBox(width: 12),
                      _buildBootLed(1, AppThemes.retroRed),
                      const SizedBox(width: 12),
                      _buildBootLed(2, AppThemes.retroGreen),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Main logo with glow effect
                Opacity(
                  opacity: _fadeIn.value,
                  child: AnimatedBuilder(
                    animation: _glow,
                    builder: (context, child) {
                      return Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: AppThemes.retroBlue.withValues(
                                alpha: _glow.value * 0.4,
                              ),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Opacity(
                          opacity: _textReveal.value,
                          child: const DexiconLogo(fontSize: 40),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // Subtitle
                Opacity(
                  opacity: _textReveal.value,
                  child: Text(
                    'Visual Identification System',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppThemes.retroLightBlue.withValues(alpha: 0.8),
                      letterSpacing: 2,
                    ),
                  ),
                ),

                const SizedBox(height: 60),

                // Loading indicator
                if (!_bootComplete)
                  Opacity(
                    opacity: _ledSequence.value,
                    child: SizedBox(
                      width: 150,
                      child: LinearProgressIndicator(
                        value: _ledSequence.value,
                        backgroundColor: AppThemes.retroDarkGray,
                        valueColor: const AlwaysStoppedAnimation(
                          AppThemes.retroBlue,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                Opacity(
                  opacity: _ledSequence.value,
                  child: Text(
                    'INITIALIZING...',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppThemes.retroBlue.withValues(alpha: 0.7),
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBootLed(int index, Color color) {
    final isActive = _ledSequence.value > (index * 0.3);

    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) {
        return Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: isActive ? color : color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: _glow.value * 0.8),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}
