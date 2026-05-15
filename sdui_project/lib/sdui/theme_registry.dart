import 'package:flutter/material.dart';

import 'sdui_page_loader.dart';

/// Brand tokens fetched from the server's `/theme` endpoint. Use the static
/// [current] anywhere you need to resolve `@primary`, `@danger`, etc.
class SDUITheme {
  final Map<String, Color> colors;
  final Map<String, double> typography;
  final Map<String, double> radius;

  const SDUITheme({
    required this.colors,
    required this.typography,
    required this.radius,
  });

  /// Reasonable fallback so the client renders even if `/theme` fails.
  static const SDUITheme fallback = SDUITheme(
    colors: {
      'primary': Color(0xFF1A1A2E),
      'secondary': Color(0xFF16213E),
      'background': Color(0xFFFFFFFF),
      'surface': Color(0xFFF5F5F5),
      'onPrimary': Color(0xFFFFFFFF),
      'onSurface': Color(0xFF1A1A2E),
      'onBackground': Color(0xFF1A1A2E),
      'muted': Color(0xFF666666),
      'danger': Color(0xFFC62828),
      'success': Color(0xFF2E7D32),
      'warning': Color(0xFFF57C00),
      'info': Color(0xFF1565C0),
    },
    typography: {'title': 24, 'subtitle': 18, 'body': 14, 'caption': 12},
    radius: {'card': 12, 'button': 8, 'input': 8},
  );

  factory SDUITheme.fromJson(Map<String, dynamic> json) {
    Color? parseHex(Object? value) {
      if (value is! String) return null;
      final hex = value.replaceFirst('#', '');
      final cleaned = hex.length == 6 ? 'ff$hex' : hex;
      try {
        return Color(int.parse(cleaned, radix: 16));
      } catch (_) {
        return null;
      }
    }

    final rawColors = (json['colors'] as Map?) ?? const {};
    final colors = <String, Color>{};
    rawColors.forEach((k, v) {
      final c = parseHex(v);
      if (c != null) colors['$k'] = c;
    });

    final rawTypo = (json['typography'] as Map?) ?? const {};
    final typo = <String, double>{
      for (final e in rawTypo.entries)
        if (e.value is num) '${e.key}': (e.value as num).toDouble(),
    };

    final rawRadius = (json['radius'] as Map?) ?? const {};
    final radius = <String, double>{
      for (final e in rawRadius.entries)
        if (e.value is num) '${e.key}': (e.value as num).toDouble(),
    };

    return SDUITheme(
      colors: {...fallback.colors, ...colors},
      typography: {...fallback.typography, ...typo},
      radius: {...fallback.radius, ...radius},
    );
  }

  /// Build a Flutter [ThemeData] from these tokens.
  ThemeData toThemeData() {
    final primary = colors['primary'] ?? fallback.colors['primary']!;
    final surface = colors['surface'] ?? fallback.colors['surface']!;
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        surface: surface,
        error: colors['danger'] ?? Colors.red,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(radius['button'] ?? 8),
          ),
        ),
      ),
    );
  }
}

/// Singleton registry. Use [bootstrap] once at app start, then read
/// [current] anywhere.
class ThemeRegistry {
  ThemeRegistry._();

  static SDUITheme current = SDUITheme.fallback;
  static final ValueNotifier<SDUITheme> notifier =
      ValueNotifier<SDUITheme>(SDUITheme.fallback);

  /// Fetches `/theme` from the server and seeds [current]. If the request
  /// fails (offline, cold start, etc.), falls back to [SDUITheme.fallback].
  static Future<void> bootstrap() async {
    try {
      final json = await SDUIApiService.fetchEndpoint('/theme');
      final theme = SDUITheme.fromJson(json);
      current = theme;
      notifier.value = theme;
    } catch (e) {
      debugPrint('[ThemeRegistry] /theme fetch failed, using fallback: $e');
    }
  }
}
