/// Abstract base for all SDUI widgets.
/// Server defines View via type, props, optional children, and optional action.
///
/// [fallbackType] / [fallbackProps] let the server ship a primary type that
/// only newer clients understand, with a back-compat node older clients can
/// render. The client parser uses them automatically when `type` has no
/// registered builder.
abstract class SDUIWidget {
  const SDUIWidget({
    required this.type,
    this.props = const {},
    this.children,
    this.action,
    this.fallbackType,
    this.fallbackProps,
  });

  final String type;
  final Map<String, dynamic> props;
  final List<SDUIWidget>? children;
  final Map<String, dynamic>? action;
  final String? fallbackType;
  final Map<String, dynamic>? fallbackProps;

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'props': props,
      if (children != null && children!.isNotEmpty)
        'children': children!.map((c) => c.toJson()).toList(),
      if (action != null) 'action': action,
      if (fallbackType != null) 'fallback_type': fallbackType,
      if (fallbackProps != null) 'fallback_props': fallbackProps,
    };
  }
}

// --- Concrete widget classes ---

class VerticalStack extends SDUIWidget {
  VerticalStack({
    super.children,
    super.action,
  }) : super(type: 'VERTICAL_STACK', props: {});
}

class HorizontalScroll extends SDUIWidget {
  HorizontalScroll({
    super.children,
    super.action,
  }) : super(type: 'HORIZONTAL_SCROLL', props: {});
}

class SDUIText extends SDUIWidget {
  SDUIText({
    required String text,
    String? style,
    String? color,
    super.action,
  }) : super(
          type: 'TEXT',
          props: {
            'text': text,
            if (style != null) 'style': style,
            if (color != null) 'color': color,
          },
        );
}

class ButtonPrimary extends SDUIWidget {
  ButtonPrimary({
    required String label,
    super.action,
  }) : super(type: 'BUTTON_PRIMARY', props: {'label': label});
}

class SDUIImage extends SDUIWidget {
  SDUIImage({
    required String url,
    double? height,
    super.action,
  }) : super(
          type: 'IMAGE',
          props: {
            'url': url,
            if (height != null) 'height': height,
          },
        );
}

class InputText extends SDUIWidget {
  InputText({
    required String id,
    String? label,
    String? placeholder,
    super.action,
  }) : super(
          type: 'INPUT_TEXT',
          props: {
            'id': id,
            if (label != null) 'label': label,
            if (placeholder != null) 'placeholder': placeholder,
          },
        );
}

class LazyList extends SDUIWidget {
  LazyList({
    String? nextUrl,
    super.children,
    super.action,
  }) : super(
          type: 'LAZY_LIST',
          props: {if (nextUrl != null) 'nextUrl': nextUrl},
        );
}

class SDUIContainer extends SDUIWidget {
  SDUIContainer({
    double? padding,
    double? margin,
    String? backgroundColor,
    double? cornerRadius,
    super.children,
    super.action,
  }) : super(
          type: 'CONTAINER',
          props: {
            if (padding != null) 'padding': padding,
            if (margin != null) 'margin': margin,
            if (backgroundColor != null) 'backgroundColor': backgroundColor,
            if (cornerRadius != null) 'cornerRadius': cornerRadius,
          },
        );
}

/// Horizontal rule.
class Divider extends SDUIWidget {
  Divider({double? thickness, String? color, double? indent})
      : super(
          type: 'DIVIDER',
          props: {
            if (thickness != null) 'thickness': thickness,
            if (color != null) 'color': color,
            if (indent != null) 'indent': indent,
          },
        );
}

/// Material icon by name (e.g. `'settings'`, `'chevron_right'`).
class SDUIIcon extends SDUIWidget {
  SDUIIcon({required String name, double? size, String? color, super.action})
      : super(
          type: 'ICON',
          props: {
            'name': name,
            if (size != null) 'size': size,
            if (color != null) 'color': color,
          },
        );
}

/// Small label / pill.
class Badge extends SDUIWidget {
  Badge({
    required String text,
    String? backgroundColor,
    String? color,
  }) : super(
          type: 'BADGE',
          props: {
            'text': text,
            if (backgroundColor != null) 'backgroundColor': backgroundColor,
            if (color != null) 'color': color,
          },
        );
}

/// Material Card — elevated container with default padding.
class Card extends SDUIWidget {
  Card({
    double? padding,
    double? margin,
    double? elevation,
    super.children,
    super.action,
  }) : super(
          type: 'CARD',
          props: {
            if (padding != null) 'padding': padding,
            if (margin != null) 'margin': margin,
            if (elevation != null) 'elevation': elevation,
          },
        );
}

/// Single boolean toggle as a checkbox. Registers under [id] in the form
/// manager; the value is `true` / `false`.
class Checkbox extends SDUIWidget {
  Checkbox({
    required String id,
    required String label,
    bool defaultValue = false,
  }) : super(
          type: 'CHECKBOX',
          props: {
            'id': id,
            'label': label,
            'default': defaultValue,
          },
        );
}

/// Boolean toggle rendered as an iOS-style switch.
class Switch extends SDUIWidget {
  Switch({
    required String id,
    required String label,
    bool defaultValue = false,
  }) : super(
          type: 'SWITCH',
          props: {
            'id': id,
            'label': label,
            'default': defaultValue,
          },
        );
}

/// Single-select radio group. [options] is a list of {value, label} maps.
class RadioGroup extends SDUIWidget {
  RadioGroup({
    required String id,
    required String label,
    required List<Map<String, String>> options,
    String? defaultValue,
  }) : super(
          type: 'RADIO_GROUP',
          props: {
            'id': id,
            'label': label,
            'options': options,
            if (defaultValue != null) 'default': defaultValue,
          },
        );
}

/// Dropdown select. Same option shape as [RadioGroup].
class Select extends SDUIWidget {
  Select({
    required String id,
    required String label,
    required List<Map<String, String>> options,
    String? defaultValue,
  }) : super(
          type: 'SELECT',
          props: {
            'id': id,
            'label': label,
            'options': options,
            if (defaultValue != null) 'default': defaultValue,
          },
        );
}

/// Two-column grid.
class Grid2Col extends SDUIWidget {
  Grid2Col({double? spacing, super.children, super.action})
      : super(
          type: 'GRID_2_COL',
          props: {if (spacing != null) 'spacing': spacing},
        );
}

/// Material ListTile-style row with optional leading/trailing icons.
class ListItem extends SDUIWidget {
  ListItem({
    required String title,
    String? subtitle,
    String? leadingIcon,
    String? trailingIcon,
    super.action,
  }) : super(
          type: 'LIST_ITEM',
          props: {
            'title': title,
            if (subtitle != null) 'subtitle': subtitle,
            if (leadingIcon != null) 'leadingIcon': leadingIcon,
            if (trailingIcon != null) 'trailingIcon': trailingIcon,
          },
        );
}
