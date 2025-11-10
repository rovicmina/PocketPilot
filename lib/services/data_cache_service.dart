import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import '../models/reminder.dart';
import 'firebase_service.dart';
import 'transaction_service.dart';

/// High-performance caching service for transaction and reminder data
/// Reduces Firebase calls and improves app responsiveness
class DataCacheService {
  static final DataCacheService _instance = DataCacheService._internal();
  factory DataCacheService() => _instance;
  DataCacheService._internal();

  // Cache storage
  final Map<String, List<Transaction>> _monthlyTransactionsCache = {};
  final Map<String, Map<DateTime, double>> _dailySpendingCache = {};
  final Map<String, Map<DateTime, Set<TransactionType>>> _dailyTransactionTypesCache = {};
  final Map<String, List<Reminder>> _monthlyRemindersCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  
  // Cache configuration
  static const Duration _cacheExpiry = Duration(minutes: 5);
  static const int _maxCacheSize = 12; // Cache up to 12 months
  
  // Preloading state
  final Set<String> _preloadingMonths = {};
  
  /// Generate cache key for a month
  String _getMonthKey(DateTime date) {
    final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
    debugPrint('DataCacheService: Generated month key "$key" for date $date');
    return key;
  }
  
  /// Check if cache entry is valid
  bool _isCacheValid(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) {
      debugPrint('DataCacheService: Cache entry for $key is null');
      return false;
    }
    
