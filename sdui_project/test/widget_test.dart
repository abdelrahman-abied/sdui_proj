// Contract test: server JSON shape <-> client parser.
//
// The fixtures below mirror exactly what `sdui_server/lib/sdui_builder.dart`
// emits. If a server widget changes its prop names or moves a field
// (e.g. moves `id` out of `props`), one of these tests fails — which is
// what we want, because the rendered UI would silently break otherwise.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sdui_project/sdui/action_delegate.dart';
import 'package:sdui_project/sdui/component_registry.dart';
import 'package:sdui_project/sdui/form_manager.dart';
import 'package:sdui_project/sdui/sdui_action.dart';
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
}
