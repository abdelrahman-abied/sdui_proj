import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'action_delegate.dart';
import 'cache_store.dart';
import 'sdui_action.dart';
import 'sdui_parser.dart';
import 'session_store.dart';

/// SDUI schema version this client speaks. Sent on every request as
/// `X-SDUI-Version`. The server can reject older clients with 426 or
/// respond with `X-SDUI-Deprecated` to nudge an upgrade.
const int sduiSchemaVersion = 1;

class SDUIGenericPage extends StatefulWidget {
  final String endpoint;
  final Map<String, dynamic> initialData;

  const SDUIGenericPage({super.key, required this.endpoint, this.initialData = const {}});

  @override
  State<SDUIGenericPage> createState() => _SDUIGenericPageState();
}

class _SDUIGenericPageState extends State<SDUIGenericPage> {
  bool isLoading = true;
  Map<String, dynamic>? uiData;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchPage();
  }

  Future<void> _fetchPage({bool useCache = true}) async {
    try {
      final json = await SDUIApiService.fetchEndpoint(
        widget.endpoint,
        useCache: useCache,
        // Stale-while-revalidate: when we serve a cached body, fire a quiet
        // background revalidation and swap to the fresh tree if the server
        // returns a different ETag. Skipped on pull-to-refresh (the user
        // already asked for fresh, and the foreground fetch is fresh).
        onRevalidate: useCache
            ? (fresh) {
                if (!mounted) return;
                setState(() => uiData = fresh);
              }
            : null,
      );
      if (!mounted) return;
      setState(() {
        uiData = json;
        errorMessage = null;
        isLoading = false;
      });
    } on SDUIUnauthorizedException catch (e) {
      // Server says we're not authenticated — dispatch its recovery action
      // (typically navigate /login). The session has already been cleared.
      if (!mounted) return;
      SDUIActionDelegate.handleAction(context, e.action);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _refresh() => _fetchPage(useCache: false);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (errorMessage != null || uiData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load: $errorMessage'),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _refresh,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final title = (uiData!['screen_title'] as String?) ?? _titleFromEndpoint(widget.endpoint);
    final tree = (uiData!['ui_tree'] is Map)
        ? Map<String, dynamic>.from(uiData!['ui_tree'] as Map)
        : uiData!;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SDUIParser(uiJson: tree),
          ),
        ),
      ),
    );
  }

  String _titleFromEndpoint(String endpoint) {
    final head = endpoint.split('/').first;
    if (head.isEmpty) return 'SDUI App';
    return head[0].toUpperCase() + head.substring(1);
  }
}

/// Thrown when the server returns 401. Carries the SDUI action the server
/// wants the client to run (typically `navigate /login`).
class SDUIUnauthorizedException implements Exception {
  SDUIUnauthorizedException(this.action);
  final SDUIAction action;
  @override
  String toString() => 'SDUIUnauthorizedException(${action.type} ${action.url})';
}

/// Fetches SDUI screen JSON from the Dart Frog server.
class SDUIApiService {
  /// Override at build/run time:
  ///   flutter run --dart-define=SDUI_BASE_URL=https://sdui.example.com
  static const String _override = String.fromEnvironment('SDUI_BASE_URL');

