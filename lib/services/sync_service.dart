import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ─── RLA CRM Sync Service ─────────────────────────────────────────────────────
// Globally persistent cross-platform sync via JSONBlob.com + Cloudflare Pages.
//
// Architecture:
//   - JSONBlob.com stores ALL data as a single JSON blob (globally persistent)
//   - Cloudflare Pages Function acts as a secure proxy for write auth
//   - Flutter app reads/writes through the CF proxy at https://rlacrm.com/api/sync
//   - Single-request "pullAll" via /api/sync/all fetches everything at once
//
// Why this works globally:
//   JSONBlob.com is backed by Cloudflare's global network but uses a central
//   datastore — unlike CF Cache API which is per-datacenter. Any write is
//   immediately visible to ALL readers worldwide.
//
// Offline-first: Hive is always the primary local store.
// Sync is opportunistic — app works offline and syncs when connected.
// ─────────────────────────────────────────────────────────────────────────────

class SyncService {
  static const String _baseUrl = 'https://rlacrm.com/api/sync';
  static const String _syncKey = 'rla-crm-sync-2024-xK9mP3nQ';
  static const Duration _timeout = Duration(seconds: 20);

  // Availability gate: reduce unavailability window to 10 seconds
  static bool _available = true;
  static DateTime? _lastFailure;
  static const Duration _retryGap = Duration(seconds: 10);

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
    if (kDebugMode) {
      debugPrint('⚠️ SyncService: unavailable for ${_retryGap.inSeconds}s');
    }
  }

  /// Force-reset availability (called on app resume / manual refresh)
  static void resetAvailability() {
    _available = true;
    _lastFailure = null;
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'X-Sync-Key': _syncKey,
  };

  // ── Health check ──────────────────────────────────────────────────────────
  static Future<bool> healthCheck() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(_timeout);
      if (res.statusCode == 200) {
        _available = true;
        if (kDebugMode) {
          final data = jsonDecode(res.body);
          debugPrint('✅ Sync health: ${data['storage']}');
        }
        return true;
      }
    } catch (_) {}
    _markUnavailable();
    return false;
  }

  // ── Pull ALL collections in a single HTTP request ─────────────────────────
  // Much more efficient than 5 separate requests.
  // Returns map of collection → list of records.
  static Future<Map<String, List<Map<String, dynamic>>>> pullAll() async {
    resetAvailability(); // always try on pullAll (called during init/login)
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/all'),
            headers: _headers,
          )
          .timeout(_timeout);

      if (res.statusCode == 200) {
        _available = true;
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final collections = data['collections'] as Map<String, dynamic>? ?? {};

        final result = <String, List<Map<String, dynamic>>>{};
        for (final col in [kUsers, kLeads, kProjects, kApprovals, kNotifications]) {
          final list = collections[col] as List? ?? [];
          result[col] = list
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList();
        }

        if (kDebugMode) {
          debugPrint('✅ SyncService.pullAll (single request): '
              '${result[kUsers]?.length ?? 0} users, '
              '${result[kLeads]?.length ?? 0} leads, '
              '${result[kProjects]?.length ?? 0} projects, '
              '${result[kApprovals]?.length ?? 0} approvals, '
              '${result[kNotifications]?.length ?? 0} notifs');
        }
        return result;
      }

      if (kDebugMode) debugPrint('⚠️ SyncService.pullAll: HTTP ${res.statusCode}');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ SyncService.pullAll error: $e');
      _markUnavailable();
    }

    // Fallback: try individual collection fetches
    return await _pullAllFallback();
  }

  // ── Fallback: fetch collections individually ──────────────────────────────
  static Future<Map<String, List<Map<String, dynamic>>>> _pullAllFallback() async {
    final result = <String, List<Map<String, dynamic>>>{};
    for (final col in [kUsers, kLeads, kProjects, kApprovals, kNotifications]) {
      result[col] = await fetchAll(col);
    }
    if (kDebugMode) {
      debugPrint('✅ SyncService.pullAll (fallback): '
          '${result[kUsers]?.length ?? 0} users');
    }
    return result;
  }

  // ── Fetch all records from a single collection ───────────────────────────
  static Future<List<Map<String, dynamic>>> fetchAll(String collection) async {
    if (!isAvailable) return [];
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl?collection=$collection'),
            headers: _headers,
          )
          .timeout(_timeout);
      if (res.statusCode == 200) {
        _available = true;
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final records = data['records'] as List? ?? [];
        return records.map((r) => Map<String, dynamic>.from(r as Map)).toList();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ SyncService.fetchAll[$collection]: $e');
      _markUnavailable();
    }
    return [];
  }

  // ── Upsert a record ───────────────────────────────────────────────────────
  // Always attempts write — data writes are critical.
  static Future<bool> upsert(
      String collection, Map<String, dynamic> record) async {
    // Reset availability for writes — always attempt
    if (!isAvailable) {
      if (_lastFailure != null &&
          DateTime.now().difference(_lastFailure!) > const Duration(seconds: 5)) {
        _available = true;
      } else {
        // Queue will retry on next sync cycle
        if (kDebugMode) debugPrint('⚠️ SyncService.upsert[$collection]: deferred');
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
        if (kDebugMode) debugPrint('✅ sync upsert [$collection] ${record['id']}');
        return true;
      }
      if (kDebugMode) debugPrint('⚠️ SyncService.upsert[$collection]: HTTP ${res.statusCode}');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ SyncService.upsert[$collection]: $e');
      _markUnavailable();
    }
    return false;
  }

  // ── Delete a record ───────────────────────────────────────────────────────
  static Future<bool> delete(String collection, String id) async {
    if (!isAvailable) return false;
    try {
      final res = await http
          .delete(
            Uri.parse('$_baseUrl?collection=$collection&id=$id'),
            headers: _headers,
          )
          .timeout(_timeout);
      if (res.statusCode == 200) {
        if (kDebugMode) debugPrint('✅ sync delete [$collection] $id');
        return true;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ SyncService.delete[$collection]: $e');
      _markUnavailable();
    }
    return false;
  }

  // ── Bulk push all local data to cloud ─────────────────────────────────────
  static Future<void> pushAll({
    required List<Map<String, dynamic>> users,
    required List<Map<String, dynamic>> leads,
    required List<Map<String, dynamic>> projects,
    required List<Map<String, dynamic>> approvals,
    required List<Map<String, dynamic>> notifications,
  }) async {
    resetAvailability();
    final batches = {
      kUsers: users,
      kLeads: leads,
      kProjects: projects,
      kApprovals: approvals,
      kNotifications: notifications,
    };
    for (final entry in batches.entries) {
      for (final record in entry.value) {
        await upsert(entry.key, record);
      }
    }
    if (kDebugMode) debugPrint('✅ SyncService.pushAll complete');
  }
}
