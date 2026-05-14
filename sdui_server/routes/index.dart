import 'package:dart_frog/dart_frog.dart';

/// App entrypoint. The server picks where the client should start.
/// Today: send everyone to /login. Later this can branch on auth
/// (e.g. read a session cookie and redirect to /home if signed in)
/// without any client change.
Response onRequest(RequestContext context) {
  return Response(
    statusCode: 302,
    headers: {'location': '/login'},
  );
}
