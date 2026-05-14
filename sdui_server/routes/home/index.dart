import 'package:dart_frog/dart_frog.dart';
import 'package:sdui_server/sdui_actions.dart';
import 'package:sdui_server/sdui_builder.dart';

Response onRequest(RequestContext context) {
  final dashboard = VerticalStack(
    children: [
      // Header
      SDUIContainer(
        backgroundColor: '#1a1a2e',
        padding: 16,
        children: [
          SDUIText(text: 'Dashboard', style: 'title', color: '#ffffff'),
        ],
      ),
      // Banner
      SDUIContainer(
        margin: 12,
        cornerRadius: 12,
        children: [
          SDUIImage(
            url: 'https://picsum.photos/800/200',
            height: 200,
          ),
        ],
      ),
      // Server-driven navigation: each button's URL is the next endpoint
      // the client will fetch — no client-side route table involved.
      SDUIContainer(
        padding: 16,
        children: [
          ButtonPrimary(
            label: 'Show Products',
            action: sduiAction(type: 'navigate', url: '/products'),
          ),
          ButtonPrimary(
            label: 'Open Product #123',
            action: sduiAction(type: 'navigate', url: '/product/123'),
          ),
          ButtonPrimary(
            label: 'Browse Feed',
            action: sduiAction(type: 'navigate', url: '/feed'),
          ),
        ],
      ),
      // Horizontal Scroll list
      SDUIText(text: 'Featured', style: 'subtitle', color: '#333333'),
      HorizontalScroll(
        children: [
          for (var i = 1; i <= 5; i++)
            SDUIContainer(
              margin: 12,
              padding: 12,
              cornerRadius: 8,
              backgroundColor: '#f0f0f0',
              action: sduiAction(type: 'navigate', url: '/product/$i'),
              children: [
                SDUIText(text: 'Item $i', color: '#000000'),
              ],
            ),
        ],
      ),
    ],
  );

  return Response.json(body: dashboard.toJson());
}
