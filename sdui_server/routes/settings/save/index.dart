import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:sdui_server/sdui_actions.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405, body: 'method not allowed');
  }
  final body = await context.request.json();
  if (body is! Map) {
    return Response.json(body: sduiFieldErrors({'_': 'Bad request body'}));
  }

  // Server-side validation. The client paints these inline on the
  // corresponding form widgets and stays on the page.
  final errors = <String, String>{};
  final plan = body['plan'] as String?;
  if (plan != 'free' && plan != 'pro' && plan != 'team') {
    errors['plan'] = 'Pick a plan';
  }
  final language = body['language'] as String?;
  if (language == null || language.isEmpty) {
    errors['language'] = 'Pick a language';
  }
  if (errors.isNotEmpty) {
    return Response.json(body: sduiFieldErrors(errors));
  }

  // Success: chain a toast and a navigate-back. The client runs them in
  // order. `clear_form: true` empties the form fields after the sequence.
  return Response.json(
    body: {
      'clear_form': true,
      'action': sduiSequence([
        sduiAction(
          type: 'show_toast',
          data: {'message': 'Preferences saved'},
        ),
        sduiAction(type: 'pop'),
      ]),
      'saved': body,
    },
  );
}
