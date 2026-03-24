import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ─── PullResult ──────────────────────────────────────────────────────────────
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

// ─── WriteEntry — queued write for retry ─────────────────────────────────────
class _WriteEntry {
  final String collection;
  final Map<String, dynamic> record;
  int attempts;
  _WriteEntry(this.collection, this.record) : attempts = 0;
}

// ─── RLA CRM Sync Service v10 ─────────────────────────────────────────────────
//
// ARCHITECTURE: CLOUD IS THE SINGLE SOURCE OF TRUTH
//
//  All data lives on the cloud. Hive is used ONLY as a short-lived session
//  cache to survive page refreshes in the same browser session — it is NEVER
//  used as a conflicting database and is NEVER pushed back to the cloud.
//
//  Write flow:
//    1. Write to cloud (POST /api/sync)
//    2. On success → update in-memory lists directly
//    3. On failure → queue for retry; UI shows stale data until retry succeeds
//
//  Read flow (every 3 seconds, lightweight version poll):
//    1. GET /api/sync/version → compare with lastKnownVersion
//    2. If changed → GET /api/sync/all → replace in-memory lists entirely
//    3. Hive is updated purely so a page-refresh doesn't show a blank screen
//       for the ~1s before the first cloud pull completes
//
//  Key properties:
//    - No bidirectional merge — cloud always wins
//    - No tombstone sets — deleted records simply disappear from cloud
//    - No local-only push-back — Hive is never used as upload source
//    - Any device sees any change within ≤3 seconds
// ─────────────────────────────────────────────────────────────────────────────
class SyncService {
  static const String _baseUrl = 'https://rlacrm.com/api/sync';
  static const String _syncKey = 'rla-crm-sync-2024-xK9mP3nQ';
  static const Duration _timeout      = Duration(seconds: 15);
  static const Duration _shortTimeout = Duration(seconds: 6);

  // ── Availability gate ─────────────────────────────────────────────────────
  static bool _available = true;
  static DateTime? _lastFailure;
  static const Duration _retryGap = Duration(seconds: 8);

  // ── Version tracking ──────────────────────────────────────────────────────
  static int _lastKnownVersion = 0;

  // ── Write retry queue ─────────────────────────────────────────────────────
  static final List<_WriteEntry> _writeQueue = [];
  static Timer? _retryTimer;
  static bool _retryRunning = false;

  // ── Post-write callback ───────────────────────────────────────────────────
  /// Called by AppState after wiring up. Triggered whenever a cloud write
  /// succeeds so AppState can schedule an immediate re-pull.
  static VoidCallback? onWriteSuccess;

  // Collections
  static const String kUsers         = 'rla_users';
  static const String kLeads         = 'rla_leads';
  static const String kProjects      = 'rla_projects';
  static const String kApprovals     = 'rla_approvals';
  static const String kNotifications = 'rla_notifications';

  // ── Availability gate ─────────────────────────────────────────────────────
  static bool get isAvailable {
    if (!_available && _lastFailure != null &&
        DateTime.now().difference(_lastFailure!) > _retryGap) {
      _available = true;
    }
    return _available;
  }

  static void _markUnavailable() {
    _available = false;
    _lastFailure = DateTime.now();
    if (kDebugMode) debugPrint('⚠️ SyncService: unavailable for ${_retryGap.inSeconds}s');
  }

  static void resetAvailability() {
    _available = true;
    _lastFailure = null;
  }

