import 'package:dart_frog/dart_frog.dart';
import 'package:sdui_server/auth.dart';

/// Returns the authenticated user. The global middleware enforces JWT auth
/// before this handler runs; if we get here, the user is real.
Response onRequest(RequestContext context) {
  final user = context.read<AuthUser>();
  return Response.json(
    body: {
      'username': user.username,
    },
  );
}
