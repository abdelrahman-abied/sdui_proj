import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

/// JWT secret. Override in production via `SDUI_JWT_SECRET` env var.
String get _secret =>
    Platform.environment['SDUI_JWT_SECRET'] ?? 'dev-secret-change-me';

SecretKey get _key => SecretKey(_secret);

/// Sign-and-issue a JWT for the given username. Expires in 24h.
String issueToken(String username) {
  final jwt = JWT({'sub': username}, issuer: 'sdui_server');
  return jwt.sign(_key, expiresIn: const Duration(hours: 24));
}

/// Returns the JWT payload (e.g. `{sub: 'demo@sdui.app'}`) if the token is
/// valid and unexpired, or null otherwise.
Map<String, dynamic>? verifyToken(String? token) {
  if (token == null || token.isEmpty) return null;
  try {
    final jwt = JWT.verify(token, _key);
    final payload = jwt.payload;
    if (payload is Map) return Map<String, dynamic>.from(payload);
    return null;
  } on JWTExpiredException {
    return null;
  } on JWTException {
    return null;
  }
}

/// Reads a bearer token from the `Authorization: Bearer <jwt>` header.
String? bearerToken(Map<String, String> headers) {
  final raw = headers['authorization'] ?? headers['Authorization'];
  if (raw == null) return null;
  final parts = raw.split(' ');
  if (parts.length != 2 || parts[0].toLowerCase() != 'bearer') return null;
  return parts[1];
}

/// Authenticated user pulled out of the JWT and injected into request
/// context by the global middleware. Anonymous when the route is public.
class AuthUser {
  const AuthUser({required this.username});
  final String username;

  static const anonymous = AuthUser(username: '');
  bool get isAnonymous => username.isEmpty;
}
