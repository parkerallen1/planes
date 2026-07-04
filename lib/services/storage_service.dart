import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../models/plane.dart';
import 'image_store.dart';
import 'sync_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('StorageService not initialized');
});

class StorageService {
  late Box<Plane> _planeBox;

  /// Set by main() when cloud sync is enabled. Every local mutation below
  /// pushes through it; remote changes come back in via the applyRemote*/
  /// removeLocal* methods, which deliberately don't push.
  SyncService? sync;

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(PlaneAdapter());
    Hive.registerAdapter(ChatMessageAdapter());
    Hive.registerAdapter(PlaneStatusAdapter());
    Hive.registerAdapter(PlaneGuessAdapter());
    _planeBox = await Hive.openBox<Plane>('planes');
  }

  /// Notifies on any box change, local or remote — UI listens to this to
  /// pick up synced-in updates.
  ValueListenable<Box<Plane>> get listenable => _planeBox.listenable();

  List<Plane> getAllPlanes() {
    return _planeBox.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Plane? getPlane(String id) => _planeBox.get(id);

  Future<void> savePlane(Plane plane) async {
    plane.updatedAt = DateTime.now().toUtc();
    await _planeBox.put(plane.id, plane);
    sync?.pushPlane(plane);
  }

  Future<void> deletePlane(String id) async {
    await _deleteImageFile(_planeBox.get(id));
    await _planeBox.delete(id);
    sync?.pushDelete(id);
  }

  Future<void> updatePlane(Plane plane) async {
    plane.updatedAt = DateTime.now().toUtc();
    await plane.save();
    sync?.pushPlane(plane);
  }

  /// Remote → local write; no updatedAt re-stamp and no push-back.
  Future<void> applyRemotePlane(Plane plane) async {
    await _planeBox.put(plane.id, plane);
  }

  /// Remote → local delete; no tombstone push-back.
  Future<void> removeLocalPlane(String id) async {
    await _deleteImageFile(_planeBox.get(id));
    await _planeBox.delete(id);
  }

  Future<void> _deleteImageFile(Plane? plane) async {
    if (plane == null || plane.imagePath.startsWith('assets/')) return;
    final imageFile = File(ImageStore.resolve(plane.imagePath));
    if (await imageFile.exists()) {
      await imageFile.delete();
    }
  }

  // Helper to get all unique tags
  Set<String> getAllTags() {
    final tags = <String>{};
    for (var plane in _planeBox.values) {
      tags.addAll(plane.tags);
    }
    return tags;
  }

  Future<File> exportToJson() async {
    final planes = getAllPlanes();
    final data = {
      'exportDate': DateTime.now().toIso8601String(),
      'count': planes.length,
      'planes': planes.map((p) => p.toJson()).toList(),
    };
    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final file = File('${dir.path}/dexicon_backup_$timestamp.json');
    await file.writeAsString(jsonString);
    return file;
  }

  Future<int> importFromJson(String jsonString) async {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    final planesJson = data['planes'] as List<dynamic>;
    int imported = 0;
    for (final pJson in planesJson) {
      final plane = Plane.fromJson(pJson as Map<String, dynamic>);
      // Route through savePlane so imports get stamped and cloud-synced.
      await savePlane(plane);
      imported++;
    }
    return imported;
  }
}
