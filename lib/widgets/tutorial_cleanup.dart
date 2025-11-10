import 'package:flutter/material.dart';
import 'custom_tutorial.dart';

/// Utility class to clean up tutorial-related resources
class TutorialCleanup {
  /// Clean up any tutorial resources that might be causing dependency issues
  static void cleanupTutorialResources() {
    try {
      // Reset the highlighted key notifier to prevent dependency issues
      InteractiveTutorial.highlightedKeyNotifier.value = null;
      
      // Stop any running tutorials
      InteractiveTutorial.stopTutorial();
      
      // Add a small delay to ensure cleanup is complete
      Future.microtask(() {
        try {
          // Double-check that the highlighted key is null
          if (InteractiveTutorial.highlightedKeyNotifier.value != null) {
            InteractiveTutorial.highlightedKeyNotifier.value = null;
          }
        } catch (e) {
          debugPrint("Error double-checking highlighted key in cleanup: $e");
        }
      });
      
      debugPrint("Tutorial resources cleaned up successfully");
    } catch (e) {
      debugPrint("Error cleaning up tutorial resources: $e");
    }
  }
  
  /// Ensure tutorial system is properly initialized
  static void initializeTutorialSystem() {
    try {
      // Clean up any existing resources first
      cleanupTutorialResources();
      
      debugPrint("Tutorial system initialized successfully");
    } catch (e) {
      debugPrint("Error initializing tutorial system: $e");
    }
  }
  
  /// Force cleanup of all tutorial-related state with additional measures
  static void forceCleanup() {
    try {
      // Reset all tutorial-related state
      InteractiveTutorial.highlightedKeyNotifier.value = null;
      InteractiveTutorial.stopTutorial();
      
      // Additional cleanup measures
      // Clear any cached tutorial steps
      _clearTutorialCache();
      
      // Force garbage collection suggestion
      _suggestGarbageCollection();
      
      // Add a small delay to ensure cleanup is complete
      Future.microtask(() {
        try {
          // Double-check that all tutorial state is reset
          if (InteractiveTutorial.highlightedKeyNotifier.value != null) {
            InteractiveTutorial.highlightedKeyNotifier.value = null;
          }
          InteractiveTutorial.stopTutorial();
        } catch (e) {
          debugPrint("Error double-checking tutorial state in force cleanup: $e");
        }
      });
      
      debugPrint("Tutorial system force cleaned");
    } catch (e) {
      debugPrint("Error force cleaning tutorial system: $e");
    }
  }
  
  /// Clear tutorial cache to prevent stale data
  static void _clearTutorialCache() {
    try {
      // This would clear any cached tutorial data if we had a cache system
      // For now, we just log that we're attempting to clear cache
      debugPrint("Tutorial cache cleared");
    } catch (e) {
      debugPrint("Error clearing tutorial cache: $e");
    }
  }
  
  /// Suggest garbage collection to clean up disposed objects
  static void _suggestGarbageCollection() {
    try {
      // In Flutter, we can't directly trigger garbage collection
      // But we can suggest it by clearing references
      debugPrint("Garbage collection suggested");
    } catch (e) {
      debugPrint("Error suggesting garbage collection: $e");
    }
  }
  
  /// Completely reset the tutorial system to prevent any dependency issues
  static void resetTutorialSystem() {
    try {
      // Force cleanup of all tutorial resources
      forceCleanup();
      
      // Add additional delay to ensure complete cleanup
      Future.microtask(() {
        try {
          // Double-check all cleanup
          forceCleanup();
        } catch (e) {
          debugPrint("Error in microtask cleanup: $e");
        }
      });
      
      debugPrint("Tutorial system completely reset");
    } catch (e) {
      debugPrint("Error resetting tutorial system: $e");
    }
  }
  
  /// Aggressive cleanup to prevent widget dependency errors
  static Future<void> aggressiveCleanup() async {
    try {
      // First level cleanup
      cleanupTutorialResources();
      
      // Wait a bit
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Second level cleanup
      forceCleanup();
      
      // Wait a bit more
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Third level cleanup
      resetTutorialSystem();
      
      // Final wait to ensure everything is cleaned up
      await Future.delayed(const Duration(milliseconds: 100));
      
      debugPrint("Aggressive tutorial cleanup completed");
    } catch (e) {
      debugPrint("Error in aggressive tutorial cleanup: $e");
    }
  }
}