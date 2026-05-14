import 'package:flutter/material.dart';

class StyleParser {
  // 1. Convert Hex String to Color (e.g., "#FF0000" -> Color)
  static Color? parseColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return null;
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      return null; // Fallback if color code is invalid
    }
  }

  // 2. Parse Spacing (Padding/Margin)
  static EdgeInsetsGeometry parseInsets(Map<String, dynamic>? style, String prefix) {
    if (style == null) return EdgeInsets.zero;

    // Check for "padding": 16 (All sides)
    if (style[prefix] is int || style[prefix] is double) {
      return EdgeInsets.all(style[prefix].toDouble());
    }

    // Check for specific sides "padding_top": 10
    return EdgeInsets.only(
      top: (style['${prefix}_top'] ?? 0).toDouble(),
      bottom: (style['${prefix}_bottom'] ?? 0).toDouble(),
      left: (style['${prefix}_left'] ?? 0).toDouble(),
      right: (style['${prefix}_right'] ?? 0).toDouble(),
    );
  }

  // 3. Parse Box Decoration (Background, Radius, Shadow)
  static BoxDecoration parseDecoration(Map<String, dynamic>? style) {
    if (style == null) return const BoxDecoration();

    return BoxDecoration(
      color: parseColor(style['background_color']),
      borderRadius: BorderRadius.circular((style['corner_radius'] ?? 0).toDouble()),
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
