import 'package:flutter/material.dart';

import '../sdui/form_manager.dart';

class SDUITextInput extends StatelessWidget {
  final String id;
  final Map<String, dynamic> props;

  const SDUITextInput({super.key, required this.id, required this.props});

  @override
  Widget build(BuildContext context) {
    // 1. Register with Manager (validators from props)
    final manager = SDUIFormManager();
    manager.registerInput(id, props['validators']);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Text(props['label'] ?? 'Input', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),

          // Input Field - listen to field errors for red border + message
          ValueListenableBuilder<Map<String, String>?>(
            valueListenable: manager.fieldErrors,
            builder: (context, errors, _) {
              final errorText = errors?[id];
              return TextField(
                obscureText: props['is_secure'] ?? false,
                keyboardType: _getKeyboardType(props['keyboard_type']),
                decoration: InputDecoration(
                  hintText: props['placeholder'] ?? '',
                  errorText: errorText,
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.red, width: 1.5),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                onChanged: (value) => manager.set(id, value),
              );
            },
          ),
        ],
      ),
    );
  }

  TextInputType _getKeyboardType(String? type) {
    switch (type) {
      case 'email':
        return TextInputType.emailAddress;
      case 'number':
        return TextInputType.number;
      default:
        return TextInputType.text;
    }
  }
}
