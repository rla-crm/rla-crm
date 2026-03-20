import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ─── RLA CRM Sync Service ─────────────────────────────────────────────────────
// Cross-platform sync: Web ↔ Android ↔ iOS share the same data via a
// Cloudflare-hosted REST API backed by Cloudflare KV storage (or Cache API
// fallback with 60-second TTL for cross-datacenter propagation).
//
// API endpoint: https://rlacrm.com/api/sync
// Sync key:     shared secret so only the RLA CRM app can write
//
// Offline-first: Hive is always the primary local store.
// Sync is opportunistic — if the API is unreachable, the app continues
// to work entirely offline, and will sync when connectivity is restored.
// ─────────────────────────────────────────────────────────────────────────────

class SyncService {
  static const String _baseUrl = 'https://rlacrm.com/api/sync';
  static const String _syncKey = 'rla-crm-sync-2024-xK9mP3nQ';
  static const Duration _timeout = Duration(seconds: 15);

  // Availability gate: mark unavailable on failure, retry after 30s (was 2min)
  static bool _available = true;
  static DateTime? _lastFailure;
  static const Duration _retryGap = Duration(seconds: 30);

  // Collections
  static const String kUsers         = 'rla_users';
  static const String kLeads         = 'rla_leads';
  static const String kProjects      = 'rla_projects';
  static const String kApprovals     = 'rla_approvals';
  static const String kNotifications = 'rla_notifications';

  // ── Availability gate ─────────────────────────────────────────────────────
  static bool get isAvailable {
    if (!_available) {
      if (_lastFailure != null &&
          DateTime.now().difference(_lastFailure!) > _retryGap) {
        _available = true; // reset — allow retry
      }
    }
    return _available;
  }

  static void _markUnavailable() {
    _available = false;
    _lastFailure = DateTime.now();
    if (kDebugMode) {
      debugPrint('⚠️ SyncService: marked unavailable for ${_retryGap.inSeconds}s');
    }
  }

  /// Force-reset availability (e.g. after network reconnect)
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
        return true;
      }
    } catch (_) {}
    _markUnavailable();
    return false;
  }

  // ── Fetch all records from a collection ───────────────────────────────────
  static Future<List<Map<String, dynamic>>> fetchAll(String collection) async {
    // Always try even if marked unavailable (reset first)
    if (!isAvailable) {
      // Check if retry gap passed
      if (_lastFailure == null ||
          DateTime.now().difference(_lastFailure!) > _retryGap) {
        _available = true;
      } else {
        return [];
      }
    }
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

  // ── Fetch records updated since a timestamp ───────────────────────────────
  static Future<List<Map<String, dynamic>>> fetchSince(
      String collection, DateTime since) async {
    if (!isAvailable) return [];
    try {
      final sinceStr = Uri.encodeComponent(since.toIso8601String());
      final res = await http
          .get(
            Uri.parse('$_baseUrl?collection=$collection&since=$sinceStr'),
            headers: _headers,
          )
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final records = data['records'] as List? ?? [];
        return records.map((r) => Map<String, dynamic>.from(r as Map)).toList();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ SyncService.fetchSince[$collection]: $e');
      _markUnavailable();
    }
    return [];
  }

  // ── Upsert a record ───────────────────────────────────────────────────────
  static Future<bool> upsert(
      String collection, Map<String, dynamic> record) async {
    // Always attempt upsert even if recently failed (data writes are critical)
    if (!isAvailable) {
      // Reset and try anyway for writes
      if (_lastFailure != null &&
          DateTime.now().difference(_lastFailure!) > const Duration(seconds: 10)) {
        _available = true;
      } else if (!isAvailable) {
        if (kDebugMode) debugPrint('⚠️ SyncService.upsert[$collection]: skipped (unavailable)');
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
      if (res.statusCode == 200) return true;
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

  // ── Pull all cloud data ────────────────────────────────────────────────────
  // Returns merged maps keyed by collection name.
  // Never returns empty map on network errors — returns partial results.
  static Future<Map<String, List<Map<String, dynamic>>>> pullAll() async {
    final result = <String, List<Map<String, dynamic>>>{};
    bool anySuccess = false;

    for (final col in [kUsers, kLeads, kProjects, kApprovals, kNotifications]) {
      final records = await fetchAll(col);
      result[col] = records;
      if (records.isNotEmpty) anySuccess = true;
    }

    if (kDebugMode) {
      debugPrint('✅ SyncService.pullAll: '
          '${result[kUsers]?.length ?? 0} users, '
          '${result[kLeads]?.length ?? 0} leads, '
          '${result[kProjects]?.length ?? 0} projects, '
          '${result[kApprovals]?.length ?? 0} approvals, '
          '${result[kNotifications]?.length ?? 0} notifs'
          '${anySuccess ? "" : " (all empty)"}');
    }

    return result;
  }
}
