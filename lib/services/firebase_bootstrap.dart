import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../firebase_options.dart';

/// Whether Firebase initialized and an (anonymous) user is signed in.
/// Overridden in main(); everything cloud-related keys off this.
final cloudEnabledProvider = Provider<bool>((ref) => false);

/// Brings up Firebase if the app has been configured with
/// `flutterfire configure`; otherwise the app runs fully local.
///
/// - App Check uses debug providers in debug builds and
///   Play Integrity / App Attest in release builds.
/// - Auth is anonymous: each install gets a stable uid with no login UI.
///   Account linking (Google/Apple) can be layered on later without losing
///   data, via FirebaseAuth linkWithCredential.
class FirebaseBootstrap {
  /// Returns true when Firebase is up AND a user is signed in — the
  /// preconditions for Firestore/Storage sync. firebase_ai only needs
  /// Firebase itself, so it checks [Firebase.apps] instead.
  static Future<bool> init() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('Firebase not configured — running local-only. ($e)');
      return false;
    }

    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? AndroidDebugProvider()
            : AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? AppleDebugProvider()
            : AppleAppAttestProvider(),
      );
    } catch (e) {
      // Non-fatal: API calls may still work if App Check enforcement is off.
      debugPrint('App Check activation failed: $e');
    }

    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      return true;
    } catch (e) {
      // Typically: first-ever launch while offline. Auth persists across
      // launches, so this succeeds on the next launch with connectivity.
      debugPrint('Anonymous sign-in failed — sync disabled this launch: $e');
      return false;
    }
  }

  static bool get firebaseAvailable => Firebase.apps.isNotEmpty;
}
