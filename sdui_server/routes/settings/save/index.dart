import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:sdui_server/sdui_actions.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405, body: 'method not allowed');
  }
  final body = await context.request.json();
  // In a real app: persist to a database. Here we just echo back.
  return Response.json(
    body: {
      'message': 'Preferences saved',
      'saved': body,
      'action': sduiAction(type: 'pop'),
    },
  );
}
