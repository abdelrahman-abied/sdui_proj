import 'package:dart_frog/dart_frog.dart';
import 'package:sdui_server/sdui_builder.dart';
import 'package:sdui_server/sdui_actions.dart';

Response onRequest(RequestContext context, String id) {
  final productId = id;
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
