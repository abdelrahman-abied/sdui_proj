/// Action payload: type ('navigate' | 'form_submit' | 'show_toast' | ...),
/// optional url, optional data, and optional success_url / success_message
/// (used by form_submit to drive post-submit navigation from the server).
/// Attach to any SDUIWidget via the widget's [action] parameter.
Map<String, dynamic> sduiAction({
  required String type,
  String? url,
  Map<String, dynamic>? data,
  String? successUrl,
  String? successMessage,
}) {
  return {
    'type': type,
    if (url != null) 'url': url,
    if (data != null) 'data': data,
    if (successUrl != null) 'success_url': successUrl,
    if (successMessage != null) 'success_message': successMessage,
  };
}

/// Wrap a list of actions so the client runs them sequentially.
///
/// Example: show a toast, then navigate.
/// ```dart
/// sduiSequence([
///   sduiAction(type: 'show_toast', data: {'message': 'Saved!'}),
///   sduiAction(type: 'navigate', url: '/home'),
/// ])
/// ```
Map<String, dynamic> sduiSequence(List<Map<String, dynamic>> actions) => {
      'type': 'sequence',
      'actions': actions,
    };

/// Wrap an action in a confirmation dialog. The dialog only shows on
/// the client; the action only runs if the user taps the confirm button.
///
/// `destructive: true` styles the confirm button red.
Map<String, dynamic> sduiConfirm(
  Map<String, dynamic> action, {
  required String title,
  required String message,
  String confirmLabel = 'OK',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) =>
    {
      ...action,
      'confirm': {
        'title': title,
        'message': message,
        'confirmLabel': confirmLabel,
        'cancelLabel': cancelLabel,
        if (destructive) 'destructive': true,
      },
    };

/// Add a client-side `if` gate. The action only runs when the form field
/// [field] matches the comparison (`equals` is the most common).
Map<String, dynamic> sduiWhen(
  Map<String, dynamic> action, {
  required String field,
  Object? equals,
  Object? notEquals,
  bool? truthy,
}) =>
    {
      ...action,
      'if': {
        'field': field,
        if (equals != null) 'equals': equals,
        if (notEquals != null) 'not_equals': notEquals,
        if (truthy != null) 'truthy': truthy,
      },
    };

/// Helper for form_submit failure responses: returns inline field errors
/// that the client paints on the corresponding `INPUT_TEXT` widgets.
/// Use from a route's POST handler:
/// ```dart
/// return Response.json(body: sduiFieldErrors({'email': 'Already in use'}));
/// ```
Map<String, dynamic> sduiFieldErrors(Map<String, String> errors) => {
      'errors': errors,
    };
