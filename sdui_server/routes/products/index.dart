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

  // Over-paginated: nothing on this page. Return a server-driven empty
  // state instead of an empty LAZY_LIST that would render as a blank
  // screen on the client.
  if (ids.isEmpty) {
    final empty = EmptyState(
      icon: 'shopping_bag',
      title: 'No products on this page',
      subtitle: 'Page $pageIndex is past the end of the catalog. '
          'Head back to the start to keep browsing.',
      actionLabel: 'Back to page 1',
      action: sduiAction(type: 'navigate', url: '/products?page=1'),
    );
    return Response.json(body: empty.toJson());
  }

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

  // Shape-matched skeleton: same card layout, blank tiles. The client renders
  // this while the page is fetching on the *next* visit (cached responses
  // carry the skeleton through to disk).
  final skeleton = VerticalStack(
    children: [
      for (var i = 0; i < _pageSize; i++)
        SDUIContainer(
          margin: 8,
          padding: 16,
          backgroundColor: '@surface',
          cornerRadius: 8,
          children: [
            SDUIContainer(
              backgroundColor: '@muted',
              cornerRadius: 8,
              children: [SDUIImage(url: '', height: 160)],
            ),
            SDUIText(text: ' ', style: 'subtitle', color: '@muted'),
            SDUIText(text: ' ', color: '@muted'),
          ],
        ),
    ],
  );

  return Response.json(
    body: sduiScreen(
      title: 'Products',
      tree: products,
      loadingSkeleton: skeleton,
    ),
  );
}
