// Contract test: server JSON shape <-> client parser.
//
// The fixtures below mirror exactly what `sdui_server/lib/sdui_builder.dart`
// emits. If a server widget changes its prop names or moves a field
// (e.g. moves `id` out of `props`), one of these tests fails — which is
// what we want, because the rendered UI would silently break otherwise.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sdui_project/sdui/component_registry.dart';
import 'package:sdui_project/sdui/form_manager.dart';
import 'package:sdui_project/sdui/sdui_parser.dart';

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
}
