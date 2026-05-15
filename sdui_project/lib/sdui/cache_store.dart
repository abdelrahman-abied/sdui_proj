import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One cached SDUI response that survives an app restart.
///
/// [storedAt] + [maxAgeSeconds] together implement server-driven TTL — the
/// server's `Cache-Control: max-age=N` tells the client how long the body is
/// trusted before a foreground revalidation is required. A null [maxAgeSeconds]
/// means "no expiry hint" and the entry stays fresh until evicted.
class CachedResponse {
  CachedResponse({
    required this.data,
    this.etag,
    this.storedAt,
    this.maxAgeSeconds,
  });
  final Map<String, dynamic> data;
  final String? etag;
  final int? storedAt;
  final int? maxAgeSeconds;

  bool isExpired({DateTime? now}) {
    if (storedAt == null || maxAgeSeconds == null) return false;
    final current = (now ?? DateTime.now()).millisecondsSinceEpoch;
    // `>=` so a `max-age=0` directive (HTTP "must-revalidate") fires every
    // read — strict `>` would let a same-millisecond second fetch serve a
    // body the server already told us is stale.
    return current - storedAt! >= maxAgeSeconds! * 1000;
  }

  Map<String, dynamic> _toJson() => {
        'data': data,
        if (etag != null) 'etag': etag,
        if (storedAt != null) 'storedAt': storedAt,
        if (maxAgeSeconds != null) 'maxAge': maxAgeSeconds,
      };

  static CachedResponse? _tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final data = raw['data'];
    if (data is! Map) return null;
    return CachedResponse(
      data: Map<String, dynamic>.from(data),
      etag: raw['etag'] as String?,
      storedAt: raw['storedAt'] as int?,
      maxAgeSeconds: raw['maxAge'] as int?,
    );
  }
}

/// Disk-backed mirror of the in-memory SDUI cache.
///
/// We serialize the whole map under one key. The cache is small (a handful of
/// screens) so the cost of rewriting the blob on each [save] is negligible,
/// and we get atomic writes for free. Anything stored is treated as
/// best-effort — a corrupted blob is silently dropped on [load].
class CacheStore {
  static const _kCacheKey = 'sdui.cache.v1';

  /// Reads the persisted cache. Returns an empty map if nothing is stored or
  /// the blob is malformed. Never throws.
  static Future<Map<String, CachedResponse>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCacheKey);
      if (raw == null) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <String, CachedResponse>{};
      for (final entry in decoded.entries) {
        final parsed = CachedResponse._tryFromJson(entry.value);
        if (parsed != null) out[entry.key.toString()] = parsed;
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  /// Writes the cache snapshot to disk. Errors are swallowed — failing to
  /// persist should never break a fetch.
  static Future<void> save(Map<String, CachedResponse> cache) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(
        cache.map((k, v) => MapEntry(k, v._toJson())),
      );
      await prefs.setString(_kCacheKey, encoded);
    } catch (_) {
      // Best-effort persistence; ignore.
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kCacheKey);
    } catch (_) {}
  }
}
