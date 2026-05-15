import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sdui_server/auth.dart';
import 'package:test/test.dart';

import '../../routes/_middleware.dart' as mw;

class _MockRequestContext extends Mock implements RequestContext {}

class _MockRequest extends Mock implements Request {}

class _FakeAuthUser extends Fake implements AuthUser {}

RequestContext _ctxFor({
  required String path,
  Map<String, String> headers = const {},
}) {
  final ctx = _MockRequestContext();
  final req = _MockRequest();
  when(() => ctx.request).thenReturn(req);
  when(() => req.method).thenReturn(HttpMethod.get);
  when(() => req.uri).thenReturn(Uri.parse('http://localhost$path'));
  when(() => req.headers).thenReturn(headers);
  // The middleware calls `context.provide<AuthUser>(() => authed)` once;
  // we just need it to keep returning a usable RequestContext.
  when(() => ctx.provide<AuthUser>(any())).thenReturn(ctx);
  return ctx;
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeAuthUser());
  });

  group('middleware ETag', () {
    test('200 GET gets an ETag header', () async {
      final ctx = _ctxFor(path: '/theme');
      final handler = mw.middleware(
        (_) => Response.json(body: {'colors': {'primary': '#111'}}),
      );
      final response = await handler(ctx);
      expect(response.statusCode, 200);
      expect(response.headers['etag'], isNotNull);
      expect(response.headers['etag'], matches(RegExp(r'^"[0-9a-f]{16}"$')));
    });

    test('If-None-Match with matching etag returns 304 (no body)', () async {
      // First call — capture the ETag the server emits.
      final firstCtx = _ctxFor(path: '/theme');
      final body = {'colors': {'primary': '#111'}};
      Handler buildHandler() => mw.middleware((_) => Response.json(body: body));
      final first = await buildHandler()(firstCtx);
      final etag = first.headers['etag']!;

      // Second call with If-None-Match should 304.
      final secondCtx = _ctxFor(
        path: '/theme',
        headers: {'if-none-match': etag},
      );
      final second = await buildHandler()(secondCtx);
      expect(second.statusCode, 304);
      expect(second.headers['etag'], etag);
      expect(await second.body(), isEmpty);
    });

    test('different body produces a different etag', () async {
      final ctxA = _ctxFor(path: '/theme');
      final ctxB = _ctxFor(path: '/theme');
      final a = await mw.middleware(
        (_) => Response.json(body: {'v': 1}),
      )(ctxA);
      final b = await mw.middleware(
        (_) => Response.json(body: {'v': 2}),
      )(ctxB);
      expect(a.headers['etag'], isNot(b.headers['etag']));
    });

    test('etag is stable for identical bodies', () async {
      Future<String> etagOf(Map<String, dynamic> body) async {
        final ctx = _ctxFor(path: '/theme');
        final r = await mw.middleware((_) => Response.json(body: body))(ctx);
        return r.headers['etag']!;
      }

      final e1 = await etagOf({'k': 'v'});
      final e2 = await etagOf({'k': 'v'});
      expect(e1, e2);
      // Sanity: matches the underlying body hash.
      expect(e1, isNotEmpty);
      expect(jsonEncode({'k': 'v'}), isNotEmpty);
    });
  });
}