    final age = DateTime.now().difference(timestamp);
    final isValid = age < _cacheExpiry;
    debugPrint('DataCacheService: Cache entry for $key is ${isValid ? "valid" : "expired"} (age: $age)');
    return isValid;
  }
  
  /// Clean expired cache entries
  void _cleanExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    
    _cacheTimestamps.forEach((key, timestamp) {
      if (now.difference(timestamp) >= _cacheExpiry) {
        expiredKeys.add(key);
      }
    });
    
    for (final key in expiredKeys) {
      _monthlyTransactionsCache.remove(key);
      _dailySpendingCache.remove(key);
      _dailyTransactionTypesCache.remove(key);
      _monthlyRemindersCache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }
  
  /// Limit cache size to prevent memory issues
  void _limitCacheSize() {
    if (_cacheTimestamps.length <= _maxCacheSize) return;
    
    // Remove oldest entries
    final sortedEntries = _cacheTimestamps.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    
    final entriesToRemove = sortedEntries.length - _maxCacheSize;
    for (int i = 0; i < entriesToRemove; i++) {
      final key = sortedEntries[i].key;
      _monthlyTransactionsCache.remove(key);
      _dailySpendingCache.remove(key);
      _dailyTransactionTypesCache.remove(key);
      _monthlyRemindersCache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }
  
  /// Get monthly transactions with caching
  Future<List<Transaction>> getMonthlyTransactions(DateTime month) async {
    final key = _getMonthKey(month);
    debugPrint('DataCacheService: Getting transactions for month $key');
    
    // Return cached data if valid
    if (_isCacheValid(key) && _monthlyTransactionsCache.containsKey(key)) {
      debugPrint('DataCacheService: Returning cached transactions for month $key');
      return _monthlyTransactionsCache[key]!;
    }
    
    debugPrint('DataCacheService: Fetching transactions from Firebase for month $key');
    
    // Fetch from Firebase
    final transactions = await TransactionService.getTransactionsByMonth(
      month.year, 
      month.month
    );
    
    debugPrint('DataCacheService: Fetched ${transactions.length} transactions for month $key');
    
    // Cache the result
    _monthlyTransactionsCache[key] = transactions;
    _cacheTimestamps[key] = DateTime.now();
    
    // Maintenance
    _cleanExpiredCache();
    _limitCacheSize();
    
    return transactions;
  }
  
  /// Get daily spending with caching
  Future<Map<DateTime, double>> getDailySpending(DateTime month) async {
    final key = _getMonthKey(month);
    debugPrint('DataCacheService: Getting daily spending for month $key');
    
    // Return cached data if valid
    if (_isCacheValid(key) && _dailySpendingCache.containsKey(key)) {
      debugPrint('DataCacheService: Returning cached daily spending for month $key');
      return _dailySpendingCache[key]!;
    }
    
    // Calculate from cached transactions if available
    if (_isCacheValid(key) && _monthlyTransactionsCache.containsKey(key)) {
      debugPrint('DataCacheService: Calculating daily spending from cached transactions for month $key');
      final transactions = _monthlyTransactionsCache[key]!;
      final dailySpending = _calculateDailySpending(transactions);
      final dailyTransactionTypes = _calculateDailyTransactionTypes(transactions);
      _dailySpendingCache[key] = dailySpending;
      _dailyTransactionTypesCache[key] = dailyTransactionTypes;
      return dailySpending;
    }

    // Fetch from Firebase and calculate
    debugPrint('DataCacheService: Fetching transactions and calculating daily spending for month $key');
    final transactions = await getMonthlyTransactions(month);
    final dailySpending = _calculateDailySpending(transactions);
    final dailyTransactionTypes = _calculateDailyTransactionTypes(transactions);

    _dailySpendingCache[key] = dailySpending;
    _dailyTransactionTypesCache[key] = dailyTransactionTypes;
    
    return dailySpending;
  }
  
  /// Calculate daily spending from transactions
  Map<DateTime, double> _calculateDailySpending(List<Transaction> transactions) {
    final Map<DateTime, double> dailySpending = {};

    for (final transaction in transactions) {
      if (transaction.type == TransactionType.expense) {
        final date = DateTime(
          transaction.date.year,
          transaction.date.month,
          transaction.date.day
        );
        dailySpending[date] = (dailySpending[date] ?? 0) + transaction.amount;
      }
    }

    return dailySpending;
  }

  /// Calculate daily transaction types from transactions
  Map<DateTime, Set<TransactionType>> _calculateDailyTransactionTypes(List<Transaction> transactions) {
    final Map<DateTime, Set<TransactionType>> dailyTypes = {};

    for (final transaction in transactions) {
      final date = DateTime(
        transaction.date.year,
        transaction.date.month,
        transaction.date.day
      );
      dailyTypes.putIfAbsent(date, () => <TransactionType>{}).add(transaction.type);
    }

    return dailyTypes;
  }
  
  /// Get monthly reminders with caching
  Future<List<Reminder>> getMonthlyReminders(DateTime month) async {
    final key = _getMonthKey(month);
    debugPrint('DataCacheService: Getting reminders for month $key');
    
    // Return cached data if valid
    if (_isCacheValid(key) && _monthlyRemindersCache.containsKey(key)) {
      debugPrint('DataCacheService: Returning cached reminders for month $key');
      return _monthlyRemindersCache[key]!;
    }
    
    debugPrint('DataCacheService: Fetching reminders from Firebase for month $key');
    
    // Fetch from Firebase
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);
    final reminders = await FirebaseService.getRemindersForDateRange(
      startOfMonth, 
      endOfMonth
    );
    
    debugPrint('DataCacheService: Fetched ${reminders.length} reminders for month $key');
    
    // Cache the result
    _monthlyRemindersCache[key] = reminders;
    _cacheTimestamps[key] = DateTime.now();
    
    return reminders;
  }
  
  /// Get reminders for a specific date from cache
  Future<List<Reminder>> getRemindersForDate(DateTime date) async {
    debugPrint('DataCacheService: Getting reminders for date $date');
    final monthReminders = await getMonthlyReminders(date);
    final filteredReminders = monthReminders.where((reminder) {
      return reminder.date.year == date.year &&
             reminder.date.month == date.month &&
             reminder.date.day == date.day;
    }).toList();
    
    debugPrint('DataCacheService: Found ${filteredReminders.length} reminders for date $date');
    return filteredReminders;
  }
  
  /// Get transactions for a specific date from cache
  Future<List<Transaction>> getTransactionsForDate(DateTime date) async {
    debugPrint('DataCacheService: Getting transactions for date $date');
    final monthTransactions = await getMonthlyTransactions(date);
    final filteredTransactions = monthTransactions.where((transaction) {
      return transaction.date.year == date.year &&
             transaction.date.month == date.month &&
             transaction.date.day == date.day;
    }).toList();
    
    debugPrint('DataCacheService: Found ${filteredTransactions.length} transactions for date $date');
    return filteredTransactions;
  }
  
  /// Preload adjacent months for faster navigation
  Future<void> preloadAdjacentMonths(DateTime currentMonth) async {
    debugPrint('DataCacheService: Preloading adjacent months for $currentMonth');
    final monthsToPreload = [
      DateTime(currentMonth.year, currentMonth.month - 2, 1), // 2 months ago
      DateTime(currentMonth.year, currentMonth.month - 1, 1), // previous month
      DateTime(currentMonth.year, currentMonth.month + 1, 1), // next month
      DateTime(currentMonth.year, currentMonth.month + 2, 1), // 2 months ahead
    ];

    // Preload in background without blocking UI
    for (final month in monthsToPreload) {
      _preloadMonth(month);
    }
  }
  
  /// Preload a specific month in background
  Future<void> _preloadMonth(DateTime month) async {
    final key = _getMonthKey(month);
    debugPrint('DataCacheService: Preloading month $key');
    
    // Skip if already cached or currently preloading
    if (_isCacheValid(key) || _preloadingMonths.contains(key)) {
      debugPrint('DataCacheService: Skipping preload for month $key (already cached or preloading)');
      return;
    }
    
    _preloadingMonths.add(key);
    debugPrint('DataCacheService: Added month $key to preloading set');
    
    try {
      // Preload transactions and reminders concurrently
      debugPrint('DataCacheService: Starting preload for month $key');
      await Future.wait([
        getMonthlyTransactions(month),
        getMonthlyReminders(month),
      ]);
      debugPrint('DataCacheService: Completed preload for month $key');
    } catch (e) {
      debugPrint('DataCacheService: Error preloading month $key: $e');
    } finally {
      _preloadingMonths.remove(key);
      debugPrint('DataCacheService: Removed month $key from preloading set');
    }
  }

  /// Invalidate cache for a specific month (call after adding/editing/deleting transactions)
  void invalidateMonth(DateTime month) {
    final key = _getMonthKey(month);
    debugPrint('DataCacheService: Invalidating cache for month $key');
    _monthlyTransactionsCache.remove(key);
    _dailySpendingCache.remove(key);
    _dailyTransactionTypesCache.remove(key);
    _monthlyRemindersCache.remove(key);
    _cacheTimestamps.remove(key);
    debugPrint('DataCacheService: Invalidated cache for month $key');
  }

  /// Invalidate cache for a specific date (call after adding/editing/deleting transactions on a specific date)
  void invalidateDate(DateTime date) {
    // For date-specific invalidation, we need to invalidate the entire month
    // since our caching is done at the monthly level
    invalidateMonth(date);
  }

  /// Clear all cache
  void clearCache() {
    _monthlyTransactionsCache.clear();
    _dailySpendingCache.clear();
    _dailyTransactionTypesCache.clear();
    _monthlyRemindersCache.clear();
    _cacheTimestamps.clear();
    _preloadingMonths.clear();
  }
  
  /// Check if a day has reminders (from cache if available)
  bool hasRemindersForDay(DateTime day) {
    final key = _getMonthKey(day);

    // If we have cached data, use it
    if (_isCacheValid(key) && _monthlyRemindersCache.containsKey(key)) {
      final monthlyReminders = _monthlyRemindersCache[key]!;
      return monthlyReminders.any((reminder) {
        return reminder.date.year == day.year &&
               reminder.date.month == day.month &&
               reminder.date.day == day.day;
      });
    }

    // If no cached data, return false (will be loaded later)
    return false;
  }

  /// Get transaction types for a specific day (from cache if available)
  Set<TransactionType> getTransactionTypesForDay(DateTime day) {
    final key = _getMonthKey(day);

    // If we have cached data, use it
    if (_isCacheValid(key) && _dailyTransactionTypesCache.containsKey(key)) {
      final dailyTypes = _dailyTransactionTypesCache[key]!;
      final normalizedDay = DateTime(day.year, day.month, day.day);
      return dailyTypes[normalizedDay] ?? <TransactionType>{};
    }

    // If no cached data, return empty set (will be loaded later)
    return <TransactionType>{};
  }

  /// Get cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    return {
      'cachedMonths': _cacheTimestamps.length,
      'preloadingMonths': _preloadingMonths.length,
      'memoryUsage': {
        'transactions': _monthlyTransactionsCache.length,
        'dailySpending': _dailySpendingCache.length,
        'dailyTransactionTypes': _dailyTransactionTypesCache.length,
        'reminders': _monthlyRemindersCache.length,
      },
    };
  }

  /// Check if a month's data is cached
  bool isMonthCached(DateTime month) {
    final key = _getMonthKey(month);
    return _isCacheValid(key) && _monthlyTransactionsCache.containsKey(key);
  }

  /// Get the cache key for a month (for debugging)
  String getMonthKey(DateTime month) {
    return _getMonthKey(month);
  }

}
