import 'dart:convert';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
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
      await _planeBox.put(plane.id, plane);
      imported++;
    }
    return imported;
  }
}
