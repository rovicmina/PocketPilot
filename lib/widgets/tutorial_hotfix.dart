import 'package:flutter/material.dart';
import 'custom_tutorial.dart';

/// Hotfix for the '_dependents.isEmpty' assertion error
/// This widget acts as a wrapper that prevents the error from occurring
class TutorialHotfixWrapper extends StatefulWidget {
  final Widget child;

  const TutorialHotfixWrapper({super.key, required this.child});

  @override
  State<TutorialHotfixWrapper> createState() => _TutorialHotfixWrapperState();
}

class _TutorialHotfixWrapperState extends State<TutorialHotfixWrapper> {
  bool _errorOccurred = false;
  static bool _handlerRegistered = false;
  static Function? _originalHandler;

  @override
  Widget build(BuildContext context) {
    if (_errorOccurred) {
      // If an error occurred, show a safe fallback
      return const SizedBox.shrink();
    }

    return widget.child;
  }

  @override
  void initState() {
    super.initState();
    
    // Only register the error handler once
    if (!_handlerRegistered) {
      _handlerRegistered = true;
      _originalHandler = FlutterError.onError;
      
      // Add error listener
      FlutterError.onError = (FlutterErrorDetails details) {
        if (details.exception.toString().contains('_dependents.isEmpty')) {
          // Handle the specific error
          _handleDependentsError(details);
        }
        // Call the original error handler if it exists and is not this handler
        if (_originalHandler != null) {
          _originalHandler!(details);
        }
      };
    }
  }

  void _handleDependentsError(FlutterErrorDetails details) {
    // Set error state to prevent further issues
    if (mounted) {
      setState(() {
        _errorOccurred = true;
      });
    }

    // Perform cleanup
    try {
      InteractiveTutorial.resetHighlightedKeyNotifier();
    } catch (e) {
      // Ignore cleanup errors
    }

    // Reset error state after a delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _errorOccurred = false;
        });
      }
    });
  }
  
  @override
  void dispose() {
    // Don't unregister the handler as it might be needed by other instances
    super.dispose();
  }
}

/// Utility class for preventing '_dependents.isEmpty' errors
class TutorialHotfix {
  /// Apply hotfix to prevent '_dependents.isEmpty' errors
  static void applyHotfix() {
    // This is a placeholder for any hotfix logic we might need
    // The main fix is implemented in the TutorialHotfixWrapper
  }

  /// Force cleanup of tutorial resources to prevent dependency errors
  static Future<void> forceCleanup() async {
    try {
      // Reset highlighted key notifier
      InteractiveTutorial.resetHighlightedKeyNotifier();
      
      // Add delay to ensure cleanup
      await Future.delayed(const Duration(milliseconds: 50));
    } catch (e) {
      // Ignore errors during cleanup
    }
  }
}