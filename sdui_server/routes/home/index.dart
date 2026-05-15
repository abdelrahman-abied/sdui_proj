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
        backgroundColor: '@primary',
        padding: 16,
        children: [
          SDUIText(
            text: 'Welcome, ${user.username}',
            style: 'title',
            color: '@onPrimary',
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
      // Server-driven navigation: each row's URL is the next endpoint
      // the client will fetch — no client-side route table involved.
      Card(
        children: [
          ListItem(
            title: 'Products',
            subtitle: 'Browse the catalog',
            leadingIcon: 'shopping_bag',
            trailingIcon: 'chevron_right',
            action: sduiAction(type: 'navigate', url: '/products'),
          ),
          Divider(indent: 16),
          ListItem(
            title: 'Feed',
            subtitle: 'Latest updates',
            leadingIcon: 'home',
            trailingIcon: 'chevron_right',
            action: sduiAction(type: 'navigate', url: '/feed'),
          ),
          Divider(indent: 16),
          ListItem(
            title: 'Settings',
            subtitle: 'Preferences and account',
            leadingIcon: 'settings',
            trailingIcon: 'chevron_right',
            action: sduiAction(type: 'navigate', url: '/settings'),
          ),
          Divider(indent: 16),
          ListItem(
            title: 'Sign out',
            leadingIcon: 'logout',
            action: sduiConfirm(
              sduiAction(type: 'logout', url: '/login'),
              title: 'Sign out?',
              message: "You'll need to sign in again to use the app.",
              confirmLabel: 'Sign out',
              destructive: true,
            ),
          ),
        ],
      ),
      // Horizontal Scroll list
      SDUIText(text: 'Featured', style: 'subtitle', color: '@onBackground'),
      HorizontalScroll(
        children: [
          for (var i = 1; i <= 5; i++)
            SDUIContainer(
              margin: 12,
              padding: 12,
              cornerRadius: 8,
              backgroundColor: '@surface',
              action: sduiAction(type: 'navigate', url: '/product/$i'),
              children: [
                SDUIText(text: 'Item $i', color: '@onSurface'),
              ],
            ),
        ],
      ),
    ],
  );

  return Response.json(body: dashboard.toJson());
}
