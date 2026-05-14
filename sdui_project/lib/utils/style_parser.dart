import 'package:flutter/material.dart';

/// Reads style fields out of an SDUI node's `props` map (which is what the
/// server emits today). Keys are camelCase to match the server-side widgets in
/// `sdui_builder.dart` (`padding`, `margin`, `backgroundColor`, `cornerRadius`).
///
/// The older `parseInsets` / `parseDecoration` helpers still accept the
/// snake_case `style` block for backwards compatibility with the legacy
/// asset-driven JSON shape.
class StyleParser {
  /// Convert `"#1a1a2e"` (or `"#aarrggbb"`) into a [Color].
  static Color? parseColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return null;
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return null;
    }
  }

  // --- New prop-based helpers (matches the server's emitted JSON) ---

  static EdgeInsets parsePadding(Map<String, dynamic>? props) =>
      _edgeFrom(props, 'padding');

  static EdgeInsets parseMargin(Map<String, dynamic>? props) =>
      _edgeFrom(props, 'margin');

  static Color? parseBackgroundColor(Map<String, dynamic>? props) =>
      parseColor(props?['backgroundColor'] as String?);

  static double parseCornerRadius(Map<String, dynamic>? props) =>
      (props?['cornerRadius'] as num?)?.toDouble() ?? 0.0;

  static EdgeInsets _edgeFrom(Map<String, dynamic>? props, String key) {
    if (props == null) return EdgeInsets.zero;
    final v = props[key];
    if (v is num) return EdgeInsets.all(v.toDouble());
    return EdgeInsets.zero;
  }

  // --- Legacy `style` block helpers, kept for backwards compat ---

  static EdgeInsetsGeometry parseInsets(Map<String, dynamic>? style, String prefix) {
    if (style == null) return EdgeInsets.zero;
    if (style[prefix] is num) {
      return EdgeInsets.all((style[prefix] as num).toDouble());
    }
    return EdgeInsets.only(
      top: (style['${prefix}_top'] ?? 0).toDouble(),
      bottom: (style['${prefix}_bottom'] ?? 0).toDouble(),
      left: (style['${prefix}_left'] ?? 0).toDouble(),
      right: (style['${prefix}_right'] ?? 0).toDouble(),
    );
  }

  static BoxDecoration parseDecoration(Map<String, dynamic>? style) {
    if (style == null) return const BoxDecoration();
    return BoxDecoration(
      color: parseColor(style['background_color'] as String?),
      borderRadius:
          BorderRadius.circular((style['corner_radius'] ?? 0).toDouble()),
      boxShadow: style.containsKey('elevation')
          ? [
              BoxShadow(
                color: Colors.black12,
                blurRadius: (style['elevation'] ?? 0).toDouble(),
                offset: const Offset(0, 4),
              ),
            ]
          : null,
    );
  }
}
