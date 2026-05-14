import 'package:flutter/material.dart';
import 'component_registry.dart';
import 'sdui_action.dart';
import 'action_delegate.dart';

class SDUIParser extends StatelessWidget {
  final Map<String, dynamic> uiJson;

  const SDUIParser({super.key, required this.uiJson});

  @override
  Widget build(BuildContext context) {
    // 1. Safety Check: If JSON is empty, render nothing.
    if (uiJson.isEmpty) return const SizedBox.shrink();

    // 2. Extract the Component Type
    final String type = uiJson['type'] ?? 'UNKNOWN';

    // 3. Resolve a builder for the primary type, falling back to whatever
    // back-compat shape the server provided (fallback_type / fallback_props)
    // when we don't know the primary. Schema-evolution safety: the server
    // can ship a v2 component and older clients still render something.
    var node = uiJson;
    var widgetBuilder = ComponentRegistry.getWidgetBuilder(type);
    if (widgetBuilder == null) {
      final fallbackType = uiJson['fallback_type'] as String?;
      final fallbackBuilder = fallbackType == null
          ? null
          : ComponentRegistry.getWidgetBuilder(fallbackType);
      if (fallbackBuilder != null) {
        widgetBuilder = fallbackBuilder;
        node = {
          'type': fallbackType,
          'props': uiJson['fallback_props'] ?? uiJson['props'] ?? const {},
          if (uiJson['children'] != null) 'children': uiJson['children'],
          if (uiJson['action'] != null) 'action': uiJson['action'],
        };
        debugPrint('[SDUIParser] $type → fallback $fallbackType');
      }
    }

    // 4. Handle Unknown Components (Version Safety)
    if (widgetBuilder == null) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          color: Colors.red.withOpacity(0.1),
          padding: const EdgeInsets.all(8),
          child: Text(
            "⚠️ Unknown Component: $type",
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    // 5. Build the Native Widget
    Widget nativeWidget = widgetBuilder(node);

    // 6. Action Layer (Interaction)
    // If the JSON contains an "action" block, we wrap the widget in a GestureDetector.
    if (uiJson.containsKey('action')) {
      try {
        final action = SDUIAction.fromJson(Map<String, dynamic>.from(uiJson['action'] as Map));

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            debugPrint("[SDUIParser] Action tap: ${action.type}");
            SDUIActionDelegate.handleAction(context, action);
          },
          child: nativeWidget,
        );
      } catch (e) {
        debugPrint("Error parsing action for $type: $e");
        // If action parsing fails, just return the widget non-clickable
        return nativeWidget;
      }
    }

    return nativeWidget;
  }
}