  /// Base URL of the sdui_server. Resolution order:
  /// 1. `--dart-define=SDUI_BASE_URL=...` if set
  /// 2. Android emulator → `http://10.0.2.2:8080` (host loopback)
  /// 3. Everything else (iOS sim, desktop, web) → `http://localhost:8080`
  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8080';
    return 'http://localhost:8080';
  }

  /// In-memory cache for GET responses. Cleared on logout/401.
  ///
  /// We keep the parsed body alongside the server's `ETag`. On a refresh
  /// (`useCache: false`) we re-send the ETag as `If-None-Match`; a `304`
  /// then serves the cached body without re-parsing.
  ///
  /// Mirrored to disk via [CacheStore] — a cold start hydrates this map
  /// before the first network call, so a repeat user sees their last UI
  /// instantly and we revalidate in the background with `If-None-Match`.
  static final Map<String, CachedResponse> _cache = {};

  /// Becomes a non-null `Future` the first time we kick off disk hydration.
  /// Subsequent fetches await the same future, so concurrent cold-start
  /// requests don't race on the prefs read.
  static Future<void>? _hydration;

  /// HTTP client used for all requests. Overridable by tests via
  /// [debugSetClient] so we can mock 304s and verify If-None-Match without
  /// real network.
  static http.Client _client = http.Client();

  @visibleForTesting
  static void debugSetClient(http.Client client) => _client = client;

  /// Wipes the in-memory mirror only — used by tests between cases.
  @visibleForTesting
  static void debugResetHydration() {
    _cache.clear();
    _hydration = null;
  }

  /// Server-emitted deprecation notice (X-SDUI-Deprecated). UI can listen to
  /// this and show a banner. Set the first time we observe the header in a
  /// response; left in place until the app restarts.
  static final ValueNotifier<String?> deprecationNotice = ValueNotifier(null);

  /// Drops both the in-memory and disk caches. Called on logout/401 so
  /// auth-gated screens don't survive into the next session.
  static void clearCache() {
    _cache.clear();
    // Fire-and-forget — the disk write doesn't need to block the caller.
    CacheStore.clear();
  }

  static Future<void> _ensureHydrated() {
    return _hydration ??= () async {
      final stored = await CacheStore.load();
      // The in-memory map is the source of truth — only fill the keys disk
      // had and we haven't already populated from a live fetch.
      stored.forEach((k, v) => _cache.putIfAbsent(k, () => v));
    }();
  }

  static Future<Map<String, dynamic>> fetchEndpoint(
    String endpoint, {
    bool useCache = true,
    void Function(Map<String, dynamic> fresh)? onRevalidate,
  }) async {
    final uri = _resolve(endpoint);
    final cacheKey = uri.path + (uri.hasQuery ? '?${uri.query}' : '');

    // Cold start: drain prefs into the in-memory cache once. After this
    // returns, repeat callers hit the fast path below without disk I/O.
    await _ensureHydrated();
    final cached = _cache[cacheKey];

    // Fast path: instant hit from memory on navigation. When the caller
    // wants stale-while-revalidate, kick off a quiet background fetch and
    // notify them if the server has fresher data. Expired entries (past
    // their server-sent max-age) fall through to the foreground refetch
    // below so we never return data the server told us is stale.
    if (useCache && cached != null && !cached.isExpired()) {
      if (onRevalidate != null) {
        unawaited(_revalidate(uri, cacheKey, cached, onRevalidate));
      }
      return Map<String, dynamic>.from(cached.data);
    }

    // Refresh path (or cold). Send If-None-Match if we have an ETag so the
    // server can answer 304 and we keep the existing parsed body.
    final headers = await _headers();
    if (cached?.etag != null) {
      headers['if-none-match'] = cached!.etag!;
    }

    final response = await _client.get(uri, headers: headers);
    if (response.statusCode == 304 && cached != null) {
      // Server confirmed the cached body is still current — refresh storedAt
      // (and pick up any new max-age) so we don't immediately revalidate
      // again on the next read.
      _cache[cacheKey] = _refreshedEntry(cached, response);
      unawaited(CacheStore.save(_cache));
      return Map<String, dynamic>.from(cached.data);
    }

    final data = await _decode(response, uri);
    // Server-rendered error bodies (non-2xx that _decode handed back as SDUI)
    // are returned for rendering but kept out of the cache — caching a 404
    // would mean a recovered route still serves the error screen next time.
    if (response.statusCode >= 200 && response.statusCode < 300) {
      _cache[cacheKey] = _buildCacheEntry(data, response);
      // Persist asynchronously — the fetch result is what the caller needs.
      unawaited(CacheStore.save(_cache));
    }
    return data;
  }

  /// Builds a fresh cache entry from a 200 response, capturing the ETag and
  /// the server's `Cache-Control: max-age=N` so future reads can detect TTL
  /// expiry and force a foreground revalidation.
  static CachedResponse _buildCacheEntry(
    Map<String, dynamic> data,
    http.Response response,
  ) {
    return CachedResponse(
      data: data,
      etag: response.headers['etag'],
      storedAt: DateTime.now().millisecondsSinceEpoch,
      maxAgeSeconds: _parseMaxAge(response.headers['cache-control']),
    );
  }

  /// Rebuilds [cached] with a new `storedAt` (and updated `maxAge`, if the
  /// 304 carried one) — used when the server confirms an expired entry is
  /// still current so the next read doesn't re-revalidate immediately.
  static CachedResponse _refreshedEntry(
    CachedResponse cached,
    http.Response response,
  ) {
    return CachedResponse(
      data: cached.data,
      etag: response.headers['etag'] ?? cached.etag,
      storedAt: DateTime.now().millisecondsSinceEpoch,
      maxAgeSeconds:
          _parseMaxAge(response.headers['cache-control']) ?? cached.maxAgeSeconds,
    );
  }

  /// Pulls `max-age=N` out of a `Cache-Control` header. Returns null when no
  /// directive is present so callers can distinguish "no expiry hint" from
  /// "expires immediately".
  static int? _parseMaxAge(String? header) {
    if (header == null || header.isEmpty) return null;
    for (final part in header.split(',')) {
      final trimmed = part.trim().toLowerCase();
      if (trimmed.startsWith('max-age=')) {
        return int.tryParse(trimmed.substring('max-age='.length));
      }
    }
    return null;
  }

  /// Background revalidation for stale-while-revalidate. Sends If-None-Match;
  /// on 304 we leave the cache alone. On 200 we update memory + disk and call
  /// [onFresh] so the UI can swap to the new tree. Failures are swallowed —
  /// the caller already got the cached body, so a network blip is harmless.
  static Future<void> _revalidate(
    Uri uri,
    String cacheKey,
    CachedResponse cached,
    void Function(Map<String, dynamic> fresh) onFresh,
  ) async {
    try {
      final headers = await _headers();
      if (cached.etag != null) {
        headers['if-none-match'] = cached.etag!;
      }
      final response = await _client.get(uri, headers: headers);
      if (response.statusCode == 304) {
        // Server confirmed staleness wasn't a problem — bump TTL so a
        // subsequent foreground read can return from cache.
        _cache[cacheKey] = _refreshedEntry(cached, response);
        unawaited(CacheStore.save(_cache));
        return;
      }
      // Non-2xx in the background path: don't replace the good cached body
      // with an error screen, and don't bother decoding.
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final data = await _decode(response, uri);
      _cache[cacheKey] = _buildCacheEntry(data, response);
      unawaited(CacheStore.save(_cache));
      onFresh(Map<String, dynamic>.from(data));
    } catch (_) {
      // SWR is best-effort. The cached body is already in the caller's hands.
    }
  }

  /// POSTs a JSON body and returns the JSON response. Used by form submits.
  static Future<Map<String, dynamic>> postJson(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final uri = _resolve(endpoint);
    final response = await _client.post(
      uri,
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _decode(response, uri);
  }

  static Uri _resolve(String endpoint) {
    final normalized = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    return Uri.parse('$baseUrl$normalized');
  }

  static Future<Map<String, String>> _headers() async {
    final token = await SessionStore.getToken();
    return {
      'content-type': 'application/json',
      'x-sdui-version': '$sduiSchemaVersion',
      if (token != null && token.isNotEmpty) 'authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> _decode(http.Response response, Uri uri) async {
    // Pick up any deprecation notice the server sent.
    final deprecated = response.headers['x-sdui-deprecated'];
    if (deprecated != null && deprecated.isNotEmpty) {
      deprecationNotice.value = deprecated;
    }

    // 401: clear session, surface the server's recovery action.
    if (response.statusCode == 401) {
      await SessionStore.clear();
      clearCache();
      final body = _tryDecodeBody(response.body);
      final actionJson = body?['action'];
      if (actionJson is Map) {
        throw SDUIUnauthorizedException(
          SDUIAction.fromJson(Map<String, dynamic>.from(actionJson)),
        );
      }
      throw SDUIUnauthorizedException(
        SDUIAction(type: 'navigate', url: '/login'),
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      // Server-rendered error: if the body parses as SDUI, hand it back so
      // the page renders the recovery tree instead of falling back to the
      // generic "Failed to load" widget. The 2xx-only cache write in
      // fetchEndpoint keeps these out of the persistent cache.
      final decoded = _tryDecodeBody(response.body);
      if (_looksLikeSDUI(decoded)) return decoded!;
      throw Exception('SDUI request failed (${response.statusCode}) for $uri');
    }
    final decoded = _tryDecodeBody(response.body);
    if (decoded == null) {
      throw Exception('SDUI response is not a JSON object for $uri');
    }
    return decoded;
  }

  /// True when [decoded] looks like an SDUI tree — has either a top-level
  /// `type` (single-node response) or `ui_tree` (wrapped response). Used to
  /// distinguish a server-rendered error screen from a plain error JSON
  /// (`{message: "..."}`) we should surface as a thrown exception.
  static bool _looksLikeSDUI(Map<String, dynamic>? decoded) {
    if (decoded == null) return false;
    return decoded.containsKey('type') || decoded.containsKey('ui_tree');
  }

  static Map<String, dynamic>? _tryDecodeBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }
}

