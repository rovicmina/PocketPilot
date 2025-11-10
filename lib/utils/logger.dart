import 'package:flutter/foundation.dart';

/// A simple logging utility that can be disabled in production
class Logger {
  // Set to false to disable logging in production
  static const bool _enabled = kDebugMode;

  /// Log informational messages
  static void info(String message) {
    if (_enabled) {
      // Use debugPrint for Flutter-specific logging
      debugPrint('INFO: $message');
    }
  }

  /// Log warning messages
  static void warning(String message) {
    if (_enabled) {
      debugPrint('WARNING: $message');
    }
  }

  /// Log error messages
  static void error(String message) {
    if (_enabled) {
      debugPrint('ERROR: $message');
    }
  }

  /// Log debug messages
  static void debug(String message) {
    if (_enabled) {
      debugPrint('DEBUG: $message');
    }
  }

  /// Log exception with stack trace
  static void exception(Object error, [StackTrace? stackTrace]) {
    if (_enabled) {
      debugPrint('EXCEPTION: $error');
      if (stackTrace != null) {
        debugPrint('STACK TRACE: $stackTrace');
      }
    }
  }
}