import 'package:flutter/services.dart';

/// Service for communicating with native platform widgets (Android/iOS)
class NativeWidgetBridge {
  static const MethodChannel _channel = MethodChannel('pocketpilot/widget');
  
  /// Update native home screen widget with budget and expense data
  static Future<void> updateHomeScreenWidget({
    required double todayBudget,
    required double todayExpenses,
    required double remaining,
    required double percentage,
    bool showAppLogo = true,
  }) async {
    try {
      final data = {
        'todayBudget': todayBudget,
        'todayExpenses': todayExpenses,
        'remaining': remaining,
        'percentage': percentage,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'currency': '₱',
        'showAppLogo': showAppLogo,
      };
      
      await _channel.invokeMethod('updateWidget', data);
    } on PlatformException {
      // Removed debug print statements for production
    }
  }
  
  /// Request widget configuration from native side
  static Future<Map<String, dynamic>?> getWidgetConfiguration() async {
    try {
      final result = await _channel.invokeMethod('getWidgetConfig');
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException {
      // Removed debug print statements for production
      return null;
    }
  }
  
  /// Check if native widgets are supported on this platform
  static Future<bool> isWidgetSupported() async {
    try {
      final result = await _channel.invokeMethod('isSupported');
      return result == true;
    } on PlatformException {
      // Removed debug print statements for production
      return false;
    }
  }
  
  /// Handle widget click/tap events from native side
  static void setWidgetClickHandler(Function(String action) handler) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'widgetClicked') {
        final action = call.arguments['action'] as String? ?? 'open_app';
        handler(action);
      }
    });
  }
}