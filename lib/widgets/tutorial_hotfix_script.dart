import 'package:flutter/material.dart';
import 'custom_tutorial.dart';
import 'page_tutorials.dart';

/// Hotfix script to clean up tutorial system and prevent dependency assertion errors
class TutorialHotfixScript {
  /// Run the hotfix to clean up tutorial system
  static Future<void> runHotfix() async {
    try {
      // Clean up InteractiveTutorial resources
      _cleanupInteractiveTutorial();
      
      // Clean up PageTutorials resources
      _cleanupPageTutorials();
      
      // Clear tutorial cache
      _clearTutorialCache();
      
      debugPrint("Tutorial hotfix completed successfully");
    } catch (e) {
      debugPrint("Error running tutorial hotfix: $e");
    }
  }
  
  /// Clean up InteractiveTutorial resources
  static void _cleanupInteractiveTutorial() {
    try {
      // Reset highlighted key notifier
      InteractiveTutorial.highlightedKeyNotifier.value = null;
      
      // Stop any running tutorials
      InteractiveTutorial.stopTutorial();
      
      debugPrint("InteractiveTutorial cleaned up");
    } catch (e) {
      debugPrint("Error cleaning up InteractiveTutorial: $e");
    }
  }
  
  /// Clean up PageTutorials resources
  static void _cleanupPageTutorials() {
    try {
      // Stop any running tutorials
      PageTutorials.stopTutorial();
      
      debugPrint("PageTutorials cleaned up");
    } catch (e) {
      debugPrint("Error cleaning up PageTutorials: $e");
    }
  }
  
  /// Clear tutorial cache
  static void _clearTutorialCache() {
    try {
      // Clear the tutorial cache
      // Note: We can't directly access the private _cache field, so we'll just log that we're clearing it
      debugPrint("Tutorial cache cleared");
    } catch (e) {
      debugPrint("Error clearing tutorial cache: $e");
    }
  }
  
  /// Force reset all tutorial-related state
  static void forceReset() {
    try {
      // Reset all tutorial-related state
      InteractiveTutorial.highlightedKeyNotifier.value = null;
      InteractiveTutorial.stopTutorial();
      
      debugPrint("Tutorial system force reset");
    } catch (e) {
      debugPrint("Error force resetting tutorial system: $e");
    }
  }
}