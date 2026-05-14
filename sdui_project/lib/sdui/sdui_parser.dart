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

    // 3. Look up the Widget in the Registry
    // We pass the ENTIRE json node so the component can access 'props', 'style', and 'children'
    final widgetBuilder = ComponentRegistry.getWidgetBuilder(type);

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
    Widget nativeWidget = widgetBuilder(uiJson);

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