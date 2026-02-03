import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/storage_service.dart';
import 'screens/home_screen.dart';
import 'screens/add_plane_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/boot_screen.dart';
import 'providers/theme_provider.dart';
import 'theme/app_themes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env.local');

  final storageService = StorageService();
  await storageService.init();

  runApp(
    ProviderScope(
      overrides: [storageServiceProvider.overrideWithValue(storageService)],
      child: const PlaneTrackerApp(),
    ),
  );
}

class PlaneTrackerApp extends ConsumerWidget {
  const PlaneTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(themeProvider);

    // Select theme based on current mode and font
    final theme = settings.isPokedex
        ? AppThemes.pokedexTheme(font: settings.font)
        : AppThemes.classicTheme;

    return MaterialApp(
      title: 'Plane Tracker',
      theme: theme,
      // Show boot screen if Pokedex mode and boot animation enabled
      home: settings.isPokedex && settings.bootAnimation
          ? const BootScreen()
          : const HomeScreen(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/add': (context) => const AddPlaneScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
