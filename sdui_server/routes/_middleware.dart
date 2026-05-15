import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:sdui_server/auth.dart';
import 'package:sdui_server/sdui_actions.dart';

/// Schema version this server speaks. Older clients are warned via
/// `X-SDUI-Deprecated`; far-older clients could be rejected with 426.
const int _serverSduiVersion = 1;
const int _minSupportedClientVersion = 1;

/// Routes the client can reach without a JWT.
const _publicPathPrefixes = <String>{
  '/',
  '/login',
  '/auth/login',
  '/theme',
};

/// Global middleware:
/// 1. Permissive CORS (the web build needs it).
/// 2. SDUI schema-version negotiation — adds X-SDUI-Deprecated when needed.
/// 3. JWT auth — anything not in [_publicPathPrefixes] requires a valid
///    Bearer token. On failure responds 401 with an SDUI navigate action.
/// 4. Injects the authenticated username into the request context so route
///    handlers can read it via `context.read<AuthUser>()`.
Handler middleware(Handler handler) {
  return (context) async {
    final method = context.request.method;

    // CORS preflight: short-circuit.
    if (method == HttpMethod.options) {
      return Response(statusCode: 204, headers: _corsHeaders);
    }

    final path = context.request.uri.path;
    final username = _authenticate(context);

    if (_isProtected(path) && username == null) {
      return Response.json(
        statusCode: 401,
        headers: {..._corsHeaders, ..._versionHeaders(context)},
        body: {
          'action': sduiAction(type: 'navigate', url: '/login'),
          'message': 'Please sign in to continue',
        },
      );
    }

    // Attach the authenticated user (or AuthUser.anonymous) for downstream.
    final authed =
        username == null ? AuthUser.anonymous : AuthUser(username: username);
    final inner = context.provide<AuthUser>(() => authed);

    final response = await handler(inner);
    final extraHeaders = {..._corsHeaders, ..._versionHeaders(context)};

    // ETag / 304 — only for cacheable GETs with a 200 body.
    if (method == HttpMethod.get && response.statusCode == 200) {
      final body = await response.body();
      final hash = sha256.convert(utf8.encode(body)).toString();
      final etag = '"${hash.substring(0, 16)}"';
      final ifNoneMatch = context.request.headers['if-none-match'];
      if (ifNoneMatch == etag) {
        return Response(
          statusCode: 304,
          headers: {...extraHeaders, 'etag': etag},
        );
      }
      return Response(
        body: body,
        headers: {...response.headers, ...extraHeaders, 'etag': etag},
      );
    }

    return response.copyWith(
      headers: {...response.headers, ...extraHeaders},
    );
  };
}

String? _authenticate(RequestContext context) {
  final token = bearerToken(context.request.headers);
  final payload = verifyToken(token);
  return payload?['sub'] as String?;
}

bool _isProtected(String path) {
  final normalized = path.endsWith('/') && path.length > 1
      ? path.substring(0, path.length - 1)
      : path;
  return !_publicPathPrefixes.contains(normalized);
}

Map<String, String> _versionHeaders(RequestContext context) {
  final headers = <String, String>{};
  final raw = context.request.headers['x-sdui-version'];
  final clientVersion = int.tryParse(raw ?? '');
  if (clientVersion != null && clientVersion < _minSupportedClientVersion) {
    headers['x-sdui-deprecated'] = 'Client speaks SDUI v$clientVersion. '
        'Min supported is v$_minSupportedClientVersion - please update.';
  }
  headers['x-sdui-version'] = '$_serverSduiVersion';
  return headers;
}

const _corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  'access-control-allow-headers':
      'content-type, authorization, x-sdui-version, if-none-match',
  'access-control-expose-headers': 'x-sdui-version, x-sdui-deprecated, etag',
  'access-control-max-age': '86400',
};
