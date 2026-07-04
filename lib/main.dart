import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/firebase_bootstrap.dart';
import 'services/image_store.dart';
import 'services/storage_service.dart';
import 'services/sync_service.dart';
import 'screens/home_screen.dart';
import 'screens/add_plane_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/boot_screen.dart';
import 'providers/theme_provider.dart';
import 'theme/app_themes.dart';
import 'models/plane.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env.local');

  await ImageStore.init();

  // No-op (returns false) until `flutterfire configure` has been run.
  final cloudEnabled = await FirebaseBootstrap.init();

  final storageService = StorageService();
  await storageService.init();

  if (cloudEnabled) {
    storageService.sync = SyncService(storageService)..start();
  }

  // Temporary injection of test plane
  if (!storageService.getAllPlanes().any((p) => p.identification == 'F-35 Lightning II')) {
    final testPlane = Plane(
      id: 'test_f35_01',
      imagePath: 'assets/images/f35.jpg',
      timestamp: DateTime.now(),
      identification: 'F-35 Lightning II',
      description: 'The Lockheed Martin F-35 Lightning II is an American family of single-seat, single-engine, all-weather stealth multirole combat aircraft.',
      status: PlaneStatus.finalized,
      tags: ['Military', 'Stealth', 'Fighter', 'Test'],
    );
    await storageService.savePlane(testPlane);
  }

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storageService),
        cloudEnabledProvider.overrideWithValue(cloudEnabled),
      ],
      child: const DexiconApp(),
    ),
  );
}

class DexiconApp extends ConsumerWidget {
  const DexiconApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(themeProvider);

    // Select theme based on current mode and font
    final theme = settings.isRetro
        ? AppThemes.retroTheme(font: settings.font)
        : AppThemes.classicTheme;

    return MaterialApp(
      title: 'Dexicon',
      theme: theme,
      // Show boot screen if Retro mode and boot animation enabled
      home: settings.isRetro && settings.bootAnimation
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
