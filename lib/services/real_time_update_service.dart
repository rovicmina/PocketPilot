import 'dart:async';
import 'package:flutter/foundation.dart';
import 'transaction_notifier.dart';
import 'data_cache_service.dart';
import 'budget_preloader_service.dart';

/// Enhanced service to coordinate real-time updates across the entire app
/// Ensures all user actions automatically reflect without manual refresh
class RealTimeUpdateService {
  static final RealTimeUpdateService _instance = RealTimeUpdateService._internal();
  factory RealTimeUpdateService() => _instance;
  RealTimeUpdateService._internal();

  final TransactionNotifier _transactionNotifier = TransactionNotifier();
  final DataCacheService _cacheService = DataCacheService();
  
  // Debounced update mechanism to prevent too many rapid updates
  Timer? _updateTimer;
  bool _updatePending = false;
  
  /// Initialize the real-time update service
  static void initialize() {
    debugPrint('RealTimeUpdateService: Initializing real-time updates');
  }

  /// Trigger comprehensive updates when transactions are modified
  static Future<void> onTransactionAdded() async {
    final instance = RealTimeUpdateService();
    await instance._handleTransactionUpdate('added');
  }

  /// Trigger comprehensive updates when transactions are updated
  static Future<void> onTransactionUpdated() async {
    final instance = RealTimeUpdateService();
    await instance._handleTransactionUpdate('updated');
  }

  /// Trigger comprehensive updates when transactions are deleted
  static Future<void> onTransactionDeleted() async {
    final instance = RealTimeUpdateService();
    await instance._handleTransactionUpdate('deleted');
  }

  /// Handle transaction updates with debouncing to prevent excessive calls
  Future<void> _handleTransactionUpdate(String action) async {
    if (_updatePending) {
      // Cancel existing timer and restart with new update
      _updateTimer?.cancel();
    }

    _updatePending = true;
    
    // Debounce updates by 500ms to handle rapid successive calls
    _updateTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        await _executeUpdate(action);
      } finally {
        _updatePending = false;
      }
    });
  }

  /// Execute the actual update process
  Future<void> _executeUpdate(String action) async {
    debugPrint('RealTimeUpdateService: Executing $action update');
    
    final now = DateTime.now();
    
    // 1. Invalidate relevant caches
    _cacheService.invalidateMonth(now); // Current month
    _cacheService.invalidateMonth(DateTime(now.year, now.month - 1, 1)); // Previous month
    
    // 2. Invalidate budget preloader data
    BudgetPreloaderService.invalidatePreloadedData();
    
    // 3. Trigger UI updates across all pages
    switch (action) {
      case 'added':
        _transactionNotifier.notifyTransactionAdded();
        break;
      case 'updated':
        _transactionNotifier.notifyTransactionUpdated();
        break;
      case 'deleted':
        _transactionNotifier.notifyTransactionDeleted();
        break;
    }
    
    // 4. Preload fresh data in background for faster future access
    _preloadFreshDataInBackground();
    
    debugPrint('RealTimeUpdateService: Update completed for $action');
  }

  /// Preload fresh data in background after updates
  void _preloadFreshDataInBackground() {
    // Run in background without blocking UI
    Future.microtask(() async {
      try {
        // Preload budget data
        await BudgetPreloaderService.refreshPreloadedData();
        
        // Preload current month transactions
        final now = DateTime.now();
        await _cacheService.getMonthlyTransactions(now);
        
        debugPrint('RealTimeUpdateService: Background preloading completed');
      } catch (e) {
        debugPrint('RealTimeUpdateService: Background preloading error: $e');
      }
    });
  }

  /// Force refresh all data (for manual refresh scenarios)
  static Future<void> forceRefreshAll() async {
    final instance = RealTimeUpdateService();
    debugPrint('RealTimeUpdateService: Force refresh all data');
    
    // Clear all caches
    instance._cacheService.clearCache();
    BudgetPreloaderService.invalidatePreloadedData();
    
    // Trigger notifications
    instance._transactionNotifier.notifyTransactionsRefresh();
    
    // Preload fresh data
    await BudgetPreloaderService.refreshPreloadedData();
  }

  /// Get the transaction notifier instance for page listeners
  static TransactionNotifier getTransactionNotifier() {
    return RealTimeUpdateService()._transactionNotifier;
  }

  /// Cleanup resources
  static void dispose() {
    final instance = RealTimeUpdateService();
    instance._updateTimer?.cancel();
  }
}

/// Mixin for pages that need real-time transaction updates
mixin RealTimeTransactionListener {
  late final TransactionNotifier _realtimeNotifier;
  
  void initializeRealTimeListener(VoidCallback onTransactionChanged) {
    _realtimeNotifier = RealTimeUpdateService.getTransactionNotifier();
    _realtimeNotifier.addListener(onTransactionChanged);
  }
  
  void disposeRealTimeListener(VoidCallback onTransactionChanged) {
    _realtimeNotifier.removeListener(onTransactionChanged);
  }
}