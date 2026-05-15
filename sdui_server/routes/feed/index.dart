import 'package:dart_frog/dart_frog.dart';
import 'package:sdui_server/sdui_builder.dart';

const _totalItems = 100;
const _pageSize = 10;

Response onRequest(RequestContext context) {
  final pageParam = context.request.uri.queryParameters['page'] ?? '1';
  final pageIndex = int.tryParse(pageParam) ?? 1;
  final firstId = (pageIndex - 1) * _pageSize + 1;
  final lastId = pageIndex * _pageSize;
  final hasMore = lastId < _totalItems;

  final feed = LazyList(
    nextUrl: hasMore ? '/feed?page=${pageIndex + 1}' : null,
    children: [
      for (var i = firstId; i <= lastId && i <= _totalItems; i++)
        SDUIContainer(
          margin: 8,
          padding: 16,
          backgroundColor: '@background',
          cornerRadius: 8,
          children: [
            SDUIText(
              text: 'Feed Item $i',
              style: 'subtitle',
              color: '@onBackground',
            ),
            SDUIText(text: 'Content for item $i.', color: '@muted'),
          ],
        ),
    ],
  );

  return Response.json(body: feed.toJson());
}
