import 'package:flutter/material.dart';
import 'package:sdui_project/sdui/sdui_parser.dart';

class SDUIGrid extends StatelessWidget {
  final Map<String, dynamic> uiJson;
  final int crossAxisCount;

  const SDUIGrid({super.key, required this.uiJson, this.crossAxisCount = 2});

  @override
  Widget build(BuildContext context) {
    final List<dynamic> children = uiJson['children'] ?? [];
    final style = Map<String, dynamic>.from(uiJson['style'] as Map? ?? {});
    final double gap = (style['gap'] ?? 0).toDouble();

    return GridView.builder(
      shrinkWrap: true, // Vital for nesting inside lists
      physics: const NeverScrollableScrollPhysics(), // Let parent scroll
      padding: EdgeInsets.symmetric(horizontal: (style['padding'] ?? 0).toDouble()),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: gap,
        mainAxisSpacing: gap,
        childAspectRatio: 0.8, // Adjust based on your card design
      ),
      itemCount: children.length,
      itemBuilder: (context, index) {
        return SDUIParser(uiJson: Map<String, dynamic>.from(children[index] as Map));
      },
    );
  }
}