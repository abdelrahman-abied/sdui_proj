import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../routes/products/index.dart' as route;

class _MockRequestContext extends Mock implements RequestContext {}

class _MockRequest extends Mock implements Request {}

RequestContext _ctxFor({String? page}) {
  final ctx = _MockRequestContext();
  final req = _MockRequest();
  final qp = <String, String>{if (page != null) 'page': page};
  when(() => ctx.request).thenReturn(req);
  when(() => req.uri).thenReturn(Uri(path: '/products', queryParameters: qp));
  return ctx;
}

Future<Map<String, dynamic>> _bodyAsMap(Response r) async {
  return jsonDecode(await r.body()) as Map<String, dynamic>;
}

void main() {
  group('GET /products', () {
    test('default page wraps the list in a sduiScreen with a loading skeleton',
        () async {
      final response = route.onRequest(_ctxFor());
      final body = await _bodyAsMap(response);

      expect(body.containsKey('ui_tree'), isTrue);
      expect(body['screen_title'], 'Products');

      final skeleton = body['loading_skeleton'] as Map<String, dynamic>?;
      expect(skeleton, isNotNull, reason: 'page should ship a skeleton');
      // Skeleton mirrors the page shape — a vertical stack of placeholder
      // cards. The exact count is incidental; presence is what matters.
      expect(skeleton!['type'], 'VERTICAL_STACK');
      expect(skeleton['children'] as List, isNotEmpty);
    });

    test('over-paginated page returns an EMPTY_STATE without a skeleton',
        () async {
      final response = route.onRequest(_ctxFor(page: '999'));
      final body = await _bodyAsMap(response);

      // Empty state is a single SDUI node — no screen wrapper, no skeleton.
      expect(body['type'], 'EMPTY_STATE');
      expect(body.containsKey('loading_skeleton'), isFalse);
    });
  });
}
