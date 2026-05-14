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

  Future<void> _fetchPage() async {
    try {
      final json = await SDUIApiService.fetchEndpoint(widget.endpoint);

      if (mounted) {
        setState(() {
          uiData = json;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (errorMessage != null || uiData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: Center(child: Text("Failed to load: $errorMessage")),
      );
    }

    final title = (uiData!['screen_title'] as String?) ?? _titleFromEndpoint(widget.endpoint);
    final tree = (uiData!['ui_tree'] is Map)
        ? Map<String, dynamic>.from(uiData!['ui_tree'] as Map)
        : uiData!;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(child: SDUIParser(uiJson: tree)),
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
  /// Base URL of the sdui_server. Android emulator needs 10.0.2.2 to reach
  /// the host machine; iOS simulator, desktop and web can use localhost.
  static String get baseUrl {
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  /// Optional in-memory cache to avoid re-fetching on repeated navigation.
  static final Map<String, Map<String, dynamic>> _cache = {};

  static Future<Map<String, dynamic>> fetchEndpoint(
    String endpoint, {
    bool useCache = true,
  }) async {
    final normalized = endpoint.startsWith('/') ? endpoint : '/$endpoint';

    if (useCache && _cache.containsKey(normalized)) {
      return Map<String, dynamic>.from(_cache[normalized]!);
    }

    final uri = Uri.parse('$baseUrl$normalized');
    final response = await http.get(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'SDUI fetch failed (${response.statusCode}) for $uri',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('SDUI response is not a JSON object for $uri');
    }
    final data = Map<String, dynamic>.from(decoded);
    if (useCache) _cache[normalized] = data;
    return data;
  }
}
