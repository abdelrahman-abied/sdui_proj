import 'package:dart_frog/dart_frog.dart';
import 'package:sdui_server/auth.dart';

/// App entrypoint. The server picks where the client should start, based on
/// the JWT the client attaches (if any). The global middleware has already
/// validated the token by the time this handler runs.
Response onRequest(RequestContext context) {
  final user = context.read<AuthUser>();
  final target = user.isAnonymous ? '/login' : '/home';
  return Response(statusCode: 302, headers: {'location': target});
}
