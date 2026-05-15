import 'package:dart_frog/dart_frog.dart';
import 'package:sdui_server/sdui_builder.dart';
import 'package:sdui_server/sdui_actions.dart';

// Matches the catalog size in /products.
const _catalogSize = 50;

Response onRequest(RequestContext context, String id) {
  final productId = int.tryParse(id);

  // Unknown id → server-rendered 404 with an EMPTY_STATE recovery panel
  // the client can show in place of the page (instead of a generic error).
  if (productId == null || productId < 1 || productId > _catalogSize) {
    final notFound = EmptyState(
      icon: 'shopping_bag',
      title: 'Product not found',
      subtitle: 'We could not find a product with id "$id". '
          'It may have been removed from the catalog.',
      actionLabel: 'Back to products',
      action: sduiAction(type: 'navigate', url: '/products'),
    );
    return Response.json(statusCode: 404, body: notFound.toJson());
  }

  final page = VerticalStack(
    children: [
      SDUIContainer(
        padding: 16,
        children: [
          SDUIText(
            text: 'Product #$productId',
            style: 'title',
            color: '@primary',
          ),
          SDUIImage(
            url: 'https://picsum.photos/400/300?seed=$productId',
            height: 300,
          ),
          SDUIText(
            text:
                'Description for product $productId. Dynamic content from server.',
            color: '@onBackground',
          ),
          ButtonPrimary(
            label: 'Add to Cart',
            action: sduiAction(
              type: 'form_submit',
              url: '/cart/add',
              data: {'productId': productId},
            ),
          ),
        ],
      ),
    ],
  );

  return Response.json(body: page.toJson());
}
