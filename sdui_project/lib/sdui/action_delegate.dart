import 'package:flutter/material.dart';
import 'package:sdui_project/sdui/form_manager.dart';
import 'package:sdui_project/sdui/sdui_page_loader.dart';
import 'package:sdui_project/sdui/session_store.dart';

import 'sdui_action.dart';

class SDUIActionDelegate {
  /// Entry point — every action tap funnels through here. Handles the
  /// universal pre-flight steps (condition + confirm + sequence) before
  /// dispatching to the type-specific handler.
  static Future<void> handleAction(BuildContext context, SDUIAction action) async {
    debugPrint("[ActionDelegate] Processing: ${action.type}");

    // 1. Conditional gate — skip if predicate is false.
    if (!_evaluateCondition(action.condition)) {
      debugPrint("[ActionDelegate] Skipping ${action.type}: condition failed");
      return;
    }

    // 2. Confirmation dialog — bail if the user cancels.
    if (action.confirm != null) {
      final ok = await _confirm(context, action.confirm!);
      if (!ok || !context.mounted) return;
    }

    // 3. Sequence — run children in order, stopping if any returns false.
    if (action.type == 'sequence') {
      for (final inner in action.actions ?? const <SDUIAction>[]) {
        if (!context.mounted) return;
        await handleAction(context, inner);
      }
      return;
    }

    // 4. Type-specific dispatch.
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
      case 'logout':
        _handleLogout(context, action);
        break;
      default:
        debugPrint("⚠️ [ActionDelegate] Unknown action type: ${action.type}");
    }
  }

  /// Evaluate `{field, equals}` against the current form data. Null
  /// condition → always pass.
  static bool _evaluateCondition(Map<String, dynamic>? condition) {
    if (condition == null) return true;
    final field = condition['field']?.toString();
    if (field == null) return true;
    final actual = SDUIFormManager().export()[field];
    if (condition.containsKey('equals')) return actual == condition['equals'];
    if (condition.containsKey('not_equals')) return actual != condition['not_equals'];
    if (condition.containsKey('truthy')) {
      final wantTruthy = condition['truthy'] == true;
      final isTruthy = actual != null && actual != false && actual != '';
      return wantTruthy == isTruthy;
    }
    return true;
  }

  static Future<bool> _confirm(BuildContext context, Map<String, dynamic> spec) async {
    final destructive = spec['destructive'] == true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text((spec['title'] as String?) ?? 'Are you sure?'),
        content: Text((spec['message'] as String?) ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text((spec['cancelLabel'] as String?) ?? 'Cancel'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: Colors.red)
                : null,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text((spec['confirmLabel'] as String?) ?? 'OK'),
          ),
        ],
      ),
    );
    return result == true;
  }

  static Future<void> _handleLogout(BuildContext context, SDUIAction action) async {
    await SessionStore.clear();
    SDUIApiService.clearCache();
    if (!context.mounted) return;
    final target = action.url ?? '/login';
    Navigator.of(context).pushNamedAndRemoveUntil(target, (_) => false);
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
    final manager = SDUIFormManager();

    // 1. Client-side validation — surface errors inline on fields.
    final errors = manager.validate();
    if (errors != null) {
      manager.fieldErrors.value = errors;
      return;
    }

    final url = action.url;
    if (url == null || url.isEmpty) {
      debugPrint('[FormSubmit] missing url on action');
      return;
    }

    // 2. Merge field values with any static data the action carries.
    final body = <String, dynamic>{
      ...manager.export(),
      if (action.payload != null) ...action.payload!,
    };

    Map<String, dynamic> reply;
    try {
      reply = await SDUIApiService.postJson(url, body);
    } catch (e) {
      debugPrint('[FormSubmit] POST $url failed: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submit failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // If the server issued a token (login), persist it so subsequent
    // requests carry it via the Authorization header.
    final token = reply['token'] as String?;
    if (token != null && token.isNotEmpty) {
      await SessionStore.setToken(token);
      // Cached responses were issued without auth — drop them so the next
      // fetch goes through the auth flow.
      SDUIApiService.clearCache();
    }

    if (!context.mounted) return;

    // 3. Server-driven field errors — `errors: {fieldId: message}` paints
    // them inline on the form. The form stays mounted (no navigate).
    final rawErrors = reply['errors'];
    if (rawErrors is Map && rawErrors.isNotEmpty) {
      manager.fieldErrors.value = {
        for (final e in rawErrors.entries) '${e.key}': '${e.value}',
      };
      return;
    }

    final message = reply['message'] as String?;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }

    // Multi-step forms: keep field data unless the server explicitly asks
    // us to clear it (`clear_form: true`) or there's no follow-up action
    // (treat as success done).
    final clearForm = reply['clear_form'] == true;

    // 4. Run whatever follow-up action the server hands back. The server is
    // the authority — on success it returns a `navigate` (or `sequence`)
    // action, on failure a `show_toast` action.
    final replyAction = reply['action'];
    if (replyAction is Map) {
      final next = SDUIAction.fromJson(Map<String, dynamic>.from(replyAction));
      if (next.type == 'navigate' && next.url != null) {
        if (clearForm) manager.clear();
        Navigator.of(context).pushNamedAndRemoveUntil(next.url!, (_) => false);
      } else {
        if (clearForm) manager.clear();
        await handleAction(context, next);
      }
    } else if (clearForm) {
      manager.clear();
    }
  }
}
