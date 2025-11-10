import 'package:flutter/material.dart';
import 'tutorial_cleanup.dart';

/// Comprehensive error handler for tutorial system errors
class TutorialErrorHandler {
  /// Handle tutorial system errors with comprehensive recovery
  static void handleTutorialError(Object error, StackTrace stackTrace) {
    // Log the error
    debugPrint('Tutorial Error Handler: $error');
    debugPrint('Stack Trace: $stackTrace');
    
    try {
      // Perform comprehensive cleanup
      _performComprehensiveCleanup();
    } catch (cleanupError) {
      debugPrint('Error during tutorial cleanup: $cleanupError');
    }
  }
  
  /// Perform comprehensive cleanup of all tutorial resources
  static void _performComprehensiveCleanup() {
    try {
      // Force cleanup of tutorial resources
      TutorialCleanup.forceCleanup();
      
      // Add additional delay to ensure cleanup completion
      Future.microtask(() {
        try {
          // Double-check cleanup
          TutorialCleanup.forceCleanup();
        } catch (e) {
          debugPrint('Error in microtask cleanup: $e');
        }
      });
    } catch (e) {
      debugPrint('Error in comprehensive cleanup: $e');
    }
  }
  
  /// Handle widget dependency errors specifically
  static void handleWidgetDependencyError(Object error, StackTrace stackTrace) {
    debugPrint('Widget Dependency Error: $error');
    debugPrint('Stack Trace: $stackTrace');
    
    try {
      // Perform immediate cleanup
      TutorialCleanup.cleanupTutorialResources();
      
      // Add delay and retry cleanup
      Future.delayed(const Duration(milliseconds: 100), () {
        TutorialCleanup.forceCleanup();
      });
    } catch (e) {
      debugPrint('Error handling widget dependency error: $e');
    }
  }
  
  /// Reset the entire tutorial system to prevent dependency issues
  static void resetTutorialSystem() {
    try {
      // Perform multiple levels of cleanup
      TutorialCleanup.cleanupTutorialResources();
      TutorialCleanup.forceCleanup();
      
      // Add delay and final cleanup
      Future.delayed(const Duration(milliseconds: 200), () {
        TutorialCleanup.resetTutorialSystem();
      });
    } catch (e) {
      debugPrint('Error resetting tutorial system: $e');
    }
  }
  
  /// Aggressive cleanup to prevent widget dependency errors
  static Future<void> aggressiveCleanup() async {
    try {
      // First level cleanup
      TutorialCleanup.cleanupTutorialResources();
      
      // Wait a bit with timeout
      await Future.any([
        Future.delayed(const Duration(milliseconds: 50)),
        Future.delayed(const Duration(milliseconds: 100)) // Timeout after 100ms
      ]);
      
      // Second level cleanup
      TutorialCleanup.forceCleanup();
      
      // Wait a bit more with timeout
      await Future.any([
        Future.delayed(const Duration(milliseconds: 50)),
        Future.delayed(const Duration(milliseconds: 100)) // Timeout after 100ms
      ]);
      
      // Third level cleanup
      TutorialCleanup.resetTutorialSystem();
      
      // Final wait to ensure everything is cleaned up with timeout
      await Future.any([
        Future.delayed(const Duration(milliseconds: 100)),
        Future.delayed(const Duration(milliseconds: 200)) // Timeout after 200ms
      ]);
    } catch (e) {
      debugPrint('Error in aggressive cleanup: $e');
    }
  }
}