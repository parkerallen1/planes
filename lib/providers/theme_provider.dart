import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme mode enum
enum AppThemeMode { classic, retro }

/// Font style options for Retro mode
enum RetroFont {
  system, // Default system font
  pressStart, // Press Start 2P - retro pixel
  vt323, // VT323 - terminal/LCD
  orbitron, // Orbitron - futuristic
  audiowide, // Audiowide - wide sci-fi
}

extension RetroFontExtension on RetroFont {
  String get displayName {
    switch (this) {
      case RetroFont.system:
        return 'System Default';
      case RetroFont.pressStart:
        return 'Press Start 2P';
      case RetroFont.vt323:
        return 'VT323 Terminal';
      case RetroFont.orbitron:
        return 'Orbitron';
      case RetroFont.audiowide:
        return 'Audiowide';
    }
  }

  String get description {
    switch (this) {
      case RetroFont.system:
        return 'Clean, modern';
      case RetroFont.pressStart:
        return 'Classic 8-bit pixel';
      case RetroFont.vt323:
        return 'LCD terminal';
      case RetroFont.orbitron:
        return 'Sleek futuristic';
      case RetroFont.audiowide:
        return 'Wide sci-fi';
    }
  }
}

/// All Retro settings in one state class
class AppSettings {
  final AppThemeMode themeMode;
  final RetroFont font;
  final bool screenFrame;
  final bool animatedLeds;
  final bool crtScanlines;
  final bool entryAnimation;
  final bool soundEffects;
  final bool bootAnimation;

  const AppSettings({
    this.themeMode = AppThemeMode.retro,
    this.font = RetroFont.system,
    this.screenFrame = true,
    this.animatedLeds = true,
    this.crtScanlines = true,
    this.entryAnimation = true,
    this.soundEffects = true,
    this.bootAnimation = true,
  });

  bool get isRetro => themeMode == AppThemeMode.retro;

  AppSettings copyWith({
    AppThemeMode? themeMode,
    RetroFont? font,
    bool? screenFrame,
    bool? animatedLeds,
    bool? crtScanlines,
    bool? entryAnimation,
    bool? soundEffects,
    bool? bootAnimation,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      font: font ?? this.font,
      screenFrame: screenFrame ?? this.screenFrame,
      animatedLeds: animatedLeds ?? this.animatedLeds,
      crtScanlines: crtScanlines ?? this.crtScanlines,
      entryAnimation: entryAnimation ?? this.entryAnimation,
      soundEffects: soundEffects ?? this.soundEffects,
      bootAnimation: bootAnimation ?? this.bootAnimation,
    );
  }
}

/// Provider for the theme/settings notifier
final themeProvider = NotifierProvider<ThemeNotifier, AppSettings>(() {
  return ThemeNotifier();
});

/// Convenience provider for just checking if Retro mode is on
final isRetroProvider = Provider<bool>((ref) {
  return ref.watch(themeProvider).isRetro;
});

/// Theme notifier that manages all Retro settings with persistence
class ThemeNotifier extends Notifier<AppSettings> {
  static const String _themeKey = 'app_theme_mode';
  static const String _fontKey = 'retro_font';
  static const String _screenFrameKey = 'screen_frame';
  static const String _animatedLedsKey = 'animated_leds';
  static const String _crtScanlinesKey = 'crt_scanlines';
  static const String _entryAnimationKey = 'entry_animation';
  static const String _soundEffectsKey = 'sound_effects';
  static const String _bootAnimationKey = 'boot_animation';

  @override
  AppSettings build() {
    _loadSettings();
    return const AppSettings(themeMode: AppThemeMode.retro);
  }

  /// Load all settings from shared preferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final themeName = prefs.getString(_themeKey);
    final fontName = prefs.getString(_fontKey);

    state = AppSettings(
      themeMode: themeName == AppThemeMode.classic.name
          ? AppThemeMode.classic
          : AppThemeMode.retro,
      font: RetroFont.values.firstWhere(
        (f) => f.name == fontName,
        orElse: () => RetroFont.system,
      ),
      screenFrame: prefs.getBool(_screenFrameKey) ?? true,
      animatedLeds: prefs.getBool(_animatedLedsKey) ?? true,
      crtScanlines: prefs.getBool(_crtScanlinesKey) ?? true,
      entryAnimation: prefs.getBool(_entryAnimationKey) ?? true,
      soundEffects: prefs.getBool(_soundEffectsKey) ?? true,
      bootAnimation: prefs.getBool(_bootAnimationKey) ?? true,
    );
  }

  /// Save a specific setting
  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  /// Toggle between themes
  Future<void> toggleTheme() async {
    final newTheme = state.themeMode == AppThemeMode.classic
        ? AppThemeMode.retro
        : AppThemeMode.classic;
    await setTheme(newTheme);
  }

  /// Set a specific theme
  Future<void> setTheme(AppThemeMode theme) async {
    state = state.copyWith(themeMode: theme);
    await _saveSetting(_themeKey, theme.name);
  }

  /// Set the font
  Future<void> setFont(RetroFont font) async {
    state = state.copyWith(font: font);
    await _saveSetting(_fontKey, font.name);
  }

  /// Toggle screen frame
  Future<void> setScreenFrame(bool enabled) async {
    state = state.copyWith(screenFrame: enabled);
    await _saveSetting(_screenFrameKey, enabled);
  }

  /// Toggle animated LEDs
  Future<void> setAnimatedLeds(bool enabled) async {
    state = state.copyWith(animatedLeds: enabled);
    await _saveSetting(_animatedLedsKey, enabled);
  }

  /// Toggle CRT scanlines
  Future<void> setCrtScanlines(bool enabled) async {
    state = state.copyWith(crtScanlines: enabled);
    await _saveSetting(_crtScanlinesKey, enabled);
  }

  /// Toggle entry animation
  Future<void> setEntryAnimation(bool enabled) async {
    state = state.copyWith(entryAnimation: enabled);
    await _saveSetting(_entryAnimationKey, enabled);
  }

  /// Toggle sound effects
  Future<void> setSoundEffects(bool enabled) async {
    state = state.copyWith(soundEffects: enabled);
    await _saveSetting(_soundEffectsKey, enabled);
  }

  /// Toggle boot animation
  Future<void> setBootAnimation(bool enabled) async {
    state = state.copyWith(bootAnimation: enabled);
    await _saveSetting(_bootAnimationKey, enabled);
  }

  // Convenience getters
  bool get isRetro => state.isRetro;
}
