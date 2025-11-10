import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import 'transaction_service.dart';
import 'transaction_recording_service.dart';

/// Service to monitor and ensure all transactions are properly saved
/// Provides backup mechanisms and validation for transaction recording
class TransactionMonitorService {
  static final List<Transaction> _pendingTransactions = [];
  static bool _isMonitoring = false;

  /// Start monitoring transactions
  static void startMonitoring() {
    if (!_isMonitoring) {
      _isMonitoring = true;
      debugPrint('Transaction monitoring started');
    }
  }

  /// Stop monitoring transactions
  static void stopMonitoring() {
    _isMonitoring = false;
    debugPrint('Transaction monitoring stopped');
  }

  /// Add transaction to pending list for backup recording
  static void addToPending(Transaction transaction) {
    if (_isMonitoring) {
      _pendingTransactions.add(transaction);
      debugPrint('Transaction added to pending: ${transaction.id}');
    }
  }

  /// Process all pending transactions
  static Future<void> processPendingTransactions() async {
    if (_pendingTransactions.isEmpty) return;

    debugPrint('Processing ${_pendingTransactions.length} pending transactions');
    
    final transactionsToProcess = List<Transaction>.from(_pendingTransactions);
    _pendingTransactions.clear();

    for (final transaction in transactionsToProcess) {
      try {
        // Check if transaction already exists
        final exists = await TransactionRecordingService.verifyTransactionExists(transaction.id);
        if (!exists) {
          await TransactionService.addTransaction(transaction);
          debugPrint('Pending transaction saved: ${transaction.id}');
        } else {
          debugPrint('Transaction already exists: ${transaction.id}');
        }
      } catch (e) {
        debugPrint('Error processing pending transaction ${transaction.id}: $e');
        // Re-add to pending if failed
        _pendingTransactions.add(transaction);
      }
    }
  }

  /// Enhanced BudgetManager wrapper that ensures transactions are saved
  static Future<Transaction> recordIncomeWithMonitoring(
    BudgetManager budgetManager,
    double amount,
    String description, {
    bool isFromDebt = false,
  }) async {
    try {
      final transaction = await budgetManager.addIncome(amount, description, isFromDebt: isFromDebt);
      
      // Verify transaction was saved
      await _verifyTransactionSaved(transaction);
      
      return transaction;
    } catch (e) {
      debugPrint('Error in recordIncomeWithMonitoring: $e');
      
      // Create backup transaction
      final backupTransaction = Transaction(
        id: TransactionService.generateTransactionId(),
        amount: amount,
        type: isFromDebt ? TransactionType.debt : TransactionType.income,
        category: isFromDebt ? 'Debt Income' : 'Income',
        description: description,
        date: DateTime.now(),
      );
      
      addToPending(backupTransaction);
      return backupTransaction;
    }
  }

  /// Enhanced expense recording with monitoring
  static Future<Transaction?> recordExpenseWithMonitoring(
    BudgetManager budgetManager,
    double amount,
    String category,
    String description, {
    bool isRecurring = false,
  }) async {
    try {
      final transaction = await budgetManager.subtractExpense(amount, category, description, isRecurring: isRecurring);
      
      if (transaction != null) {
        await _verifyTransactionSaved(transaction);
      }
      
      return transaction;
    } catch (e) {
      debugPrint('Error in recordExpenseWithMonitoring: $e');
      
      // Create backup transaction if balance allows
      if (budgetManager.currentBalance >= amount) {
        final backupTransaction = Transaction(
          id: TransactionService.generateTransactionId(),
          amount: amount,
          type: isRecurring ? TransactionType.recurringExpense : TransactionType.expense,
          category: category,
          description: description,
          date: DateTime.now(),
        );
        
        addToPending(backupTransaction);
        return backupTransaction;
      }
      
      return null;
    }
  }

