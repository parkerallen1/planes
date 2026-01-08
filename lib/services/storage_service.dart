import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/plane.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('StorageService not initialized');
});

class StorageService {
  late Box<Plane> _planeBox;

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(PlaneAdapter());
    Hive.registerAdapter(ChatMessageAdapter());
    Hive.registerAdapter(PlaneStatusAdapter());
    Hive.registerAdapter(PlaneGuessAdapter());
    _planeBox = await Hive.openBox<Plane>('planes');
  }

  List<Plane> getAllPlanes() {
    return _planeBox.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> savePlane(Plane plane) async {
    await _planeBox.put(plane.id, plane);
  }

  Future<void> deletePlane(String id) async {
    await _planeBox.delete(id);
  }

  Future<void> updatePlane(Plane plane) async {
    await plane.save();
  }

  // Helper to get all unique tags
  Set<String> getAllTags() {
    final tags = <String>{};
    for (var plane in _planeBox.values) {
      tags.addAll(plane.tags);
    }
    return tags;
  }
}
