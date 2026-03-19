import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ─── RLA CRM Sync Service ─────────────────────────────────────────────────────
// Cross-platform sync: Web ↔ Android ↔ iOS share the same data via a
// Cloudflare-hosted REST API backed by Cloudflare KV storage.
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
  static const Duration _timeout = Duration(seconds: 10);

  static bool _available = true;        // optimistic — flipped false on failures
  static DateTime? _lastFailure;
  static const Duration _retryGap = Duration(minutes: 2);

  // Collections
  static const String kUsers         = 'rla_users';
  static const String kLeads         = 'rla_leads';
  static const String kProjects      = 'rla_projects';
  static const String kApprovals     = 'rla_approvals';
  static const String kNotifications = 'rla_notifications';

  // ── Availability gate ─────────────────────────────────────────────────────
  static bool get isAvailable {
    if (!_available) {
      // Retry after _retryGap
      if (_lastFailure != null &&
          DateTime.now().difference(_lastFailure!) > _retryGap) {
        _available = true;
      }
    }
    return _available;
  }

  static void _markUnavailable() {
    _available = false;
    _lastFailure = DateTime.now();
    if (kDebugMode) debugPrint('⚠️ SyncService: marked unavailable until ${_lastFailure!.add(_retryGap)}');
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
    if (!isAvailable) return [];
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl?collection=$collection'), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode == 200) {
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
    if (!isAvailable) return false;
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl?collection=$collection'),
            headers: _headers,
            body: jsonEncode(record),
          )
          .timeout(_timeout);
      if (res.statusCode == 200) return true;
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

  // ── Bulk push all local data to cloud ────────────────────────────────────
  static Future<void> pushAll({
    required List<Map<String, dynamic>> users,
    required List<Map<String, dynamic>> leads,
    required List<Map<String, dynamic>> projects,
    required List<Map<String, dynamic>> approvals,
    required List<Map<String, dynamic>> notifications,
  }) async {
    if (!isAvailable) return;

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

  // ── Pull all cloud data and merge into local ───────────────────────────────
  // Returns merged maps keyed by collection name
  static Future<Map<String, List<Map<String, dynamic>>>> pullAll() async {
    if (!isAvailable) {
      if (kDebugMode) debugPrint('⚠️ SyncService.pullAll: skipped (unavailable)');
      return {};
    }

    final result = <String, List<Map<String, dynamic>>>{};

    for (final col in [kUsers, kLeads, kProjects, kApprovals, kNotifications]) {
      result[col] = await fetchAll(col);
    }

    if (kDebugMode) {
      debugPrint('✅ SyncService.pullAll: '
          '${result[kUsers]?.length ?? 0} users, '
          '${result[kLeads]?.length ?? 0} leads, '
          '${result[kProjects]?.length ?? 0} projects, '
          '${result[kApprovals]?.length ?? 0} approvals, '
          '${result[kNotifications]?.length ?? 0} notifs');
    }

    return result;
  }
}
