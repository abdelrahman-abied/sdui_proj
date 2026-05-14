import 'package:dart_frog/dart_frog.dart';
import 'package:sdui_server/auth.dart';
import 'package:sdui_server/sdui_actions.dart';
import 'package:sdui_server/sdui_builder.dart';

Response onRequest(RequestContext context) {
  final user = context.read<AuthUser>();
  final dashboard = VerticalStack(
    children: [
      // Header — greets the signed-in user
      SDUIContainer(
        backgroundColor: '#1a1a2e',
        padding: 16,
        children: [
          SDUIText(
            text: 'Welcome, ${user.username}',
            style: 'title',
            color: '#ffffff',
          ),
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
          ButtonPrimary(
            label: 'Sign Out',
            action: sduiAction(type: 'logout', url: '/login'),
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
