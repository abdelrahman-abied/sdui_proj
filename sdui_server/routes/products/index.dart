import 'package:dart_frog/dart_frog.dart';
import 'package:sdui_server/sdui_actions.dart';
import 'package:sdui_server/sdui_builder.dart';

Response onRequest(RequestContext context) {
  final pageParam = context.request.uri.queryParameters['page'] ?? '1';
  final pageIndex = int.tryParse(pageParam) ?? 1;
  final nextPage = pageIndex + 1;

  final products = LazyList(
    nextUrl: '/products?page=$nextPage',
    children: [
      for (var i = (pageIndex - 1) * 10 + 1;
          i <= pageIndex * 10 && i <= 50;
          i++)
        SDUIContainer(
          margin: 8,
          padding: 16,
          backgroundColor: '#ffffff',
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
              color: '#1a1a2e',
            ),
            SDUIText(
              text: '\$${(i * 9.99).toStringAsFixed(2)}',
              color: '#666666',
            ),
          ],
        ),
    ],
  );

  return Response.json(body: products.toJson());
}
