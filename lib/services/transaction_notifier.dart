import 'package:flutter/foundation.dart';

/// A simple notifier to manage transaction state changes across the app
/// This helps update the UI when transactions are added, modified, or deleted
class TransactionNotifier extends ChangeNotifier {
  static final TransactionNotifier _instance = TransactionNotifier._internal();
  
  factory TransactionNotifier() {
    return _instance;
  }
  
  TransactionNotifier._internal();

  /// Notify listeners that a transaction has been added
  void notifyTransactionAdded() {
    debugPrint('TransactionNotifier: Transaction added, notifying listeners');
    notifyListeners();
  }

  /// Notify listeners that a transaction has been updated
  void notifyTransactionUpdated() {
    debugPrint('TransactionNotifier: Transaction updated, notifying listeners');
    notifyListeners();
  }

  /// Notify listeners that a transaction has been deleted
  void notifyTransactionDeleted() {
    debugPrint('TransactionNotifier: Transaction deleted, notifying listeners');
    notifyListeners();
  }

  /// Notify listeners that transactions need to be refreshed
  void notifyTransactionsRefresh() {
    debugPrint('TransactionNotifier: Transactions refresh requested, notifying listeners');
    notifyListeners();
  }
}