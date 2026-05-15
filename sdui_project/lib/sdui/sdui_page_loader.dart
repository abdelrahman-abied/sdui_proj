import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'action_delegate.dart';
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
  static final Map<String, _CachedEntry> _cache = {};

  /// HTTP client used for all requests. Overridable by tests via
  /// [debugSetClient] so we can mock 304s and verify If-None-Match without
  /// real network.
  static http.Client _client = http.Client();

  @visibleForTesting
  static void debugSetClient(http.Client client) => _client = client;

  /// Server-emitted deprecation notice (X-SDUI-Deprecated). UI can listen to
  /// this and show a banner. Set the first time we observe the header in a
  /// response; left in place until the app restarts.
  static final ValueNotifier<String?> deprecationNotice = ValueNotifier(null);

  static void clearCache() => _cache.clear();

  static Future<Map<String, dynamic>> fetchEndpoint(
    String endpoint, {
    bool useCache = true,
  }) async {
    final uri = _resolve(endpoint);
    final cacheKey = uri.path + (uri.hasQuery ? '?${uri.query}' : '');
    final cached = _cache[cacheKey];

    // Fast path: instant hit from memory on navigation.
    if (useCache && cached != null) {
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
      return Map<String, dynamic>.from(cached.data);
    }

    final data = await _decode(response, uri);
    _cache[cacheKey] = _CachedEntry(data, response.headers['etag']);
    return data;
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
      throw Exception('SDUI request failed (${response.statusCode}) for $uri');
    }
    final decoded = _tryDecodeBody(response.body);
    if (decoded == null) {
      throw Exception('SDUI response is not a JSON object for $uri');
    }
    return decoded;
  }

  static Map<String, dynamic>? _tryDecodeBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }
}

class _CachedEntry {
  _CachedEntry(this.data, this.etag);
  final Map<String, dynamic> data;
  final String? etag;
}
