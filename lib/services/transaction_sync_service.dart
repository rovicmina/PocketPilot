import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import 'transaction_service.dart';
import 'transaction_monitor_service.dart';

/// Service to periodically sync and verify transaction integrity
/// Ensures all transactions are properly saved and handles any discrepancies
class TransactionSyncService {
  static Timer? _syncTimer;
  static bool _isSyncing = false;
  static DateTime? _lastSyncTime;
  static int _syncIntervalMinutes = 5; // Sync every 5 minutes

  /// Start periodic transaction synchronization
  static void startPeriodicSync({int intervalMinutes = 5}) {
    _syncIntervalMinutes = intervalMinutes;
    
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      Duration(minutes: _syncIntervalMinutes),
      (timer) => _performSync(),
    );
    
    debugPrint('Transaction sync service started (interval: ${_syncIntervalMinutes}m)');
    
    // Perform initial sync
    _performSync();
  }

  /// Stop periodic synchronization
  static void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    debugPrint('Transaction sync service stopped');
  }

  /// Manually trigger a sync operation
  static Future<void> performManualSync() async {
    await _performSync();
  }

  /// Internal sync operation
  static Future<void> _performSync() async {
    if (_isSyncing) {
      debugPrint('Sync already in progress, skipping');
      return;
    }

    _isSyncing = true;
    _lastSyncTime = DateTime.now();

    try {
      debugPrint('Starting transaction sync...');

      // Process any pending transactions from monitor service
      await TransactionMonitorService.processPendingTransactions();

      // Verify recent transactions are in database
      await _verifyRecentTransactions();

      // Clean up any duplicate transactions
      await _cleanupDuplicateTransactions();

      debugPrint('Transaction sync completed successfully');
    } catch (e) {
      debugPrint('Error during transaction sync: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Verify that recent transactions are properly saved
  static Future<void> _verifyRecentTransactions() async {
    try {
      final allTransactions = await TransactionService.getAllTransactions();
      final now = DateTime.now();
      final oneDayAgo = now.subtract(const Duration(days: 1));

      // Check transactions from the last 24 hours
      final recentTransactions = allTransactions.where(
        (t) => t.date.isAfter(oneDayAgo),
      ).toList();

      debugPrint('Verified ${recentTransactions.length} recent transactions');

      // If we have very few recent transactions, it might indicate a sync issue
      if (recentTransactions.isEmpty) {
        debugPrint('Warning: No recent transactions found in database');
      }
    } catch (e) {
      debugPrint('Error verifying recent transactions: $e');
    }
  }

  /// Clean up any duplicate transactions that might exist
  static Future<void> _cleanupDuplicateTransactions() async {
    try {
      final allTransactions = await TransactionService.getAllTransactions();
      final Map<String, List<Transaction>> transactionGroups = {};

      // Group transactions by ID
      for (final transaction in allTransactions) {
        transactionGroups.putIfAbsent(transaction.id, () => []).add(transaction);
      }

      // Find duplicates
      final duplicateGroups = transactionGroups.entries
          .where((entry) => entry.value.length > 1)
          .toList();

      if (duplicateGroups.isNotEmpty) {
        debugPrint('Found ${duplicateGroups.length} duplicate transaction groups');
        
        // Note: In a real implementation, you would handle duplicate removal
        // For now, we just log the issue since Firebase should prevent duplicates
        // by using the transaction ID as the document ID
        for (final group in duplicateGroups) {
          debugPrint('Duplicate transaction ID: ${group.key} (${group.value.length} copies)');
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up duplicate transactions: $e');
    }
  }

  /// Get sync service status
  static Map<String, dynamic> getSyncStatus() {
    return {
      'isActive': _syncTimer?.isActive ?? false,
      'isSyncing': _isSyncing,
      'lastSyncTime': _lastSyncTime?.toIso8601String(),
      'syncIntervalMinutes': _syncIntervalMinutes,
      'pendingTransactions': TransactionMonitorService.getPendingTransactionsCount(),
    };
  }

  /// Force sync all transactions (use with caution)
  static Future<void> forceSyncAllTransactions() async {
    try {
      debugPrint('Starting force sync of all transactions...');
      
      // Get all transactions from database
      final allTransactions = await TransactionService.getAllTransactions();
      
      debugPrint('Found ${allTransactions.length} transactions in database');
      
      // Verify each transaction exists and is valid
      int validCount = 0;
      int invalidCount = 0;
      
      for (final transaction in allTransactions) {
        if (_isValidTransaction(transaction)) {
          validCount++;
        } else {
          invalidCount++;
          debugPrint('Invalid transaction found: ${transaction.id}');
        }
      }
      
      debugPrint('Force sync completed: $validCount valid, $invalidCount invalid transactions');
    } catch (e) {
      debugPrint('Error during force sync: $e');
    }
  }

  /// Validate transaction data
  static bool _isValidTransaction(Transaction transaction) {
    // Check required fields
    if (transaction.id.isEmpty) return false;
    if (transaction.amount <= 0) return false;
    if (transaction.category.trim().isEmpty) return false;
    // Description is now optional - no need to check if empty
    
    // Check date is reasonable (not too far in future or past)
    final now = DateTime.now();
    final oneYearAgo = now.subtract(const Duration(days: 365));
    final oneYearFromNow = now.add(const Duration(days: 365));
    
    if (transaction.date.isBefore(oneYearAgo) || transaction.date.isAfter(oneYearFromNow)) {
      return false;
    }
    
    return true;
  }

  /// Export transaction data for backup
  static Future<List<Map<String, dynamic>>> exportTransactionData() async {
    try {
      final allTransactions = await TransactionService.getAllTransactions();
      return allTransactions.map((t) => t.toJson()).toList();
    } catch (e) {
      debugPrint('Error exporting transaction data: $e');
      return [];
    }
  }

  /// Get transaction statistics
  static Future<Map<String, dynamic>> getTransactionStatistics() async {
    try {
      final allTransactions = await TransactionService.getAllTransactions();
      final now = DateTime.now();
      
      // Calculate statistics
      final totalTransactions = allTransactions.length;
      final todayTransactions = allTransactions.where(
        (t) => _isSameDay(t.date, now),
      ).length;
      
      final thisWeekTransactions = allTransactions.where(
        (t) => t.date.isAfter(now.subtract(const Duration(days: 7))),
      ).length;
      
      final thisMonthTransactions = allTransactions.where(
        (t) => t.date.month == now.month && t.date.year == now.year,
      ).length;
      
      // Calculate totals by type
      double totalIncome = 0;
      double totalExpenses = 0;
      double totalSavings = 0;
      
      for (final transaction in allTransactions) {
        switch (transaction.type) {
          case TransactionType.income:
          case TransactionType.debt:
          case TransactionType.emergencyFundWithdrawal: // Emergency fund withdrawal adds to income
            totalIncome += transaction.amount;
            break;
          case TransactionType.expense:
          case TransactionType.recurringExpense:
          case TransactionType.debtPayment:
            totalExpenses += transaction.amount;
            break;
          case TransactionType.savings:
            totalSavings += transaction.amount;
            break;
          case TransactionType.savingsWithdrawal:
            totalSavings -= transaction.amount;
            break;
          case TransactionType.emergencyFund:
            // Emergency fund is tracked separately, doesn't affect regular savings
            break;
        }
      }
      
      return {
        'totalTransactions': totalTransactions,
        'todayTransactions': todayTransactions,
        'thisWeekTransactions': thisWeekTransactions,
        'thisMonthTransactions': thisMonthTransactions,
        'totalIncome': totalIncome,
        'totalExpenses': totalExpenses,
        'totalSavings': totalSavings,
        'netWorth': totalIncome - totalExpenses + totalSavings,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error calculating transaction statistics: $e');
      return {};
    }
  }

  /// Helper method to check if two dates are the same day
  static bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  /// Dispose of resources
  static void dispose() {
    stopPeriodicSync();
  }
}
