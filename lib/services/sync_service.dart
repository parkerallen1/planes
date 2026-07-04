import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/plane.dart';
import 'storage_service.dart';

/// Mirrors the local Hive collection to Firestore at
/// `users/{uid}/items/{id}`.
///
/// - Local writes push through [pushPlane]/[pushDelete], called by
///   StorageService after every local mutation. Firestore's offline
///   persistence queues these while offline, so pushes are fire-and-forget.
/// - Remote changes arrive on a realtime snapshot listener and merge
///   last-write-wins on [Plane.updatedAt]; ties (echoes of this device's
///   own writes) are no-ops.
/// - Deletes are soft: the doc stays with `deleted: true` so the deletion
///   replicates reliably to devices that were offline when it happened.
class SyncService {
  SyncService(this._storage);

  final StorageService _storage;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  bool _seededLocalOnly = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _items => FirebaseFirestore
      .instance
      .collection('users')
      .doc(_uid)
      .collection('items');

  void start() {
    if (_uid == null || _sub != null) return;
    _sub = _items.snapshots().listen(
      _onSnapshot,
      onError: (Object e) => debugPrint('Sync listener error: $e'),
    );
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  void pushPlane(Plane plane) {
    if (_uid == null) return;
    final data = plane.toJson()..['deleted'] = false;
    _items
        .doc(plane.id)
        .set(data, SetOptions(merge: true))
        .catchError((Object e) => debugPrint('Sync push ${plane.id}: $e'));
  }

  void pushDelete(String id) {
    if (_uid == null) return;
    _items.doc(id).set({
      'id': id,
      'deleted': true,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    }, SetOptions(merge: true)).catchError(
      (Object e) => debugPrint('Sync delete $id: $e'),
    );
  }

  Future<void> _onSnapshot(QuerySnapshot<Map<String, dynamic>> snap) async {
    for (final change in snap.docChanges) {
      final data = change.doc.data();
      if (data != null) {
        await _applyRemote(data);
      }
    }

    // First snapshot after startup: upload anything local the cloud has
    // never seen (items created before sync was enabled, or while a
    // previous launch couldn't sign in).
    if (!_seededLocalOnly) {
      _seededLocalOnly = true;
      final remoteIds = snap.docs.map((d) => d.id).toSet();
      for (final plane in _storage.getAllPlanes()) {
        if (!remoteIds.contains(plane.id)) {
          pushPlane(plane);
        }
      }
    }
  }

  Future<void> _applyRemote(Map<String, dynamic> data) async {
    final id = data['id'] as String?;
    if (id == null) return;

    final local = _storage.getPlane(id);
    final localUpdated = local?.updatedAt;
    final remoteUpdated = DateTime.tryParse(data['updatedAt'] as String? ?? '');

    // Last-write-wins. Equal timestamps mean this is the echo of our own
    // write coming back off the listener — nothing to do.
    final remoteWins = local == null ||
        localUpdated == null ||
        (remoteUpdated != null && remoteUpdated.isAfter(localUpdated));
    if (!remoteWins) return;

    if (data['deleted'] == true) {
      if (local != null) {
        await _storage.removeLocalPlane(id);
      }
      return;
    }

    try {
      await _storage.applyRemotePlane(Plane.fromJson(data));
    } catch (e) {
      debugPrint('Sync: could not apply remote item $id: $e');
    }
  }
}
