import 'package:dart_frog/dart_frog.dart';

/// Brand tokens for the client. Edit this map to change the app's look
/// without touching any client code. Tokens here are referenced from
/// component JSON as `@primary`, `@danger`, etc.
const _theme = {
  'colors': {
    'primary': '#1a1a2e',
    'secondary': '#16213e',
    'background': '#ffffff',
    'surface': '#f5f5f5',
    'onPrimary': '#ffffff',
    'onSurface': '#1a1a2e',
    'onBackground': '#1a1a2e',
    'muted': '#666666',
    'danger': '#c62828',
    'success': '#2e7d32',
    'warning': '#f57c00',
    'info': '#1565c0',
  },
  'typography': {
    'title': 24.0,
    'subtitle': 18.0,
    'body': 14.0,
    'caption': 12.0,
  },
  'radius': {
    'card': 12.0,
    'button': 8.0,
    'input': 8.0,
  },
};

Response onRequest(RequestContext context) {
  return Response.json(body: _theme);
}
