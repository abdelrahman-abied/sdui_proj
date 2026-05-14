import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'sdui_parser.dart';

class SDUIGenericPage extends StatefulWidget {
  final String endpoint; // e.g., "home" or "product/123"
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
        appBar: AppBar(title: const Text("Error")),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Failed to load: $errorMessage"),
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

  /// Optional in-memory cache to avoid re-fetching on repeated navigation.
  static final Map<String, Map<String, dynamic>> _cache = {};

  static Future<Map<String, dynamic>> fetchEndpoint(
    String endpoint, {
    bool useCache = true,
  }) async {
    final uri = _resolve(endpoint);
    final cacheKey = uri.path + (uri.hasQuery ? '?${uri.query}' : '');

    if (useCache && _cache.containsKey(cacheKey)) {
      return Map<String, dynamic>.from(_cache[cacheKey]!);
    }

    final response = await http.get(uri);
    final data = _decode(response, uri);
    if (useCache) _cache[cacheKey] = data;
    return data;
  }

  /// POSTs a JSON body and returns the JSON response. Used by form submits.
  static Future<Map<String, dynamic>> postJson(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final uri = _resolve(endpoint);
    final response = await http.post(
      uri,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decode(response, uri);
  }

  static Uri _resolve(String endpoint) {
    final normalized = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    return Uri.parse('$baseUrl$normalized');
  }

  static Map<String, dynamic> _decode(http.Response response, Uri uri) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('SDUI request failed (${response.statusCode}) for $uri');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('SDUI response is not a JSON object for $uri');
    }
    return Map<String, dynamic>.from(decoded);
  }
}