  static void resetVersion() => _lastKnownVersion = 0;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'X-Sync-Key': _syncKey,
  };

  // ── Health check ──────────────────────────────────────────────────────────
  static Future<bool> healthCheck() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/health'), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode == 200) {
        _available = true;
        if (kDebugMode) {
          final data = jsonDecode(res.body);
          debugPrint('✅ Sync health v${data['syncVersion']}: ${data['service']}');
        }
        return true;
      }
    } catch (_) {}
    _markUnavailable();
    return false;
  }

  // ── Version poll (lightweight — called every 3s) ──────────────────────────
  static Future<int> pollVersion() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/version'), headers: _headers)
          .timeout(_shortTimeout);
      if (res.statusCode == 200) {
        _available = true;
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (data['version'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}
    return -1;
  }

  // ── Pull ALL collections from cloud ───────────────────────────────────────
  // Returns the complete authoritative cloud state. AppState replaces its
  // in-memory lists entirely from this result — no merging.
  static Future<PullResult> pullAll() async {
    resetAvailability();
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/all'), headers: _headers)
          .timeout(_timeout);

      if (res.statusCode == 200) {
        _available = true;
        final data           = jsonDecode(res.body) as Map<String, dynamic>;
        final collectionsRaw = data['collections'] as Map<String, dynamic>? ?? {};
        final serverVersion  = (data['version'] as num?)?.toInt() ?? 0;

        final collections = <String, List<Map<String, dynamic>>>{};
        for (final col in [kUsers, kLeads, kProjects, kApprovals, kNotifications]) {
          final list = collectionsRaw[col] as List? ?? [];
          collections[col] = list
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList();
        }

        // deleted_ledger still returned for compatibility but AppState no
        // longer uses tombstones — cloud data is simply replaced wholesale.
        final rawLedger    = data['deleted_ledger'] as List? ?? [];
        final deletedLedger = rawLedger
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        _lastKnownVersion = serverVersion;

        if (kDebugMode) {
          debugPrint('☁️ pullAll v$serverVersion: '
              '${collections[kUsers]?.length ?? 0}u '
              '${collections[kLeads]?.length ?? 0}l '
              '${collections[kProjects]?.length ?? 0}p '
              '${collections[kApprovals]?.length ?? 0}a '
              '${collections[kNotifications]?.length ?? 0}n');
        }
        return PullResult(
          collections: collections,
          deletedLedger: deletedLedger,
          version: serverVersion,
        );
      }
      if (kDebugMode) debugPrint('⚠️ pullAll: HTTP ${res.statusCode}');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ pullAll error: $e');
      _markUnavailable();
    }
    // On failure return empty — AppState will keep showing last known state
    return const PullResult(collections: {}, deletedLedger: [], version: -1);
  }

  // ── Has cloud changed since last pull? ────────────────────────────────────
  static Future<bool> hasCloudChanged() async {
    if (_lastKnownVersion == 0) return true;
    final v = await pollVersion();
    if (v < 0) return true; // poll failed — pull to be safe
    return v > _lastKnownVersion;
  }

  // ── Fetch single collection ───────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> fetchAll(String collection) async {
    if (!isAvailable) return [];
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl?collection=$collection'), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode == 200) {
        _available = true;
        final data    = jsonDecode(res.body) as Map<String, dynamic>;
        final records = data['records'] as List? ?? [];
        return records.map((r) => Map<String, dynamic>.from(r as Map)).toList();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ fetchAll[$collection]: $e');
      _markUnavailable();
    }
    return [];
  }

  // ── Upsert (cloud-first write) ────────────────────────────────────────────
  // Writes immediately to cloud. On success updates _lastKnownVersion and
  // fires onWriteSuccess so all devices can pull the new state quickly.
  // On failure queues for background retry — caller's in-memory state is
  // already updated optimistically so the UI stays responsive.
  static Future<bool> upsert(String collection, Map<String, dynamic> record) async {
    final ok = await _attemptUpsert(collection, record);
    if (ok) {
      onWriteSuccess?.call();
    } else {
      _enqueueWrite(_WriteEntry(collection, Map.from(record)));
    }
    return ok;
  }

  static Future<bool> _attemptUpsert(String collection, Map<String, dynamic> record) async {
    if (!isAvailable) {
      // Allow immediate retry after retryGap even if marked unavailable
      if (_lastFailure != null &&
          DateTime.now().difference(_lastFailure!) > const Duration(seconds: 4)) {
        _available = true;
      } else {
        if (kDebugMode) debugPrint('⚠️ upsert[$collection]: deferred (unavailable)');
        return false;
      }
    }
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl?collection=$collection'),
            headers: _headers,
            body: jsonEncode(record),
          )
          .timeout(_timeout);
      if (res.statusCode == 200) {
        _available = true;
        try {
          final resp = jsonDecode(res.body) as Map<String, dynamic>;
          final v    = (resp['version'] as num?)?.toInt();
          if (v != null && v > _lastKnownVersion) _lastKnownVersion = v;
        } catch (_) {}
        if (kDebugMode) debugPrint('✅ upsert [$collection] ${record['id']}');
        return true;
      }
      if (kDebugMode) debugPrint('⚠️ upsert[$collection]: HTTP ${res.statusCode}');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ upsert[$collection]: $e');
      _markUnavailable();
    }
    return false;
  }

  // ── Delete (cloud-first) ──────────────────────────────────────────────────
  static Future<bool> delete(String collection, String id) async {
    final ok = await _attemptDelete(collection, id);
    if (ok) {
      onWriteSuccess?.call();
    } else {
      _enqueueWrite(_WriteEntry('__delete__$collection', {'id': id}));
    }
    return ok;
  }

  static Future<bool> _attemptDelete(String collection, String id) async {
    if (!isAvailable) return false;
    try {
      final res = await http
          .delete(
            Uri.parse('$_baseUrl?collection=$collection&id=$id'),
            headers: _headers,
          )
          .timeout(_timeout);
      if (res.statusCode == 200) {
        _available = true;
        try {
          final resp = jsonDecode(res.body) as Map<String, dynamic>;
          final v    = (resp['version'] as num?)?.toInt();
          if (v != null && v > _lastKnownVersion) _lastKnownVersion = v;
        } catch (_) {}
        if (kDebugMode) debugPrint('✅ delete [$collection] $id');
        return true;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ delete[$collection]: $e');
      _markUnavailable();
    }
    return false;
  }

  // ── Write retry queue ─────────────────────────────────────────────────────
  static void _enqueueWrite(_WriteEntry entry) {
    // Deduplicate: newer write for same id replaces old one
    _writeQueue.removeWhere((e) =>
        e.collection == entry.collection &&
        e.record['id'] == entry.record['id']);
    _writeQueue.add(entry);
    _startRetryTimer();
  }

  static void _startRetryTimer() {
    _retryTimer ??= Timer.periodic(const Duration(seconds: 5), (_) => _flushQueue());
  }

  static Future<void> _flushQueue() async {
    if (_retryRunning || _writeQueue.isEmpty) return;
    _retryRunning = true;
    final toRetry = List<_WriteEntry>.from(_writeQueue);
    _writeQueue.clear();
    bool anySuccess = false;
    for (final entry in toRetry) {
      if (entry.attempts >= 8) continue; // give up after 8 attempts (~40s)
      entry.attempts++;
      bool ok;
      if (entry.collection.startsWith('__delete__')) {
        final col = entry.collection.substring('__delete__'.length);
        final id  = entry.record['id'] as String;
        ok = await _attemptDelete(col, id);
      } else {
        ok = await _attemptUpsert(entry.collection, entry.record);
      }
      if (!ok && entry.attempts < 8) {
        _writeQueue.add(entry);
      } else if (ok) {
        anySuccess = true;
      }
    }
    if (anySuccess) onWriteSuccess?.call();
    _retryRunning = false;
  }

  static void stopRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _writeQueue.clear();
  }

  // ── Delete all records in a collection except one ID ─────────────────────
  static Future<int> deleteAllExcept(String collection, {String? keepId}) async {
    resetAvailability();
    try {
      final records = await fetchAll(collection);
      int deleted = 0;
      for (final record in records) {
        final id = record['id'] as String?;
        if (id == null || id == keepId) continue;
        final ok = await _attemptDelete(collection, id);
        if (ok) deleted++;
      }
      if (kDebugMode) debugPrint('✅ deleteAllExcept[$collection]: deleted $deleted');
      return deleted;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ deleteAllExcept[$collection]: $e');
      return 0;
    }
  }

  // ── Full platform flush (keeps master admin) ──────────────────────────────
  static Future<Map<String, int>> flushCloudExceptMasterAdmin({
    required String masterAdminId,
  }) async {
    resetAvailability();
    _writeQueue.clear();
    final result = <String, int>{};
    result[kUsers]         = await deleteAllExcept(kUsers, keepId: masterAdminId);
    result[kLeads]         = await deleteAllExcept(kLeads);
    result[kProjects]      = await deleteAllExcept(kProjects);
    result[kApprovals]     = await deleteAllExcept(kApprovals);
    result[kNotifications] = await deleteAllExcept(kNotifications);
    resetVersion();
    if (kDebugMode) {
      debugPrint('🧹 flushCloud complete: '
          '${result[kUsers]}u ${result[kLeads]}l ${result[kProjects]}p deleted');
    }
    return result;
  }
}
