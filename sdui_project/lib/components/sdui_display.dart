import 'package:flutter/material.dart';

import '../sdui/sdui_parser.dart';
import '../utils/style_parser.dart';

/// Map of Material icon names → IconData. Extend as needed. Names match
/// what the server emits in ICON.props.name.
const Map<String, IconData> _iconLookup = {
  'settings': Icons.settings,
  'account_circle': Icons.account_circle,
  'chevron_right': Icons.chevron_right,
  'star': Icons.star,
  'favorite': Icons.favorite,
  'home': Icons.home,
  'notifications': Icons.notifications,
  'logout': Icons.logout,
  'shopping_cart': Icons.shopping_cart,
  'shopping_bag': Icons.shopping_bag,
  'search': Icons.search,
  'info': Icons.info_outline,
  'check': Icons.check,
  'close': Icons.close,
  'add': Icons.add,
  'remove': Icons.remove,
  'edit': Icons.edit,
  'delete': Icons.delete,
  'arrow_forward': Icons.arrow_forward,
  'arrow_back': Icons.arrow_back,
  'menu': Icons.menu,
  'person': Icons.person,
};

class SDUIDivider extends StatelessWidget {
  final double thickness;
  final double indent;
  final Color? color;

  const SDUIDivider({
    super.key,
    this.thickness = 1,
    this.indent = 0,
    this.color,
  });

  factory SDUIDivider.fromProps(Map<String, dynamic> props) => SDUIDivider(
        thickness: (props['thickness'] as num?)?.toDouble() ?? 1,
        indent: (props['indent'] as num?)?.toDouble() ?? 0,
        color: StyleParser.parseColor(props['color'] as String?),
      );

  @override
  Widget build(BuildContext context) => Divider(
        thickness: thickness,
        indent: indent,
        endIndent: indent,
        color: color,
      );
}

class SDUIIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;

  const SDUIIcon({super.key, required this.icon, this.size = 24, this.color});

  factory SDUIIcon.fromProps(Map<String, dynamic> props) {
    final name = props['name']?.toString() ?? '';
    return SDUIIcon(
      icon: _iconLookup[name] ?? Icons.help_outline,
      size: (props['size'] as num?)?.toDouble() ?? 24,
      color: StyleParser.parseColor(props['color'] as String?),
    );
  }

  @override
  Widget build(BuildContext context) => Icon(icon, size: size, color: color);
}

class SDUIBadge extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;

  const SDUIBadge({
    super.key,
    required this.text,
    this.background = const Color(0xFFE3F2FD),
    this.foreground = const Color(0xFF1565C0),
  });

  factory SDUIBadge.fromProps(Map<String, dynamic> props) => SDUIBadge(
        text: props['text']?.toString() ?? '',
        background: StyleParser.parseColor(props['backgroundColor'] as String?) ??
            const Color(0xFFE3F2FD),
        foreground: StyleParser.parseColor(props['color'] as String?) ??
            const Color(0xFF1565C0),
      );

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      );
}

class SDUICard extends StatelessWidget {
  final Map<String, dynamic> uiJson;
  const SDUICard({super.key, required this.uiJson});

  @override
  Widget build(BuildContext context) {
    final props = Map<String, dynamic>.from(uiJson['props'] as Map? ?? {});
    final children = (uiJson['children'] as List? ?? []);
    final padding = StyleParser.parsePadding(props);
    final margin = StyleParser.parseMargin(props);
    final elevation = (props['elevation'] as num?)?.toDouble() ?? 1.0;

    final body = children.length == 1
        ? SDUIParser(uiJson: Map<String, dynamic>.from(children.first as Map))
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children
                .map((c) => SDUIParser(uiJson: Map<String, dynamic>.from(c as Map)))
                .toList(),
          );

    return Padding(
      padding: margin == EdgeInsets.zero ? const EdgeInsets.all(8) : margin,
      child: Card(
        elevation: elevation,
        child: Padding(
          padding: padding == EdgeInsets.zero ? const EdgeInsets.all(16) : padding,
          child: body,
        ),
      ),
    );
  }
}

/// Full-screen empty state — large muted icon + title + optional subtitle,
/// plus a visual "button" affordance when [actionLabel] is set. The actual
/// tap handling lives at the parser level: when the node carries an
/// `action`, the parser wraps the whole widget in a GestureDetector so
/// tapping anywhere triggers the recovery flow.
class SDUIEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;

  const SDUIEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
  });

  factory SDUIEmptyState.fromProps(Map<String, dynamic> props) {
    final iconName = props['icon']?.toString() ?? '';
    return SDUIEmptyState(
      icon: _iconLookup[iconName] ?? Icons.inbox_outlined,
      title: props['title']?.toString() ?? '',
      subtitle: props['subtitle'] as String?,
      actionLabel: props['action_label'] as String?,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: theme.disabledColor),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: TextStyle(color: theme.hintColor),
              textAlign: TextAlign.center,
            ),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                actionLabel!,
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SDUIListItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final IconData? trailingIcon;

  const SDUIListItem({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.trailingIcon,
  });

  factory SDUIListItem.fromProps(Map<String, dynamic> props) => SDUIListItem(
        title: props['title']?.toString() ?? '',
        subtitle: (props['subtitle'] as String?),
        leadingIcon: _iconLookup[props['leadingIcon']?.toString() ?? ''],
        trailingIcon: _iconLookup[props['trailingIcon']?.toString() ?? ''],
      );

  @override
  Widget build(BuildContext context) => ListTile(
        leading: leadingIcon == null ? null : Icon(leadingIcon),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: trailingIcon == null ? null : Icon(trailingIcon),
      );
}
