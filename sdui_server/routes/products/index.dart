import 'package:dart_frog/dart_frog.dart';
import 'package:sdui_server/sdui_actions.dart';
import 'package:sdui_server/sdui_builder.dart';

const _totalProducts = 50;
const _pageSize = 10;

Response onRequest(RequestContext context) {
  final pageParam = context.request.uri.queryParameters['page'] ?? '1';
  final pageIndex = int.tryParse(pageParam) ?? 1;
  final firstId = (pageIndex - 1) * _pageSize + 1;
  final lastId = pageIndex * _pageSize;

  final ids = [
    for (var i = firstId; i <= lastId && i <= _totalProducts; i++) i,
  ];
  final hasMore = lastId < _totalProducts;

  final products = LazyList(
    nextUrl: hasMore ? '/products?page=${pageIndex + 1}' : null,
    children: [
      for (final i in ids)
        SDUIContainer(
          margin: 8,
          padding: 16,
          backgroundColor: '@background',
          cornerRadius: 8,
          action: sduiAction(type: 'navigate', url: '/product/$i'),
          children: [
            SDUIImage(
              url: 'https://picsum.photos/300/200?seed=$i',
              height: 160,
            ),
            SDUIText(
              text: 'Product $i',
              style: 'subtitle',
              color: '@primary',
            ),
            SDUIText(
              text: '\$${(i * 9.99).toStringAsFixed(2)}',
              color: '@muted',
            ),
          ],
        ),
    ],
  );

  return Response.json(body: products.toJson());
}
