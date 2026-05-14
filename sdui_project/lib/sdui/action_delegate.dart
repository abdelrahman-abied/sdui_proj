import 'package:flutter/material.dart';
import 'package:sdui_project/sdui/form_manager.dart';

import 'sdui_action.dart';

class SDUIActionDelegate {
  static void handleAction(BuildContext context, SDUIAction action) {
    debugPrint("[ActionDelegate] Processing: ${action.type}");

    switch (action.type) {
      case 'navigate':
        _handleNavigation(context, action);
        break;

      case 'show_toast':
        _showToast(context, action);
        break;

      case 'network_request':
        _performNetworkRequest(context, action);
        break;

      case 'pop':
        Navigator.of(context).pop();
        break;
      case 'form_submit':
        _handleFormSubmit(context, action);
        break;
      default:
        debugPrint("⚠️ [ActionDelegate] Unknown action type: ${action.type}");
    }
  }

  // --- Handlers ---

  static void _handleNavigation(BuildContext context, SDUIAction action) {
    if (action.url == null) return;

    // We use named routes to keep the implementation clean.
    // The arguments are passed so the destination page can use them to fetch data.
    Navigator.of(context).pushNamed(action.url!, arguments: action.payload);
  }

  static void _showToast(BuildContext context, SDUIAction action) {
    final message = action.payload?['message'] ?? 'Action Completed';
    final isError = action.payload?['is_error'] ?? false;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.black87,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void _performNetworkRequest(BuildContext context, SDUIAction action) async {
    // Example: "Add to Cart"
    // 1. Show loading indicator
    // 2. Await API call (mocked here)
    // 3. Handle success/failure action if defined in payload
    debugPrint("Sending API Request to: ${action.url} with body: ${action.payload}");

    await Future.delayed(const Duration(seconds: 1)); // Mock Network delay

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("API Request Successful")));
    }
  }

  static void _handleFormSubmit(BuildContext context, SDUIAction action) async {
    debugPrint("[FormSubmit] Sign In tapped - validating form");
    final manager = SDUIFormManager();

    // 1. Validate Client-Side - show errors on fields (not toast)
    final errors = manager.validate();
    if (errors != null) {
      manager.fieldErrors.value = errors;
      return;
    }

    // 2. Merge form data with action.data (e.g. device_id)
    final body = Map<String, dynamic>.from(manager.export());
    if (action.payload != null) {
      body.addAll(Map<String, dynamic>.from(action.payload!));
    }

    debugPrint("Form submit to ${action.url}: $body");

    // 3. Mock API call
    await Future.delayed(const Duration(seconds: 1));

    if (!context.mounted) return;

    // 4. Success: navigate from JSON if provided
    manager.clear();
    final route = action.successUrl;
    if (route != null && route.isNotEmpty) {
      Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => false);
    }
    final message = action.successMessage;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
}
