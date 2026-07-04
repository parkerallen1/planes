import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Permanent, app-owned storage for scan photos.
///
/// `image_picker` returns files in an OS-purgeable cache directory, and on
/// iOS the app container path changes across app updates — so absolute
/// picker paths saved in Hive eventually stop resolving. Every picked photo
/// is copied into `<documents>/scans/<uuid>.<ext>` and persisted as the
/// relative token (`scans/<uuid>.jpg`), which stays valid across updates
/// and is portable across devices once cloud photo sync exists.
class ImageStore {
  static const _scansSubdir = 'scans';
  static late final String _docsPath;

  static Future<void> init() async {
    _docsPath = (await getApplicationDocumentsDirectory()).path;
    final dir = Directory('$_docsPath/$_scansSubdir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// Copies a freshly picked photo into permanent storage and returns the
  /// relative token to persist on the item (e.g. `scans/ab12cd….jpg`).
  static Future<String> importImage(File source) async {
    final dotIndex = source.path.lastIndexOf('.');
    final ext = dotIndex == -1
        ? 'jpg'
        : source.path.substring(dotIndex + 1).toLowerCase();
    final token = '$_scansSubdir/${const Uuid().v4()}.$ext';
    await source.copy('$_docsPath/$token');
    return token;
  }

  /// Maps a stored image path — relative token, bundled asset, or legacy
  /// absolute path — to a path `File()` can open. Callers keep branching on
  /// `startsWith('assets/')` for bundled images.
  static String resolve(String stored) {
    if (stored.startsWith('assets/')) return stored;
    if (!stored.startsWith('/')) return '$_docsPath/$stored';
    if (File(stored).existsSync()) return stored;
    // Legacy absolute path whose container moved (iOS app update). If the
    // file was since re-homed under scans/ keep the same basename.
    final basename = stored.substring(stored.lastIndexOf('/') + 1);
    return '$_docsPath/$_scansSubdir/$basename';
  }

  /// Absolute path for a relative token, whether or not the file exists yet.
  static File fileFor(String token) => File('$_docsPath/$token');
}
