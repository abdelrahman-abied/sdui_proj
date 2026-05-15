import 'package:flutter/material.dart';

import '../sdui/form_manager.dart';

/// Boolean checkbox bound to [SDUIFormManager].
class SDUICheckbox extends StatefulWidget {
  final String id;
  final String label;
  final bool defaultValue;

  const SDUICheckbox({
    super.key,
    required this.id,
    required this.label,
    this.defaultValue = false,
  });

  @override
  State<SDUICheckbox> createState() => _SDUICheckboxState();
}

class _SDUICheckboxState extends State<SDUICheckbox> {
  late bool _value = widget.defaultValue;

  @override
  void initState() {
    super.initState();
    SDUIFormManager().set(widget.id, _value);
  }

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(widget.label),
      value: _value,
      onChanged: (v) {
        final next = v ?? false;
        setState(() => _value = next);
        SDUIFormManager().set(widget.id, next);
      },
    );
  }
}

/// Boolean switch bound to [SDUIFormManager].
class SDUISwitch extends StatefulWidget {
  final String id;
  final String label;
  final bool defaultValue;

  const SDUISwitch({
    super.key,
    required this.id,
    required this.label,
    this.defaultValue = false,
  });

  @override
  State<SDUISwitch> createState() => _SDUISwitchState();
}

class _SDUISwitchState extends State<SDUISwitch> {
  late bool _value = widget.defaultValue;

  @override
  void initState() {
    super.initState();
    SDUIFormManager().set(widget.id, _value);
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(widget.label),
      value: _value,
      onChanged: (v) {
        setState(() => _value = v);
        SDUIFormManager().set(widget.id, v);
      },
    );
  }
}

/// Single-select radio group. [options] is a list of `{value, label}` maps.
class SDUIRadioGroup extends StatefulWidget {
  final String id;
  final String label;
  final List<Map<String, dynamic>> options;
  final String? defaultValue;

  const SDUIRadioGroup({
    super.key,
    required this.id,
    required this.label,
    required this.options,
    this.defaultValue,
  });

  @override
  State<SDUIRadioGroup> createState() => _SDUIRadioGroupState();
}

class _SDUIRadioGroupState extends State<SDUIRadioGroup> {
  String? _value;

  @override
  void initState() {
    super.initState();
    _value = widget.defaultValue;
    if (_value != null) SDUIFormManager().set(widget.id, _value);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label, style: const TextStyle(fontWeight: FontWeight.bold)),
          RadioGroup<String>(
            groupValue: _value,
            onChanged: (v) {
              if (v == null) return;
              setState(() => _value = v);
              SDUIFormManager().set(widget.id, v);
            },
            child: Column(
              children: [
                for (final opt in widget.options)
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(opt['label']?.toString() ?? ''),
                    value: opt['value']?.toString() ?? '',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dropdown select. Same option shape as [SDUIRadioGroup].
class SDUISelect extends StatefulWidget {
  final String id;
  final String label;
  final List<Map<String, dynamic>> options;
  final String? defaultValue;

  const SDUISelect({
    super.key,
    required this.id,
    required this.label,
    required this.options,
    this.defaultValue,
  });

  @override
  State<SDUISelect> createState() => _SDUISelectState();
}

class _SDUISelectState extends State<SDUISelect> {
  String? _value;

  @override
  void initState() {
    super.initState();
    _value = widget.defaultValue;
    if (_value != null) SDUIFormManager().set(widget.id, _value);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            initialValue: _value,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: [
              for (final opt in widget.options)
                DropdownMenuItem(
                  value: opt['value']?.toString() ?? '',
                  child: Text(opt['label']?.toString() ?? ''),
                ),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _value = v);
              SDUIFormManager().set(widget.id, v);
            },
          ),
        ],
      ),
    );
  }
}
