import 'package:flutter/material.dart';

/// Mixin to track form state changes and detect unsaved data
mixin FormStateTracker<T extends StatefulWidget> on State<T> {
  bool _hasUnsavedChanges = false;
  bool _isSubmitting = false;
  Map<String, dynamic> _initialValues = {};
  Map<String, dynamic> _currentValues = {};

  /// Whether the form has unsaved changes
  bool get hasUnsavedChanges => _hasUnsavedChanges && !_isSubmitting;

  /// Mark that the form is being submitted (to avoid warning during save)
  void setSubmitting(bool submitting) {
    setState(() {
      _isSubmitting = submitting;
    });
  }

  /// Initialize form tracking with initial values
  void initializeFormTracking(Map<String, dynamic> initialValues) {
    _initialValues = Map.from(initialValues);
    _currentValues = Map.from(initialValues);
    _hasUnsavedChanges = false;
  }

  /// Update a form field value and check for changes
  void updateFormField(String fieldName, dynamic value) {
    _currentValues[fieldName] = value;
    _checkForChanges();
  }

  /// Check if current values differ from initial values
  void _checkForChanges() {
    bool hasChanges = false;
    
    // Check if any current value differs from initial value
    for (String key in _currentValues.keys) {
      if (_currentValues[key] != _initialValues[key]) {
        hasChanges = true;
        break;
      }
    }
    
    // Also check if any initial value is missing in current values
    if (!hasChanges) {
      for (String key in _initialValues.keys) {
        if (!_currentValues.containsKey(key) || 
            _currentValues[key] != _initialValues[key]) {
          hasChanges = true;
          break;
        }
      }
    }
    
    if (_hasUnsavedChanges != hasChanges) {
      setState(() {
        _hasUnsavedChanges = hasChanges;
      });
    }
  }

  /// Reset form tracking (call after successful save)
  void resetFormTracking() {
    setState(() {
      _initialValues = Map.from(_currentValues);
      _hasUnsavedChanges = false;
      _isSubmitting = false;
    });
  }

  /// Clear form tracking
  void clearFormTracking() {
    setState(() {
      _initialValues.clear();
      _currentValues.clear();
      _hasUnsavedChanges = false;
      _isSubmitting = false;
    });
  }
}

/// Helper class to track TextEditingController changes
class TrackedTextEditingController extends TextEditingController {
  final String fieldName;
  final FormStateTracker tracker;

  TrackedTextEditingController({
    required this.fieldName,
    required this.tracker,
    super.text,
  }) {
    addListener(_onTextChanged);
  }

  void _onTextChanged() {
    tracker.updateFormField(fieldName, text);
  }

  @override
  void dispose() {
    removeListener(_onTextChanged);
    super.dispose();
  }
}

/// Helper function to create tracked controllers
TrackedTextEditingController createTrackedController(
  String fieldName,
  FormStateTracker tracker, {
  String? initialText,
}) {
  return TrackedTextEditingController(
    fieldName: fieldName,
    tracker: tracker,
    text: initialText,
  );
}
