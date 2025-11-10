import 'package:flutter/foundation.dart';

/// A notifier to manage user profile changes across the app
/// This helps update the UI when user data like emergency fund amount or monthly net is modified
class UserNotifier extends ChangeNotifier {
  static final UserNotifier _instance = UserNotifier._internal();
  
  factory UserNotifier() {
    return _instance;
  }
  
  UserNotifier._internal();

  /// Notify listeners that user profile has been updated
  void notifyProfileUpdated() {
    debugPrint('UserNotifier: User profile updated, notifying listeners');
    notifyListeners();
  }

  /// Notify listeners that emergency fund amount has been updated
  void notifyEmergencyFundUpdated() {
    debugPrint('UserNotifier: Emergency fund updated, notifying listeners');
    notifyListeners();
  }

  /// Notify listeners that monthly net has been updated
  void notifyMonthlyNetUpdated() {
    debugPrint('UserNotifier: Monthly net updated, notifying listeners');
    notifyListeners();
  }

  /// Notify listeners that user data needs to be refreshed
  void notifyUserRefresh() {
    debugPrint('UserNotifier: User refresh requested, notifying listeners');
    notifyListeners();
  }
}