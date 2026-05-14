import 'package:flutter/material.dart';
import 'package:sdui_project/components/sdui_lazy_list.dart';
import 'package:sdui_project/sdui/sdui_input.dart';
import 'package:sdui_project/sdui/sdui_parser.dart';

import '../components/sdui_components.dart';
import '../components/sdui_container.dart'; // Import Container
import '../components/sdui_grid.dart'; // Import Grid
import '../utils/style_parser.dart'; // Import Parser

typedef SDUIWidgetBuilder = Widget Function(Map<String, dynamic> node);

class ComponentRegistry {
  static final Map<String, SDUIWidgetBuilder> _registry = {
    // Layouts
    'VERTICAL_STACK': (node) => Column(
      children: (node['children'] as List? ?? [])
          .map((child) => SDUIParser(uiJson: Map<String, dynamic>.from(child as Map)))
          .toList(),
    ),

    'HORIZONTAL_SCROLL': (node) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: (node['children'] as List? ?? [])
            .map((child) => SDUIParser(uiJson: Map<String, dynamic>.from(child as Map)))
            .toList(),
      ),
    ),

    'IMAGE': (node) {
      final props = Map<String, dynamic>.from(node['props'] as Map? ?? {});
      final url = props['url']?.toString() ?? '';
      final height = (props['height'] as num?)?.toDouble();
      final width = (props['width'] as num?)?.toDouble();
      if (url.isEmpty) return const SizedBox.shrink();
      return Image.network(
        url,
        height: height,
        width: width,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: height ?? 120,
          width: width,
          color: Colors.grey[300],
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    },

    // New: Generic Container (Div)
    'CONTAINER': (node) => SDUIContainer(uiJson: Map<String, dynamic>.from(node)),

    // New: Grids
    'GRID_2_COL': (node) => SDUIGrid(uiJson: Map<String, dynamic>.from(node), crossAxisCount: 2),

    // Components
    'HEADER': (node) => SDUIHeader(title: node['props']['title'], iconUrl: node['props']['icon_url']),

    'BANNER_CARD': (node) => SDUIBanner(imageUrl: node['props']['image_url']),

    'PRODUCT_CARD': (node) => SDUIProductCard(name: node['props']['name'], price: node['props']['price']),

    'BUTTON_PRIMARY': (node) {
      final props = node['props'] as Map? ?? {};
      final style = Map<String, dynamic>.from(node['style'] as Map? ?? {});
      final label = props['label'] ?? 'Button';
      final color = StyleParser.parseColor(style['background_color'] ?? props['color']) ?? Colors.blue;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            child: Text(
              label.toString(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      );
    },

    // Server emits text + named style preset (title/subtitle/body) + color in props.
    'TEXT': (node) {
      final props = Map<String, dynamic>.from(node['props'] as Map? ?? {});
      final preset = (props['style'] as String?) ?? 'body';
      final fontSize = switch (preset) {
        'title' => 24.0,
        'subtitle' => 18.0,
        _ => 14.0,
      };
      final fontWeight = preset == 'title' || preset == 'subtitle'
          ? FontWeight.bold
          : FontWeight.normal;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Text(
          props['text']?.toString() ?? '',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: StyleParser.parseColor(props['color'] as String?) ?? Colors.black,
          ),
        ),
      );
    },
    'INPUT_TEXT': (node) {
      final props = Map<String, dynamic>.from(node['props'] as Map? ?? {});
      return SDUITextInput(
        id: props['id']?.toString() ?? 'unknown_id',
        props: props,
      );
    },
    'LAZY_LIST': (node) => SDUILazyList(uiJson: node),
  };

  static SDUIWidgetBuilder? getWidgetBuilder(String type) {
    return _registry[type];
  }
}
