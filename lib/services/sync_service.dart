import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// ─── RLA CRM Sync Service v15 — Firebase Firestore ───────────────────────────
//
// ARCHITECTURE: Firebase Firestore is the single source of truth.
//
//  Write flow:
//    1. Write to Firestore (set/merge on collection/docId)
//    2. On success → onWriteSuccess callback fires → triggers re-pull
//
//  Read flow (real-time stream + 3-second version poll fallback):
//    1. Firestore real-time snapshots push changes automatically
//    2. AppState replaces in-memory lists on every snapshot
//
//  Collections:  rla_users | rla_leads | rla_projects | rla_approvals | rla_notifications
// ─────────────────────────────────────────────────────────────────────────────

class PullResult {
  final Map<String, List<Map<String, dynamic>>> collections;
  final List<Map<String, dynamic>> deletedLedger;
  final int version;
  const PullResult({
    required this.collections,
    required this.deletedLedger,
    this.version = 0,
  });
}

class SyncService {
  static const String kUsers         = 'rla_users';
  static const String kLeads         = 'rla_leads';
  static const String kProjects      = 'rla_projects';
  static const String kApprovals     = 'rla_approvals';
  static const String kNotifications = 'rla_notifications';

  static final List<String> _collections = [
    kUsers, kLeads, kProjects, kApprovals, kNotifications,
  ];

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  // Callback fired after every successful write
  static VoidCallback? onWriteSuccess;

  // ── Upsert a single record ────────────────────────────────────────────────
  static Future<bool> upsert(String collection, Map<String, dynamic> record) async {
    try {
      final id = record['id'] as String?;
      if (id == null || id.isEmpty) {
        if (kDebugMode) debugPrint('⚠️ upsert[$collection]: missing id');
        return false;
      }
      // Remove placeholder if present
      final data = Map<String, dynamic>.from(record);
      await _db.collection(collection).doc(id).set(data, SetOptions(merge: true));
      if (kDebugMode) debugPrint('✅ upsert [$collection] $id');
      onWriteSuccess?.call();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ upsert[$collection] error: $e');
      return false;
    }
  }

  // ── Delete a single record ────────────────────────────────────────────────
  static Future<bool> delete(String collection, String id) async {
    try {
      await _db.collection(collection).doc(id).delete();
      if (kDebugMode) debugPrint('🗑️ delete [$collection] $id');
      onWriteSuccess?.call();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ delete[$collection] error: $e');
      return false;
    }
  }

  // ── Pull ALL collections from Firestore ───────────────────────────────────
  static Future<PullResult> pullAll() async {
    try {
      final results = await Future.wait(
        _collections.map((col) => _fetchCollection(col)),
      );
      final collections = <String, List<Map<String, dynamic>>>{};
      for (int i = 0; i < _collections.length; i++) {
        collections[_collections[i]] = results[i];
      }
      if (kDebugMode) {
        debugPrint('☁️ pullAll: '
            '${collections[kUsers]?.length ?? 0}u '
            '${collections[kLeads]?.length ?? 0}l '
            '${collections[kProjects]?.length ?? 0}p '
            '${collections[kApprovals]?.length ?? 0}a '
            '${collections[kNotifications]?.length ?? 0}n');
      }
      return PullResult(
        collections: collections,
        deletedLedger: [],
        version: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ pullAll error: $e');
      return const PullResult(collections: {}, deletedLedger: [], version: -1);
    }
  }

  // ── Check if a doc is a real data record (not an init/placeholder doc) ─────
  static bool _isRealDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    // Skip the _init sentinel doc used during collection creation
    if (d.id == '_init') return false;
    final data = d.data();
    if (data == null) return false;
    // Skip docs explicitly marked as placeholders
    if (data['_placeholder'] == true) return false;
    // Skip docs that have no 'id' field AND no recognisable content
    // (extra safety net for any other sentinel documents)
    final hasId = data.containsKey('id') && data['id'] != null && data['id'].toString().isNotEmpty;
    final hasName = data.containsKey('name') || data.containsKey('email') ||
        data.containsKey('title') || data.containsKey('applicantName');
    return hasId || hasName;
  }

  // ── Fetch a single collection, skipping placeholder docs ─────────────────
  static Future<List<Map<String, dynamic>>> _fetchCollection(String col) async {
    final snap = await _db.collection(col).get();
    return snap.docs
        .where(_isRealDoc)
        .map((d) {
          final data = Map<String, dynamic>.from(d.data()!);
          if (!data.containsKey('id') || data['id'] == null) data['id'] = d.id;
          return data;
        })
        .toList();
  }

  // ── Real-time stream for a collection ────────────────────────────────────
  static Stream<List<Map<String, dynamic>>> watchCollection(String col) {
    return _db.collection(col).snapshots().map((snap) {
      return snap.docs
          .where(_isRealDoc)
          .map((d) {
            final data = Map<String, dynamic>.from(d.data()!);
            if (!data.containsKey('id') || data['id'] == null) data['id'] = d.id;
            return data;
          })
          .toList();
    });
  }

  // ── Health check ──────────────────────────────────────────────────────────
  static Future<bool> healthCheck() async {
    try {
      await _db.collection(kUsers).limit(1).get();
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Delete all records except one (for flush feature) ────────────────────
  static Future<void> deleteAllExcept(String collection, String keepId) async {
    final snap = await _db.collection(collection).get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      if (doc.id != keepId && doc.id != '_init') {
        batch.delete(doc.reference);
      }
    }
    await batch.commit();
    if (kDebugMode) debugPrint('🗑️ deleteAllExcept[$collection] kept=$keepId');
  }

  // ── Flush entire cloud except master admin ────────────────────────────────
  static Future<void> flushCloudExceptMasterAdmin(String masterAdminId) async {
    await Future.wait([
      deleteAllExcept(kUsers, masterAdminId),
      _deleteAll(kLeads),
      _deleteAll(kProjects),
      _deleteAll(kApprovals),
      _deleteAll(kNotifications),
    ]);
    if (kDebugMode) debugPrint('🔥 Cloud flushed — only $masterAdminId remains');
  }

  static Future<void> _deleteAll(String collection) async {
    final snap = await _db.collection(collection).get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      if (doc.id != '_init') batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ── No-op stubs kept for compatibility with app_state.dart ───────────────
  static void resetVersion() {}
  static void resetAvailability() {}
  static bool get isAvailable => true;
  static void stopRetryTimer() {}
  static Future<bool> hasCloudChanged() async => true;
}
