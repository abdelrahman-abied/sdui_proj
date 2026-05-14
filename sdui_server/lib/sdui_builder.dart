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
