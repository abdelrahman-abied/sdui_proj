import 'package:flutter/material.dart';

import '../sdui/sdui_parser.dart';
import '../utils/style_parser.dart';

class SDUIContainer extends StatelessWidget {
  final Map<String, dynamic> uiJson;

  const SDUIContainer({super.key, required this.uiJson});

  @override
  Widget build(BuildContext context) {
    final props = Map<String, dynamic>.from(uiJson['props'] as Map? ?? {});
    final children = (uiJson['children'] as List? ?? []);

    final radius = StyleParser.parseCornerRadius(props);
    final decoration = BoxDecoration(
      color: StyleParser.parseBackgroundColor(props),
      borderRadius: radius > 0 ? BorderRadius.circular(radius) : null,
    );

    final body = children.length == 1
        ? SDUIParser(uiJson: Map<String, dynamic>.from(children.first as Map))
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children
                .map((c) => SDUIParser(uiJson: Map<String, dynamic>.from(c as Map)))
                .toList(),
          );

    return Padding(
      padding: StyleParser.parseMargin(props),
      child: Container(
        padding: StyleParser.parsePadding(props),
        decoration: decoration,
        child: body,
      ),
    );
  }
}
