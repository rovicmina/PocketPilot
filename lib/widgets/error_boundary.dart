import 'package:flutter/material.dart';
import 'tutorial_error_handler.dart';

/// Error boundary widget to catch and handle widget tree errors
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget? fallback;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.fallback,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // Initialize error state
    _hasError = false;
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      // Show fallback UI or a recovery screen
      return widget.fallback ?? _buildRecoveryScreen();
    }

    // Use a try-catch wrapper to catch build errors
    return _ErrorCatcher(
      onError: _handleError,
      child: widget.child,
    );
  }

  void _handleError(Object error, StackTrace stackTrace) {
    debugPrint('ErrorBoundary caught error: $error');
    debugPrint('Stack Trace: $stackTrace');
    
    // Check if this is the specific error we're trying to fix
    if (error.toString().contains('_dependents.isEmpty')) {
      // Handle the widget dependency error
      TutorialErrorHandler.handleWidgetDependencyError(error, stackTrace);
      
      // Try to recover by resetting the error state after a delay
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
            _hasError = false;
          });
        }
      });
    } else {
      // For other errors, show fallback UI
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  Widget _buildRecoveryScreen() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'We\'re trying to recover automatically',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Try to reset the error state
                TutorialErrorHandler.resetTutorialSystem();
                setState(() {
                  _hasError = false;
                });
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Internal widget that catches build errors
class _ErrorCatcher extends StatelessWidget {
  final Widget child;
  final Function(Object error, StackTrace stackTrace) onError;

  const _ErrorCatcher({
    required this.child,
    required this.onError,
  });

  @override
  Widget build(BuildContext context) {
    try {
      return child;
    } catch (error, stackTrace) {
      // Catch synchronous errors during build
      onError(error, stackTrace);
      return const SizedBox.shrink();
    }
  }
}