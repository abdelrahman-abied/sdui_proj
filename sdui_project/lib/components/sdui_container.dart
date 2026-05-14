import 'package:flutter/material.dart';
import 'package:sdui_project/sdui/sdui_parser.dart';

import '../utils/style_parser.dart';

class SDUIContainer extends StatelessWidget {
  final Map<String, dynamic> uiJson;

  const SDUIContainer({super.key, required this.uiJson});

  @override
  Widget build(BuildContext context) {
    final style = Map<String, dynamic>.from(uiJson['style'] as Map? ?? {});
    final List<dynamic> children = uiJson['children'] ?? [];

    return Padding(
      padding: StyleParser.parseInsets(style, 'margin'),
      child: Container(
        decoration: StyleParser.parseDecoration(style),
        padding: StyleParser.parseInsets(style, 'padding'),

        // --- FIX IS HERE ---
        child: children.length == 1
            ? SDUIParser(uiJson: Map<String, dynamic>.from(children[0] as Map))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children
                    .map((c) => SDUIParser(uiJson: Map<String, dynamic>.from(c as Map)))
                    .toList(),
              ),
      ),
    );
  }
}
