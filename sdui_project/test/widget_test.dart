// Contract test: server JSON shape <-> client parser.
//
// The fixtures below mirror exactly what `sdui_server/lib/sdui_builder.dart`
// emits. If a server widget changes its prop names or moves a field
// (e.g. moves `id` out of `props`), one of these tests fails — which is
// what we want, because the rendered UI would silently break otherwise.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sdui_project/sdui/action_delegate.dart';
import 'package:sdui_project/sdui/component_registry.dart';
import 'package:sdui_project/sdui/form_manager.dart';
import 'package:sdui_project/sdui/sdui_action.dart';
import 'package:sdui_project/sdui/sdui_page_loader.dart';
import 'package:sdui_project/sdui/sdui_parser.dart';
import 'package:sdui_project/sdui/theme_registry.dart';
import 'package:sdui_project/utils/style_parser.dart';

Widget _wrap(Map<String, dynamic> json) => MaterialApp(
      home: Scaffold(body: SDUIParser(uiJson: json)),
    );

void main() {
  group('component registry', () {
    test('every server-emitted type has a client builder', () {
      const serverEmittedTypes = [
        'VERTICAL_STACK',
        'HORIZONTAL_SCROLL',
        'CONTAINER',
        'TEXT',
        'IMAGE',
        'BUTTON_PRIMARY',
        'INPUT_TEXT',
        'LAZY_LIST',
        // Phase 4 additions
        'DIVIDER',
        'ICON',
        'BADGE',
        'CARD',
        'LIST_ITEM',
        'CHECKBOX',
        'SWITCH',
        'RADIO_GROUP',
        'SELECT',
        'GRID_2_COL',
      ];
      for (final type in serverEmittedTypes) {
        expect(
          ComponentRegistry.getWidgetBuilder(type),
          isNotNull,
          reason: 'no builder registered for "$type"',
        );
      }
    });
  });

  group('parser renders without unknown-component banner', () {
    testWidgets('TEXT reads text + color + style preset from props', (tester) async {
      await tester.pumpWidget(_wrap({
        'type': 'TEXT',
        'props': {'text': 'Hello SDUI', 'style': 'title', 'color': '#1a1a2e'},
      }));
      expect(find.text('Hello SDUI'), findsOneWidget);
      expect(find.textContaining('Unknown Component'), findsNothing);
    });

    testWidgets('CONTAINER reads layout from props', (tester) async {
      await tester.pumpWidget(_wrap({
        'type': 'CONTAINER',
        'props': {
          'padding': 16,
          'margin': 8,
          'backgroundColor': '#ffffff',
          'cornerRadius': 8,
        },
        'children': [
          {'type': 'TEXT', 'props': {'text': 'Inside'}},
        ],
      }));
      expect(find.text('Inside'), findsOneWidget);
      expect(find.textContaining('Unknown Component'), findsNothing);
    });

    testWidgets('BUTTON_PRIMARY renders its label', (tester) async {
      await tester.pumpWidget(_wrap({
        'type': 'BUTTON_PRIMARY',
        'props': {'label': 'Sign In'},
        'action': {'type': 'navigate', 'url': '/home'},
      }));
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.textContaining('Unknown Component'), findsNothing);
    });

    testWidgets('HORIZONTAL_SCROLL renders its children', (tester) async {
      await tester.pumpWidget(_wrap({
        'type': 'HORIZONTAL_SCROLL',
        'children': [
          {'type': 'TEXT', 'props': {'text': 'A'}},
          {'type': 'TEXT', 'props': {'text': 'B'}},
        ],
      }));
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('IMAGE renders without throwing on missing network', (tester) async {
      await tester.pumpWidget(_wrap({
        'type': 'IMAGE',
        'props': {'url': 'https://example.invalid/x.png', 'height': 120},
      }));
      // Image hasn't loaded, but no Unknown Component banner.
      expect(find.textContaining('Unknown Component'), findsNothing);
    });
  });

  group('INPUT_TEXT', () {
    setUp(() => SDUIFormManager().clear());

    testWidgets('id is read from props (regression: was read from root)', (tester) async {
      await tester.pumpWidget(_wrap({
        'type': 'INPUT_TEXT',
        'props': {'id': 'email', 'label': 'Email'},
      }));
      await tester.enterText(find.byType(TextField), 'a@b.c');
      final exported = SDUIFormManager().export();
      expect(exported['email'], 'a@b.c');
      expect(exported.containsKey('unknown_id'), isFalse);
    });
  });

  group('display widgets', () {
    testWidgets('DIVIDER renders without error', (tester) async {
      await tester.pumpWidget(_wrap({'type': 'DIVIDER', 'props': {'thickness': 2}}));
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('ICON renders the named material icon', (tester) async {
      await tester.pumpWidget(_wrap({
        'type': 'ICON',
        'props': {'name': 'settings'},
      }));
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('BADGE renders its text', (tester) async {
      await tester.pumpWidget(_wrap({
        'type': 'BADGE',
        'props': {'text': 'NEW'},
      }));
      expect(find.text('NEW'), findsOneWidget);
    });

    testWidgets('CARD wraps its children', (tester) async {
      await tester.pumpWidget(_wrap({
        'type': 'CARD',
        'props': {},
        'children': [
          {'type': 'TEXT', 'props': {'text': 'In a card'}},
        ],
      }));
      expect(find.text('In a card'), findsOneWidget);
    });

    testWidgets('LIST_ITEM renders title + subtitle + icons', (tester) async {
      await tester.pumpWidget(_wrap({
        'type': 'LIST_ITEM',
        'props': {
          'title': 'Profile',
          'subtitle': 'demo@sdui.app',
          'leadingIcon': 'account_circle',
          'trailingIcon': 'chevron_right',
        },
      }));
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('demo@sdui.app'), findsOneWidget);
      expect(find.byIcon(Icons.account_circle), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });
  });

  group('form input widgets', () {
    setUp(() => SDUIFormManager().clear());

    testWidgets('CHECKBOX registers value in form manager and updates on tap', (tester) async {
      await tester.pumpWidget(_wrap({
        'type': 'CHECKBOX',
        'props': {'id': 'agree', 'label': 'I agree', 'default': false},
      }));
      expect(SDUIFormManager().export()['agree'], false);
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(SDUIFormManager().export()['agree'], true);
    });

    testWidgets('SWITCH registers value in form manager', (tester) async {
      await tester.pumpWidget(_wrap({
        'type': 'SWITCH',
        'props': {'id': 'dark_mode', 'label': 'Dark mode', 'default': true},
      }));
      expect(SDUIFormManager().export()['dark_mode'], true);
    });

    testWidgets('RADIO_GROUP picks up default and stores selection', (tester) async {
      await tester.pumpWidget(_wrap({
        'type': 'RADIO_GROUP',
        'props': {
          'id': 'plan',
          'label': 'Plan',
          'default': 'pro',
          'options': [
            {'value': 'free', 'label': 'Free'},
            {'value': 'pro', 'label': 'Pro'},
          ],
        },
      }));
      expect(SDUIFormManager().export()['plan'], 'pro');
      expect(find.text('Free'), findsOneWidget);
      expect(find.text('Pro'), findsOneWidget);
    });

    testWidgets('SELECT picks up default', (tester) async {
      await tester.pumpWidget(_wrap({
        'type': 'SELECT',
        'props': {
          'id': 'language',
          'label': 'Language',
          'default': 'en',
          'options': [
            {'value': 'en', 'label': 'English'},
            {'value': 'es', 'label': 'Español'},
          ],
        },
      }));
      expect(SDUIFormManager().export()['language'], 'en');
    });
  });

  group('theming', () {
    setUp(() {
      // Seed a known theme so the resolver is deterministic.
      ThemeRegistry.current = const SDUITheme(
        colors: {
          'primary': Color(0xFF1A1A2E),
          'danger': Color(0xFFC62828),
        },
        typography: {'title': 24, 'body': 14},
        radius: {'button': 8},
      );
    });

    test('@token resolves to the theme color', () {
      expect(StyleParser.parseColor('@primary'), const Color(0xFF1A1A2E));
      expect(StyleParser.parseColor('@danger'), const Color(0xFFC62828));
    });

    test('unknown @token returns null', () {
      expect(StyleParser.parseColor('@nope'), isNull);
    });

    test('raw hex still works alongside tokens', () {
      expect(StyleParser.parseColor('#1a1a2e'), const Color(0xFF1A1A2E));
    });

    test('SDUITheme.fromJson merges incoming colors over fallback', () {
      final theme = SDUITheme.fromJson({
        'colors': {'primary': '#abcdef'},
      });
      // Custom value wins…
      expect(theme.colors['primary'], const Color(0xFFABCDEF));
      // …but other fallback tokens are still available.
      expect(theme.colors['danger'], SDUITheme.fallback.colors['danger']);
    });
  });

  group('fallback_type', () {
    testWidgets('unknown type renders the fallback', (tester) async {
      await tester.pumpWidget(_wrap({
        'type': 'FUTURE_WIDGET_V2',
        'props': {'mystery': 42},
        'fallback_type': 'TEXT',
        'fallback_props': {'text': 'Update the app to see the new widget'},
      }));
      expect(find.text('Update the app to see the new widget'), findsOneWidget);
      expect(find.textContaining('Unknown Component'), findsNothing);
    });

    testWidgets('unknown type with no fallback still shows the banner', (tester) async {
      await tester.pumpWidget(_wrap({
        'type': 'NOPE_NEVER_HEARD_OF_IT',
        'props': {},
      }));
      expect(find.textContaining('Unknown Component'), findsOneWidget);
    });
  });

  group('Phase 5 — smarter actions', () {
    setUp(() => SDUIFormManager().clear());

    test('SDUIAction.fromJson parses sequence, condition, and confirm', () {
      final action = SDUIAction.fromJson({
        'type': 'sequence',
        'if': {'field': 'agree', 'equals': true},
        'confirm': {'title': 'Sure?', 'message': 'Really?'},
        'actions': [
          {'type': 'show_toast', 'data': {'message': 'one'}},
          {'type': 'navigate', 'url': '/home'},
        ],
      });
      expect(action.type, 'sequence');
      expect(action.condition!['field'], 'agree');
      expect(action.confirm!['title'], 'Sure?');
      expect(action.actions, hasLength(2));
      expect(action.actions![0].type, 'show_toast');
      expect(action.actions![1].url, '/home');
    });

    testWidgets('condition skips action when predicate is false', (tester) async {
      // Build a button whose tap would toast — but the condition is unmet,
      // so tapping should NOT show the snack.
      SDUIFormManager().set('agree', false);
      await tester.pumpWidget(_wrap({
        'type': 'BUTTON_PRIMARY',
        'props': {'label': 'Continue'},
        'action': {
          'type': 'show_toast',
          'data': {'message': 'should not appear'},
          'if': {'field': 'agree', 'equals': true},
        },
      }));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('should not appear'), findsNothing);
    });

    testWidgets('condition allows action when predicate matches', (tester) async {
      SDUIFormManager().set('agree', true);
      await tester.pumpWidget(_wrap({
        'type': 'BUTTON_PRIMARY',
        'props': {'label': 'Continue'},
        'action': {
          'type': 'show_toast',
          'data': {'message': 'fired'},
          'if': {'field': 'agree', 'equals': true},
        },
      }));
      await tester.tap(find.text('Continue'));
      await tester.pump(); // start snackbar animation
      expect(find.text('fired'), findsOneWidget);
    });

    testWidgets('confirm dialog appears and Cancel suppresses the action', (tester) async {
      await tester.pumpWidget(_wrap({
        'type': 'BUTTON_PRIMARY',
        'props': {'label': 'Delete'},
        'action': {
          'type': 'show_toast',
          'data': {'message': 'deleted'},
          'confirm': {
            'title': 'Delete this?',
            'message': 'Permanent.',
            'confirmLabel': 'Delete',
            'cancelLabel': 'Keep',
          },
        },
      }));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this?'), findsOneWidget);
      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();
      expect(find.text('deleted'), findsNothing);
    });

    testWidgets('sequence awaits inner actions before returning', (tester) async {
      final order = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                final a = SDUIAction.fromJson({
                  'type': 'sequence',
                  'actions': [
                    {'type': 'show_toast', 'data': {'message': 'one'}},
                    {'type': 'show_toast', 'data': {'message': 'two'}},
                  ],
                });
                order.add('start');
                await SDUIActionDelegate.handleAction(ctx, a);
                order.add('end');
              },
              child: const Text('Go'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      expect(order, ['start', 'end']);
    });
  });

  group('Phase 6 — ETag / 304 caching', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SDUIApiService.debugResetHydration();
    });

    tearDown(() {
      SDUIApiService.debugSetClient(http.Client());
    });

    test('first fetch stores the ETag, refresh sends If-None-Match and a 304 returns cached body', () async {
      final body = jsonEncode({'type': 'TEXT', 'props': {'text': 'hi'}});
      const etag = '"abc123def456abcd"';
      final requests = <http.Request>[];

      SDUIApiService.debugSetClient(MockClient((req) async {
        requests.add(req);
        if (requests.length == 1) {
          return http.Response(body, 200, headers: {
            'content-type': 'application/json',
            'etag': etag,
          });
        }
        // Second call: client should send If-None-Match; server replies 304.
        expect(req.headers['if-none-match'], etag);
        return http.Response('', 304, headers: {'etag': etag});
      }));

      final first = await SDUIApiService.fetchEndpoint('/probe');
      expect(first['type'], 'TEXT');
      expect(requests, hasLength(1));
      // First request has no If-None-Match — nothing cached yet.
      expect(requests.first.headers.containsKey('if-none-match'), isFalse);

      // Refresh: cache is bypassed for the read, but we still re-use the ETag.
      final second = await SDUIApiService.fetchEndpoint('/probe', useCache: false);
      expect(second['type'], 'TEXT');
      expect(requests, hasLength(2));
    });

    test('useCache: true returns the in-memory body without hitting the network', () async {
      final body = jsonEncode({'type': 'TEXT', 'props': {'text': 'cached'}});
      var calls = 0;
      SDUIApiService.debugSetClient(MockClient((req) async {
        calls++;
        return http.Response(body, 200, headers: {'etag': '"x"'});
      }));

      await SDUIApiService.fetchEndpoint('/probe');
      await SDUIApiService.fetchEndpoint('/probe');
      expect(calls, 1, reason: 'second call should be served from cache');
    });
  });

  group('Phase 6 — stale-while-revalidate', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SDUIApiService.debugResetHydration();
    });

    tearDown(() {
      SDUIApiService.debugSetClient(http.Client());
    });

    test('returns cached body immediately, then calls onRevalidate with fresh body', () async {
      final stale = jsonEncode({'type': 'TEXT', 'props': {'text': 'old'}});
      final fresh = jsonEncode({'type': 'TEXT', 'props': {'text': 'new'}});
      var calls = 0;
      SDUIApiService.debugSetClient(MockClient((req) async {
        calls++;
        if (calls == 1) {
          return http.Response(stale, 200, headers: {'etag': '"v1"'});
        }
        // Background revalidation sees a new ETag and a different body.
        expect(req.headers['if-none-match'], '"v1"');
        return http.Response(fresh, 200, headers: {'etag': '"v2"'});
      }));

      // Warm the cache.
      await SDUIApiService.fetchEndpoint('/probe');
      expect(calls, 1);

      // Second call with onRevalidate: returns cached synchronously and
      // dispatches a background refetch.
      Map<String, dynamic>? freshFromCallback;
      final returned = await SDUIApiService.fetchEndpoint(
        '/probe',
        onRevalidate: (v) => freshFromCallback = v,
      );
      expect(returned['props']['text'], 'old',
          reason: 'cached value should be returned synchronously');

      // Let the background fetch settle.
      await Future<void>.delayed(Duration.zero);
      expect(calls, 2);
      expect(freshFromCallback, isNotNull);
      expect(freshFromCallback!['props']['text'], 'new');
    });

    test('skips onRevalidate when the server responds 304', () async {
      final body = jsonEncode({'type': 'TEXT', 'props': {'text': 'same'}});
      var calls = 0;
      SDUIApiService.debugSetClient(MockClient((req) async {
        calls++;
        if (calls == 1) {
          return http.Response(body, 200, headers: {'etag': '"v1"'});
        }
        return http.Response('', 304, headers: {'etag': '"v1"'});
      }));

      await SDUIApiService.fetchEndpoint('/probe');

      var fired = false;
      await SDUIApiService.fetchEndpoint(
        '/probe',
        onRevalidate: (_) => fired = true,
      );
      await Future<void>.delayed(Duration.zero);

      expect(calls, 2);
      expect(fired, isFalse, reason: '304 means cached body is still current');
    });

    test('background fetch errors do not surface to the caller', () async {
      final body = jsonEncode({'type': 'TEXT', 'props': {'text': 'cached'}});
      var calls = 0;
      SDUIApiService.debugSetClient(MockClient((req) async {
        calls++;
        if (calls == 1) {
          return http.Response(body, 200, headers: {'etag': '"e"'});
        }
        throw Exception('network down');
      }));

      await SDUIApiService.fetchEndpoint('/probe');

      // The synchronous return must complete normally even if the
      // background revalidation throws.
      final cached = await SDUIApiService.fetchEndpoint(
        '/probe',
        onRevalidate: (_) {},
      );
      expect(cached['props']['text'], 'cached');
      await Future<void>.delayed(Duration.zero);
      expect(calls, 2);
    });
  });

  group('Phase 6 — server-driven TTL', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SDUIApiService.debugResetHydration();
    });

    tearDown(() {
      SDUIApiService.debugSetClient(http.Client());
    });

    test('fresh entry (within max-age) returns from cache without network', () async {
      final body = jsonEncode({'type': 'TEXT', 'props': {'text': 'fresh'}});
      var calls = 0;
      SDUIApiService.debugSetClient(MockClient((req) async {
        calls++;
        return http.Response(body, 200, headers: {
          'etag': '"e"',
          'cache-control': 'max-age=300',
        });
      }));

      await SDUIApiService.fetchEndpoint('/probe');
      await SDUIApiService.fetchEndpoint('/probe');
      expect(calls, 1, reason: 'second call is within max-age, must hit cache');
    });

    test('expired entry forces a foreground revalidation with If-None-Match', () async {
      final body = jsonEncode({'type': 'TEXT', 'props': {'text': 'aged'}});
      var calls = 0;
      String? lastIfNoneMatch;
      SDUIApiService.debugSetClient(MockClient((req) async {
        calls++;
        lastIfNoneMatch = req.headers['if-none-match'];
        // max-age=0 means every subsequent read is past expiry.
        return http.Response(body, 200, headers: {
          'etag': '"v1"',
          'cache-control': 'max-age=0',
        });
      }));

      await SDUIApiService.fetchEndpoint('/probe');
      // Even though useCache: true, the stored entry is already expired.
      await SDUIApiService.fetchEndpoint('/probe');
      expect(calls, 2);
      expect(lastIfNoneMatch, '"v1"',
          reason: 'expired path must still try the 304 shortcut');
    });

    test('304 on the expired path refreshes the TTL so the next read hits cache', () async {
      final body = jsonEncode({'type': 'TEXT', 'props': {'text': 'aged'}});
      var calls = 0;
      SDUIApiService.debugSetClient(MockClient((req) async {
        calls++;
        if (calls == 1) {
          // Seed: store the entry already expired (max-age=0).
          return http.Response(body, 200, headers: {
            'etag': '"v1"',
            'cache-control': 'max-age=0',
          });
        }
        // Foreground revalidation finds nothing has changed AND the server
        // now advertises a longer freshness window — entry should be reborn.
        expect(req.headers['if-none-match'], '"v1"');
        return http.Response('', 304, headers: {
          'etag': '"v1"',
          'cache-control': 'max-age=300',
        });
      }));

      await SDUIApiService.fetchEndpoint('/probe');
      // First read after seeding: entry is expired, forces revalidation.
      await SDUIApiService.fetchEndpoint('/probe');
      expect(calls, 2);
      // Now within the refreshed 300s window — must not hit the network.
      await SDUIApiService.fetchEndpoint('/probe');
      expect(calls, 2, reason: '304 should have refreshed the TTL');
    });

    test('no Cache-Control header keeps the legacy "never expires" semantics', () async {
      final body = jsonEncode({'type': 'TEXT', 'props': {'text': 'no-ttl'}});
      var calls = 0;
      SDUIApiService.debugSetClient(MockClient((req) async {
        calls++;
        return http.Response(body, 200, headers: {'etag': '"e"'});
      }));

      await SDUIApiService.fetchEndpoint('/probe');
      await SDUIApiService.fetchEndpoint('/probe');
      expect(calls, 1,
          reason: 'absent Cache-Control means no expiry hint — cache stays warm');
    });
  });

  group('Phase 6 — persistent disk cache', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SDUIApiService.debugResetHydration();
    });

    tearDown(() {
      SDUIApiService.debugSetClient(http.Client());
    });

    test('write seeds disk so the next cold start hydrates without a network call', () async {
      final body = jsonEncode({'type': 'TEXT', 'props': {'text': 'persisted'}});
      var calls = 0;
      SDUIApiService.debugSetClient(MockClient((req) async {
        calls++;
        return http.Response(body, 200, headers: {'etag': '"persisted-tag"'});
      }));

      // First "session" — populate the cache.
      await SDUIApiService.fetchEndpoint('/probe');
      // Let the unawaited CacheStore.save complete.
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);

      // Simulate a cold start: wipe in-memory state but keep the prefs blob.
      SDUIApiService.debugResetHydration();

      final hydrated = await SDUIApiService.fetchEndpoint('/probe');
      expect(hydrated['props']['text'], 'persisted');
      expect(calls, 1, reason: 'hydrated value should serve from disk, not hit the network');
    });

    test('after cold-start hydration, refresh sends the persisted ETag', () async {
      final body = jsonEncode({'type': 'TEXT', 'props': {'text': 'p2'}});
      var calls = 0;
      String? lastIfNoneMatch;
      SDUIApiService.debugSetClient(MockClient((req) async {
        calls++;
        lastIfNoneMatch = req.headers['if-none-match'];
        // Always respond 304 — the cached body should keep being returned.
        if (calls == 1) {
          return http.Response(body, 200, headers: {'etag': '"e1"'});
        }
        return http.Response('', 304, headers: {'etag': '"e1"'});
      }));

      // Session 1: warm the disk cache.
      await SDUIApiService.fetchEndpoint('/probe');
      await Future<void>.delayed(Duration.zero);

      // Cold start.
      SDUIApiService.debugResetHydration();

      // First call after cold start: served from disk, no network.
      final cached = await SDUIApiService.fetchEndpoint('/probe');
      expect(cached['props']['text'], 'p2');
      expect(calls, 1);

      // Refresh: we should now send If-None-Match with the persisted etag,
      // get a 304 back, and return the same body.
      final refreshed = await SDUIApiService.fetchEndpoint('/probe', useCache: false);
      expect(refreshed['props']['text'], 'p2');
      expect(calls, 2);
      expect(lastIfNoneMatch, '"e1"');
    });

    test('clearCache wipes the disk blob so future cold starts start empty', () async {
      final body = jsonEncode({'type': 'TEXT', 'props': {'text': 'gone'}});
      var calls = 0;
      SDUIApiService.debugSetClient(MockClient((req) async {
        calls++;
        return http.Response(body, 200, headers: {'etag': '"e"'});
      }));

      await SDUIApiService.fetchEndpoint('/probe');
      await Future<void>.delayed(Duration.zero);
      SDUIApiService.clearCache();
      // Give the fire-and-forget CacheStore.clear a tick to finish.
      await Future<void>.delayed(Duration.zero);
      SDUIApiService.debugResetHydration();

      // Cold start with no disk state: forced to hit the network.
      await SDUIApiService.fetchEndpoint('/probe');
      expect(calls, 2);
    });
  });
}
