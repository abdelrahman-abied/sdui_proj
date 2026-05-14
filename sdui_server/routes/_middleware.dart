import 'package:dart_frog/dart_frog.dart';

/// Global middleware applied to every route.
///
/// Adds permissive CORS headers so the Flutter web build (and any other
/// browser-based client) can talk to this server during development.
/// Tighten the allowed origin before deploying to production.
Handler middleware(Handler handler) {
  return (context) async {
    // Pre-flight: short-circuit OPTIONS with the CORS headers.
    if (context.request.method == HttpMethod.options) {
      return Response(statusCode: 204, headers: _corsHeaders);
    }
    final response = await handler(context);
    return response.copyWith(
      headers: {...response.headers, ..._corsHeaders},
    );
  };
}

const _corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  'access-control-allow-headers': 'content-type, authorization',
  'access-control-max-age': '86400',
};
