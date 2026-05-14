import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:sdui_server/sdui_actions.dart';

/// Mock credentials store. Replace with a real check when you wire auth.
const _mockUsername = 'demo@sdui.app';
const _mockPassword = 'password';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405, body: 'method not allowed');
  }

  final body = await context.request.json();
  if (body is! Map) {
    return Response.json(
      statusCode: 400,
      body: {'action': _toastError('Bad request body')},
    );
  }

  final username = (body['username'] as String?)?.trim() ?? '';
  final password = (body['password'] as String?) ?? '';

  if (username.isEmpty || password.isEmpty) {
    return Response.json(
      body: {'action': _toastError('Username and password are required')},
    );
  }

  if (username != _mockUsername || password != _mockPassword) {
    return Response.json(
      body: {'action': _toastError('Invalid credentials')},
    );
  }

  // Success: server decides the post-login destination.
  return Response.json(
    body: {
      'action': sduiAction(type: 'navigate', url: '/home'),
      'message': 'Welcome, $username',
    },
  );
}

Map<String, dynamic> _toastError(String message) => sduiAction(
      type: 'show_toast',
      data: {'message': message, 'is_error': true},
    );
