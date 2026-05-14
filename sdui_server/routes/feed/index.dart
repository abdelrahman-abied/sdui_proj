import 'package:dart_frog/dart_frog.dart';
import 'package:sdui_server/sdui_builder.dart';

Response onRequest(RequestContext context) {
  final pageParam = context.request.uri.queryParameters['page'] ?? '1';
  final pageIndex = int.tryParse(pageParam) ?? 1;
  final nextPage = pageIndex + 1;

  final feed = LazyList(
    nextUrl: '/feed?page=$nextPage',
    children: [
      for (var i = (pageIndex - 1) * 10 + 1;
          i <= pageIndex * 10 && i <= 100;
          i++)
        SDUIContainer(
          margin: 8,
          padding: 16,
          backgroundColor: '#ffffff',
          cornerRadius: 8,
          children: [
            SDUIText(
              text: 'Feed Item $i',
              style: 'subtitle',
              color: '#333333',
            ),
            SDUIText(text: 'Content for item $i.', color: '#666666'),
          ],
        ),
    ],
  );

  return Response.json(body: feed.toJson());
}
