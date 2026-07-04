// PLACEHOLDER — replaced wholesale by `flutterfire configure`.
//
// Until that runs (see FIREBASE_SETUP.md), `currentPlatform` throws,
// FirebaseBootstrap catches it, and the app runs local-only: Hive storage,
// no cloud sync, Gemini via the .env.local API key.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'Firebase has not been configured for this app yet — run '
      '`flutterfire configure` (see FIREBASE_SETUP.md).',
    );
  }
}
