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

// ─── RLA CRM Sync Service v7 ──────────────────────────────────────────────────
// Real-time sync architecture:
//
//  1. VERSION POLLING (every 5s, lightweight):
//     GET /api/sync/version → { version, updatedAt }
//     Only fetches the full /all payload when version > lastKnownVersion.
//     Makes change detection essentially free (one integer comparison).
//
//  2. WRITE RETRY QUEUE:
//     Every upsert/delete is added to an in-memory retry queue if it fails.
//     A background timer flushes the queue every 8s.
//     This ensures no write is lost even during brief network hiccups.
//
//  3. IMMEDIATE SYNC TRIGGER:
//     After any successful write, callers can call triggerImmediateSync()
//     to schedule a pull 2s later — so other open tabs/devices see the
//     change within ~2s instead of waiting up to 5s for the next version poll.
//
//  4. DELETED LEDGER (from v6):
//     Every DELETE is recorded server-side. Every /all pull includes the
//     ledger so every client removes those records from local Hive.
// ─────────────────────────────────────────────────────────────────────────────
class SyncService {
  static const String _baseUrl = 'https://rlacrm.com/api/sync';
  static const String _syncKey = 'rla-crm-sync-2024-xK9mP3nQ';
  static const Duration _timeout     = Duration(seconds: 20);
  static const Duration _shortTimeout = Duration(seconds: 8);

  // ── Availability gate ─────────────────────────────────────────────────────
  static bool _available = true;
  static DateTime? _lastFailure;
  static const Duration _retryGap = Duration(seconds: 10);

  // ── Version tracking ──────────────────────────────────────────────────────
  /// Last cloud version number we pulled a full dataset for.
  static int _lastKnownVersion = 0;

  // ── Write retry queue ─────────────────────────────────────────────────────
  static final List<_WriteEntry> _writeQueue = [];
  static Timer? _retryTimer;
  static bool _retryRunning = false;

  // ── Immediate sync callback ───────────────────────────────────────────────
  /// Set by AppState. Called when a write succeeds and we want other
  /// devices to pull quickly.
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

