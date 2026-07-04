import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/plane.dart';
import 'image_store.dart';
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
/// - Photos go to Firebase Storage at `users/{uid}/scans/<basename>`. The
///   uploading device stamps the download URL on [Plane.imageUrl]; other
///   devices download into their own local scans/ dir on first sight.
class SyncService {
  SyncService(this._storage);

  final StorageService _storage;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  bool _seededLocalOnly = false;
  final Set<String> _uploading = {};
  final Set<String> _downloading = {};

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
    _maybeUploadImage(plane);
  }

  void pushDelete(String id, {String? imagePath}) {
    if (_uid == null) return;
    _items.doc(id).set({
      'id': id,
      'deleted': true,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    }, SetOptions(merge: true)).catchError(
      (Object e) => debugPrint('Sync delete $id: $e'),
    );
    if (imagePath != null && !imagePath.startsWith('assets/')) {
      unawaited(_deleteCloudImage(id, imagePath));
    }
  }

  Future<void> _deleteCloudImage(String id, String imagePath) async {
    try {
      await _imageRef(imagePath).delete();
    } catch (e) {
      // Usually just "object not found" — the photo never got uploaded.
      debugPrint('Cloud image delete $id: $e');
    }
  }

  /// Photos live at `users/{uid}/scans/<basename>` regardless of whether
  /// the local imagePath is a relative token or a legacy absolute path.
  Reference _imageRef(String imagePath) {
    final basename = imagePath.substring(imagePath.lastIndexOf('/') + 1);
    return FirebaseStorage.instance.ref('users/$_uid/scans/$basename');
  }

  void _maybeUploadImage(Plane plane) {
    if (_uid == null ||
        plane.imageUrl != null ||
        plane.imagePath.startsWith('assets/')) {
      return;
    }
    final file = File(ImageStore.resolve(plane.imagePath));
    if (!file.existsSync() || !_uploading.add(plane.id)) return;

    unawaited(_uploadImage(plane.id, file, _imageRef(plane.imagePath)));
  }

  Future<void> _uploadImage(String id, File file, Reference ref) async {
    try {
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      // Re-fetch: the item may have been edited (or deleted) meanwhile.
      final current = _storage.getPlane(id);
      if (current != null && current.imageUrl == null) {
        current.imageUrl = url;
        await _storage.updatePlane(current);
      }
    } catch (e) {
      debugPrint('Image upload $id: $e');
    } finally {
      _uploading.remove(id);
    }
  }

  Future<void> _maybeDownloadImage(Plane plane) async {
    final url = plane.imageUrl;
    if (url == null || plane.imagePath.startsWith('assets/')) return;
    final target = File(ImageStore.resolve(plane.imagePath));
    if (target.existsSync() || !_downloading.add(plane.id)) return;

    try {
      await FirebaseStorage.instance.refFromURL(url).writeToFile(target);
      // Re-put the record so box listeners rebuild now that the file exists.
      final current = _storage.getPlane(plane.id);
      if (current != null) {
        await _storage.applyRemotePlane(current);
      }
    } catch (e) {
      debugPrint('Image download ${plane.id}: $e');
      // Don't let a partial file block a retry on the next snapshot.
      if (target.existsSync()) {
        await target.delete();
      }
    } finally {
      _downloading.remove(plane.id);
    }
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
        } else if (plane.imageUrl == null) {
          // Known to the cloud but the photo upload never finished
          // (e.g. the app was killed mid-upload) — retry it.
          _maybeUploadImage(plane);
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
      final plane = Plane.fromJson(data);
      await _storage.applyRemotePlane(plane);
      unawaited(_maybeDownloadImage(plane));
    } catch (e) {
      debugPrint('Sync: could not apply remote item $id: $e');
    }
  }
}
