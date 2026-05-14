import 'package:flutter/material.dart';

class SDUIFormManager {
  // Singleton Pattern
  static final SDUIFormManager _instance = SDUIFormManager._internal();
  factory SDUIFormManager() => _instance;
  SDUIFormManager._internal();

  // Storage: { "email": "user@test.com", "password": "123" }
  final Map<String, dynamic> _formData = {};

  // Validators: { "email": { "required": true } }
  final Map<String, Map<String, dynamic>> _validators = {};

  // Field errors for UI: { "username": "Email is required" }
  final ValueNotifier<Map<String, String>?> fieldErrors = ValueNotifier<Map<String, String>?>(null);

  // 1. Register a field and its validation rules
  void registerInput(String id, dynamic validators) {
    if (validators is Map) {
      _validators[id] = Map<String, dynamic>.from(validators);
    }
  }

  // 2. Update value (Called by UI)
  void set(String id, String value) {
    _formData[id] = value;
    debugPrint("📝 Form Update [$id]: $value");
    // Clear error for this field when user types
    clearFieldError(id);
  }

  // 3. Get all data (Called by Submit Action)
  Map<String, dynamic> export() => _formData;

  // 4. Validate all fields - returns map of field id -> error message (null if valid)
  Map<String, String>? validate() {
    final errors = <String, String>{};
    for (var key in _validators.keys) {
      final rules = _validators[key]!;
      final value = _formData[key] as String? ?? '';

      // Rule: Required
      if (rules['required'] == true && value.trim().isEmpty) {
        errors[key] = "This field is required.";
        continue;
      }

      // Rule: Regex
      if (rules.containsKey('regex')) {
        try {
          final pattern = rules['regex']?.toString() ?? '';
          if (pattern.isNotEmpty) {
            final regExp = RegExp(pattern);
            if (!regExp.hasMatch(value)) {
              errors[key] = "Invalid format.";
              continue;
            }
          }
        } catch (e) {
          debugPrint("Regex validation error for $key: $e");
        }
      }
    }
    return errors.isEmpty ? null : errors;
  }

  void clearFieldError(String id) {
    final current = fieldErrors.value;
    if (current != null && current.containsKey(id)) {
      final next = Map<String, String>.from(current)..remove(id);
      fieldErrors.value = next.isEmpty ? null : next;
    }
  }

  void clear() {
    _formData.clear();
    _validators.clear();
    fieldErrors.value = null;
  }
}