  /// Reset known version so next poll always fetches the full dataset.
  static void resetVersion() => _lastKnownVersion = 0;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'X-Sync-Key': _syncKey,
  };

  // ── Health check ──────────────────────────────────────────────────────────
  static Future<bool> healthCheck() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/health')).timeout(_timeout);
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

  // ── Version poll (lightweight — called every 5s) ──────────────────────────
  // Returns the current cloud version number, or -1 on error.
  // If version > _lastKnownVersion → caller should do a full pullAll.
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
    return -1; // error — caller treats as "unknown, try full pull"
  }

  // ── Pull ALL collections + deleted ledger ────────────────────────────────
  static Future<PullResult> pullAll() async {
    resetAvailability();
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/all'), headers: _headers)
          .timeout(_timeout);

      if (res.statusCode == 200) {
        _available = true;
        final data        = jsonDecode(res.body) as Map<String, dynamic>;
        final collectionsRaw = data['collections'] as Map<String, dynamic>? ?? {};
        final serverVersion  = (data['version'] as num?)?.toInt() ?? 0;

        final collections = <String, List<Map<String, dynamic>>>{};
        for (final col in [kUsers, kLeads, kProjects, kApprovals, kNotifications]) {
          final list = collectionsRaw[col] as List? ?? [];
          collections[col] = list
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList();
        }

        final rawLedger = data['deleted_ledger'] as List? ?? [];
        final deletedLedger = rawLedger
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        // Update known version
        _lastKnownVersion = serverVersion;

        if (kDebugMode) {
          debugPrint('✅ pullAll v$serverVersion: '
              '${collections[kUsers]?.length ?? 0}u '
              '${collections[kLeads]?.length ?? 0}l '
              '${collections[kProjects]?.length ?? 0}p '
              '${deletedLedger.length} deletions');
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

    return PullResult(
      collections: await _pullAllFallback(),
      deletedLedger: [],
    );
  }

  // ── Check if cloud has changed since last pull ────────────────────────────
  // Returns true if a full pullAll is needed, false if data is already current.
  static Future<bool> hasCloudChanged() async {
    if (_lastKnownVersion == 0) return true; // first run — always pull
    final serverVersion = await pollVersion();
    if (serverVersion < 0) return true; // poll failed — pull to be safe
    return serverVersion > _lastKnownVersion;
  }

  // ── Fallback individual fetches ───────────────────────────────────────────
  static Future<Map<String, List<Map<String, dynamic>>>> _pullAllFallback() async {
    final result = <String, List<Map<String, dynamic>>>{};
    for (final col in [kUsers, kLeads, kProjects, kApprovals, kNotifications]) {
      result[col] = await fetchAll(col);
    }
    if (kDebugMode) debugPrint('✅ pullAll fallback: ${result[kUsers]?.length ?? 0}u');
    return result;
  }

  // ── Fetch all records from one collection ─────────────────────────────────
  static Future<List<Map<String, dynamic>>> fetchAll(String collection) async {
    if (!isAvailable) return [];
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl?collection=$collection'), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode == 200) {
        _available = true;
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final records = data['records'] as List? ?? [];
        return records.map((r) => Map<String, dynamic>.from(r as Map)).toList();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ fetchAll[$collection]: $e');
      _markUnavailable();
    }
    return [];
  }

  // ── Upsert with retry queue ───────────────────────────────────────────────
  // Attempts the write immediately. On failure, adds to the retry queue.
  // After a successful write, calls onWriteSuccess to trigger a quick re-sync
  // on this device and notifies other clients via the version bump.
  static Future<bool> upsert(String collection, Map<String, dynamic> record) async {
    final ok = await _attemptUpsert(collection, record);
    if (ok) {
      onWriteSuccess?.call();
    } else {
      // Queue for retry
      _enqueueWrite(_WriteEntry(collection, Map.from(record)));
    }
    return ok;
  }

  static Future<bool> _attemptUpsert(String collection, Map<String, dynamic> record) async {
    if (!isAvailable) {
      if (_lastFailure != null &&
          DateTime.now().difference(_lastFailure!) > const Duration(seconds: 5)) {
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
        // Update known version from response
        try {
          final resp = jsonDecode(res.body) as Map<String, dynamic>;
          final v = (resp['version'] as num?)?.toInt();
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

  // ── Delete with retry queue ───────────────────────────────────────────────
  static Future<bool> delete(String collection, String id) async {
    final ok = await _attemptDelete(collection, id);
    if (ok) {
      onWriteSuccess?.call();
    } else {
      // Queue a sentinel delete record for retry
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
          final v = (resp['version'] as num?)?.toInt();
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
    // Don't duplicate the same record
    if (entry.collection.startsWith('__delete__')) {
      _writeQueue.removeWhere((e) =>
          e.collection == entry.collection && e.record['id'] == entry.record['id']);
    } else {
      _writeQueue.removeWhere((e) =>
          e.collection == entry.collection &&
          e.record['id'] == entry.record['id']);
    }
    _writeQueue.add(entry);
    _startRetryTimer();
  }

  static void _startRetryTimer() {
    _retryTimer ??= Timer.periodic(const Duration(seconds: 8), (_) => _flushQueue());
  }

  static Future<void> _flushQueue() async {
    if (_retryRunning || _writeQueue.isEmpty) return;
    _retryRunning = true;
    final toRetry = List<_WriteEntry>.from(_writeQueue);
    _writeQueue.clear();
    bool anySuccess = false;
    for (final entry in toRetry) {
      if (entry.attempts >= 5) continue; // give up after 5 attempts
      entry.attempts++;
      bool ok;
      if (entry.collection.startsWith('__delete__')) {
        final col = entry.collection.substring('__delete__'.length);
        final id  = entry.record['id'] as String;
        ok = await _attemptDelete(col, id);
      } else {
        ok = await _attemptUpsert(entry.collection, entry.record);
      }
      if (!ok && entry.attempts < 5) {
        _writeQueue.add(entry); // re-queue for next retry
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

  // ── Bulk push ─────────────────────────────────────────────────────────────
  static Future<void> pushAll({
    required List<Map<String, dynamic>> users,
    required List<Map<String, dynamic>> leads,
    required List<Map<String, dynamic>> projects,
    required List<Map<String, dynamic>> approvals,
    required List<Map<String, dynamic>> notifications,
  }) async {
    resetAvailability();
    final batches = {
      kUsers: users, kLeads: leads, kProjects: projects,
      kApprovals: approvals, kNotifications: notifications,
    };
    for (final entry in batches.entries) {
      for (final record in entry.value) {
        await upsert(entry.key, record);
      }
    }
    if (kDebugMode) debugPrint('✅ pushAll complete');
  }

  // ── Delete all records in a collection except a specific ID ───────────────
  /// Fetches every record in [collection] from the cloud and deletes each one
  /// whose id != [keepId].  Returns the number of records deleted.
  static Future<int> deleteAllExcept(String collection, {String? keepId}) async {
    if (!isAvailable) {
      resetAvailability(); // try once more
    }
    try {
      final records = await fetchAll(collection);
      int deleted = 0;
      for (final record in records) {
        final id = record['id'] as String?;
        if (id == null) continue;
        if (keepId != null && id == keepId) continue;
        final ok = await _attemptDelete(collection, id);
        if (ok) deleted++;
      }
      if (kDebugMode) debugPrint('✅ deleteAllExcept[$collection]: deleted $deleted records');
      return deleted;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ deleteAllExcept[$collection]: $e');
      return 0;
    }
  }

  // ── Full platform flush (keeps one user record) ───────────────────────────
  /// Deletes every record from every collection on the cloud, except the
  /// master admin user record identified by [masterAdminId].
  /// Returns a summary map of {collection: countDeleted}.
  static Future<Map<String, int>> flushCloudExceptMasterAdmin({
    required String masterAdminId,
  }) async {
    resetAvailability();
    _writeQueue.clear(); // cancel any pending writes so they don't restore data
    final result = <String, int>{};
    result[kUsers]         = await deleteAllExcept(kUsers, keepId: masterAdminId);
    result[kLeads]         = await deleteAllExcept(kLeads);
    result[kProjects]      = await deleteAllExcept(kProjects);
    result[kApprovals]     = await deleteAllExcept(kApprovals);
    result[kNotifications] = await deleteAllExcept(kNotifications);
    resetVersion(); // force a full re-pull on next poll
    if (kDebugMode) {
      debugPrint('🧹 flushCloudExceptMasterAdmin complete: '
          '${result[kUsers]}u ${result[kLeads]}l ${result[kProjects]}p '
          '${result[kApprovals]}a ${result[kNotifications]}n deleted');
    }
    return result;
  }
}
