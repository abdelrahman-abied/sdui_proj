import 'package:dart_frog/dart_frog.dart';
import 'package:sdui_server/sdui_actions.dart';
import 'package:sdui_server/sdui_builder.dart' as sdui;

Response onRequest(RequestContext context) {
  final page = sdui.VerticalStack(
    children: [
      sdui.SDUIContainer(
        backgroundColor: '@primary',
        padding: 16,
        children: [
          sdui.SDUIText(
            text: 'Settings',
            style: 'title',
            color: '@onPrimary',
          ),
        ],
      ),

      // Profile card showcasing CARD + LIST_ITEM + DIVIDER + ICON
      sdui.Card(
        children: [
          sdui.ListItem(
            title: 'Profile',
            subtitle: 'demo@sdui.app',
            leadingIcon: 'account_circle',
            trailingIcon: 'chevron_right',
            action: sduiAction(type: 'show_toast', data: {'message': 'Profile tapped'}),
          ),
          sdui.Divider(indent: 16),
          sdui.ListItem(
            title: 'Notifications',
            subtitle: '3 unread',
            leadingIcon: 'notifications',
            trailingIcon: 'chevron_right',
          ),
        ],
      ),

      // Preferences form — CHECKBOX + SWITCH + RADIO_GROUP + SELECT
      sdui.SDUIContainer(
        padding: 16,
        children: [
          sdui.SDUIText(text: 'Preferences', style: 'subtitle'),
          sdui.Checkbox(
            id: 'newsletter',
            label: 'Subscribe to newsletter',
            defaultValue: true,
          ),
          sdui.Switch(
            id: 'dark_mode',
            label: 'Dark mode',
          ),
          sdui.Divider(),
          sdui.RadioGroup(
            id: 'plan',
            label: 'Plan',
            defaultValue: 'pro',
            options: [
              {'value': 'free', 'label': 'Free'},
              {'value': 'pro', 'label': r'Pro ($9/mo)'},
              {'value': 'team', 'label': r'Team ($29/mo)'},
            ],
          ),
          sdui.Select(
            id: 'language',
            label: 'Language',
            defaultValue: 'en',
            options: [
              {'value': 'en', 'label': 'English'},
              {'value': 'ar', 'label': 'العربية'},
              {'value': 'es', 'label': 'Español'},
              {'value': 'de', 'label': 'Deutsch'},
            ],
          ),
        ],
      ),

      // Badges row — BADGE inside HORIZONTAL_SCROLL
      sdui.SDUIContainer(
        padding: 16,
        children: [
          sdui.SDUIText(text: 'Tags', style: 'subtitle'),
          sdui.HorizontalScroll(
            children: [
              sdui.Badge(text: 'Beta'),
              sdui.Badge(text: 'Pro', backgroundColor: '#FFF3E0', color: '#E65100'),
              sdui.Badge(text: 'New', backgroundColor: '#E8F5E9', color: '#2E7D32'),
              sdui.Badge(text: 'Sale', backgroundColor: '#FFEBEE', color: '#C62828'),
            ],
          ),
        ],
      ),

      sdui.SDUIContainer(
        padding: 16,
        children: [
          sdui.ButtonPrimary(
            label: 'Save Preferences',
            action: sduiAction(
              type: 'form_submit',
              url: '/settings/save',
            ),
          ),
        ],
      ),
    ],
  );

  return Response.json(body: page.toJson());
}