  /// Enhanced savings recording with monitoring
  static Future<Transaction?> recordSavingsWithMonitoring(
    BudgetManager budgetManager,
    double amount,
    String description, {
    String? goalName,
  }) async {
    try {
      final transaction = await budgetManager.addToSavings(amount, description, goalName: goalName);
      
      if (transaction != null) {
        await _verifyTransactionSaved(transaction);
      }
      
      return transaction;
    } catch (e) {
      debugPrint('Error in recordSavingsWithMonitoring: $e');
      
      // Create backup transaction if balance allows
      if (budgetManager.currentBalance >= amount) {
        final backupTransaction = Transaction(
          id: TransactionService.generateTransactionId(),
          amount: amount,
          type: TransactionType.savings,
          category: goalName ?? 'General Savings',
          description: description,
          date: DateTime.now(),
        );
        
        addToPending(backupTransaction);
        return backupTransaction;
      }
      
      return null;
    }
  }

  /// Enhanced savings withdrawal with monitoring
  static Future<Transaction?> recordSavingsWithdrawalWithMonitoring(
    BudgetManager budgetManager,
    double amount,
    String description, {
    String? goalName,
  }) async {
    try {
      final transaction = await budgetManager.withdrawFromSavings(amount, description, goalName: goalName);
      
      if (transaction != null) {
        await _verifyTransactionSaved(transaction);
      }
      
      return transaction;
    } catch (e) {
      debugPrint('Error in recordSavingsWithdrawalWithMonitoring: $e');
      
      // Create backup transaction if savings allows
      if (budgetManager.totalSavings >= amount) {
        final backupTransaction = Transaction(
          id: TransactionService.generateTransactionId(),
          amount: amount,
          type: TransactionType.savingsWithdrawal,
          category: goalName ?? 'General Savings',
          description: description,
          date: DateTime.now(),
        );
        
        addToPending(backupTransaction);
        return backupTransaction;
      }
      
      return null;
    }
  }

  /// Enhanced debt payment with monitoring
  static Future<Transaction?> recordDebtPaymentWithMonitoring(
    BudgetManager budgetManager,
    double amount,
    String description,
    String debtName,
  ) async {
    try {
      final transaction = await budgetManager.payDebt(amount, description, debtName);
      
      if (transaction != null) {
        await _verifyTransactionSaved(transaction);
      }
      
      return transaction;
    } catch (e) {
      debugPrint('Error in recordDebtPaymentWithMonitoring: $e');
      
      // Create backup transaction if balance and debt allows
      if (budgetManager.currentBalance >= amount && budgetManager.totalDebt >= amount) {
        final backupTransaction = Transaction(
          id: TransactionService.generateTransactionId(),
          amount: amount,
          type: TransactionType.debtPayment,
          category: debtName,
          description: description,
          date: DateTime.now(),
        );
        
        addToPending(backupTransaction);
        return backupTransaction;
      }
      
      return null;
    }
  }

  /// Verify transaction was properly saved to database
  static Future<void> _verifyTransactionSaved(Transaction transaction) async {
    try {
      // Wait a moment for the save operation to complete
      await Future.delayed(const Duration(milliseconds: 500));
      
      final exists = await TransactionRecordingService.verifyTransactionExists(transaction.id);
      if (!exists) {
        debugPrint('Transaction not found in database, adding to pending: ${transaction.id}');
        addToPending(transaction);
      } else {
        debugPrint('Transaction verified in database: ${transaction.id}');
      }
    } catch (e) {
      debugPrint('Error verifying transaction: $e');
      addToPending(transaction);
    }
  }

  /// Get pending transactions count
  static int getPendingTransactionsCount() {
    return _pendingTransactions.length;
  }

  /// Clear all pending transactions (use with caution)
  static void clearPendingTransactions() {
    _pendingTransactions.clear();
    debugPrint('Pending transactions cleared');
  }

  /// Get summary of monitoring status
  static Map<String, dynamic> getMonitoringStatus() {
    return {
      'isMonitoring': _isMonitoring,
      'pendingTransactions': _pendingTransactions.length,
      'lastCheck': DateTime.now().toIso8601String(),
    };
  }
}
