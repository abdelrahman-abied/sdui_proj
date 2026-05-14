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
