import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import 'firebase_service.dart';
import 'transaction_service.dart';

/// Service for date-based transaction operations
/// Provides efficient querying and management of transactions organized by date
class DateBasedTransactionService {
  
  /// Get transactions for today
  static Future<List<Transaction>> getTodayTransactions() async {
    final today = DateTime.now();
    return await FirebaseService.getTransactionsByDate(today);
  }

  /// Get transactions for a specific date
  static Future<List<Transaction>> getTransactionsForDate(DateTime date) async {
    return await FirebaseService.getTransactionsByDate(date);
  }

  /// Get transactions for current week (Monday to Sunday)
  static Future<List<Transaction>> getCurrentWeekTransactions() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    return await FirebaseService.getTransactionsByDateRange(startOfWeek, endOfWeek);
  }

  /// Get transactions for current month
  static Future<List<Transaction>> getCurrentMonthTransactions() async {
    final now = DateTime.now();
    return await FirebaseService.getTransactionsByMonth(now.year, now.month);
  }

  /// Get transactions for a specific month
  static Future<List<Transaction>> getMonthTransactions(int year, int month) async {
    return await FirebaseService.getTransactionsByMonth(year, month);
  }

  /// Get transactions for current year
  static Future<List<Transaction>> getCurrentYearTransactions() async {
    final now = DateTime.now();
    return await FirebaseService.getTransactionsByYear(now.year);
  }

  /// Get transactions for last N days
  static Future<List<Transaction>> getLastNDaysTransactions(int days) async {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days - 1));
    return await FirebaseService.getTransactionsByDateRange(startDate, now);
  }

  /// Get daily transaction summary for a date range
  static Future<Map<String, Map<String, double>>> getDailyTransactionSummary(
    DateTime startDate, 
    DateTime endDate
  ) async {
    final Map<String, Map<String, double>> summary = {};
    
    DateTime currentDate = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    
    while (currentDate.isBefore(end) || currentDate.isAtSameMomentAs(end)) {
      final dateKey = _formatDateKey(currentDate);
      final transactions = await getTransactionsForDate(currentDate);
      
      double income = 0.0;
      double expenses = 0.0;
      double savings = 0.0;
      
      for (final transaction in transactions) {
        switch (transaction.type) {
          case TransactionType.income:
            // Exclude duplicate income transactions for debt and emergency fund withdrawals
            if (transaction.category != 'Debt Income' && 
                transaction.category != 'Emergency Fund Withdrawal') {
              income += transaction.amount;
            }
            break;
          case TransactionType.debt:
          case TransactionType.emergencyFundWithdrawal: // Emergency fund withdrawal adds to income
            income += transaction.amount;
            break;
          case TransactionType.expense:
          case TransactionType.recurringExpense:
          case TransactionType.debtPayment:
            expenses += transaction.amount;
            break;
          case TransactionType.savings:
            savings += transaction.amount;
            break;
          case TransactionType.savingsWithdrawal:
            savings -= transaction.amount;
            break;
          case TransactionType.emergencyFund:
            // Emergency fund is tracked separately, doesn't affect regular savings
            break;
        }
      }
      
      summary[dateKey] = {
        'income': income,
        'expenses': expenses,
        'savings': savings,
        'net': income - expenses,
        'count': transactions.length.toDouble(),
      };
      
      currentDate = currentDate.add(const Duration(days: 1));
    }
    
    return summary;
  }

  /// Get monthly transaction summary for a year
  static Future<Map<String, Map<String, double>>> getMonthlyTransactionSummary(int year) async {
    final Map<String, Map<String, double>> summary = {};
    
    for (int month = 1; month <= 12; month++) {
      final monthKey = '$year-${month.toString().padLeft(2, '0')}';
      final transactions = await getMonthTransactions(year, month);
      
      double income = 0.0;
      double expenses = 0.0;
      double savings = 0.0;
      
      for (final transaction in transactions) {
        switch (transaction.type) {
          case TransactionType.income:
            // Exclude duplicate income transactions for debt and emergency fund withdrawals
            if (transaction.category != 'Debt Income' && 
                transaction.category != 'Emergency Fund Withdrawal') {
              income += transaction.amount;
            }
            break;
          case TransactionType.debt:
          case TransactionType.emergencyFundWithdrawal: // Emergency fund withdrawal adds to income
            income += transaction.amount;
            break;
          case TransactionType.expense:
          case TransactionType.recurringExpense:
          case TransactionType.debtPayment:
            expenses += transaction.amount;
            break;
          case TransactionType.savings:
            savings += transaction.amount;
            break;
          case TransactionType.savingsWithdrawal:
            savings -= transaction.amount;
            break;
          case TransactionType.emergencyFund:
            // Emergency fund is tracked separately, doesn't affect regular savings
            break;
        }
      }
      
      summary[monthKey] = {
        'income': income,
        'expenses': expenses,
        'savings': savings,
        'net': income - expenses,
        'count': transactions.length.toDouble(),
      };
    }
    
    return summary;
  }

  /// Get transactions by category for a specific date
  static Future<Map<String, List<Transaction>>> getTransactionsByCategory(DateTime date) async {
    final transactions = await getTransactionsForDate(date);
    final Map<String, List<Transaction>> categorized = {};
    
    for (final transaction in transactions) {
      categorized.putIfAbsent(transaction.category, () => []).add(transaction);
    }
    
    return categorized;
  }

  /// Get category spending for a date range
  static Future<Map<String, double>> getCategorySpending(
    DateTime startDate, 
    DateTime endDate, {
    TransactionType? filterType,
  }) async {
    final transactions = await FirebaseService.getTransactionsByDateRange(startDate, endDate);
    final Map<String, double> categoryTotals = {};
    
    for (final transaction in transactions) {
      if (filterType == null || transaction.type == filterType) {
        categoryTotals[transaction.category] = 
            (categoryTotals[transaction.category] ?? 0.0) + transaction.amount;
      }
    }
    
    return categoryTotals;
  }

  /// Check if there are transactions for a specific date
  static Future<bool> hasTransactionsForDate(DateTime date) async {
    final transactions = await getTransactionsForDate(date);
    return transactions.isNotEmpty;
  }

  /// Get the first and last transaction dates
  static Future<Map<String, DateTime?>> getTransactionDateRange() async {
    try {
      final allTransactions = await TransactionService.getAllTransactions();
      if (allTransactions.isEmpty) {
        return {'first': null, 'last': null};
      }
      
      allTransactions.sort((a, b) => a.date.compareTo(b.date));
      return {
        'first': allTransactions.first.date,
        'last': allTransactions.last.date,
      };
    } catch (e) {
      debugPrint('Error getting transaction date range: $e');
      return {'first': null, 'last': null};
    }
  }

  /// Get transaction statistics for a specific date
  static Future<Map<String, dynamic>> getDateStatistics(DateTime date) async {
    final transactions = await getTransactionsForDate(date);
    
    if (transactions.isEmpty) {
      return {
        'totalTransactions': 0,
        'totalAmount': 0.0,
        'income': 0.0,
        'expenses': 0.0,
        'savings': 0.0,
        'categories': <String>[],
        'averageAmount': 0.0,
      };
    }
    
    double income = 0.0;
    double expenses = 0.0;
    double savings = 0.0;
    final Set<String> categories = {};
    
    for (final transaction in transactions) {
      categories.add(transaction.category);
      
      switch (transaction.type) {
        case TransactionType.income:
          // Exclude duplicate income transactions for debt and emergency fund withdrawals
          if (transaction.category != 'Debt Income' && 
              transaction.category != 'Emergency Fund Withdrawal') {
            income += transaction.amount;
          }
          break;
        case TransactionType.debt:
        case TransactionType.emergencyFundWithdrawal: // Emergency fund withdrawal adds to income
          income += transaction.amount;
          break;
        case TransactionType.expense:
        case TransactionType.recurringExpense:
        case TransactionType.debtPayment:
          expenses += transaction.amount;
          break;
        case TransactionType.savings:
          savings += transaction.amount;
          break;
        case TransactionType.savingsWithdrawal:
          savings -= transaction.amount;
          break;
        case TransactionType.emergencyFund:
          // Emergency fund is tracked separately, doesn't affect regular savings
          break;
      }
    }
    
    return {
      'totalTransactions': transactions.length,
      'totalAmount': income + expenses + savings.abs(),
      'income': income,
      'expenses': expenses,
      'savings': savings,
      'categories': categories.toList(),
      'averageAmount': (income + expenses + savings.abs()) / transactions.length,
    };
  }

  /// Get days with transactions in a month
  static Future<List<int>> getDaysWithTransactions(int year, int month) async {
    final transactions = await getMonthTransactions(year, month);
    final Set<int> days = {};
    
    for (final transaction in transactions) {
      if (transaction.date.year == year && transaction.date.month == month) {
        days.add(transaction.date.day);
      }
    }
    
    return days.toList()..sort();
  }

  /// Helper method to format date as string key
  static String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Get transaction trends (comparing with previous period)
  static Future<Map<String, dynamic>> getTransactionTrends(
    DateTime startDate, 
    DateTime endDate
  ) async {
    final currentPeriod = await FirebaseService.getTransactionsByDateRange(startDate, endDate);
    
    // Calculate previous period (same duration)
    final duration = endDate.difference(startDate);
    final prevEndDate = startDate.subtract(const Duration(days: 1));
    final prevStartDate = prevEndDate.subtract(duration);
    
    final previousPeriod = await FirebaseService.getTransactionsByDateRange(prevStartDate, prevEndDate);
    
    // Calculate totals for current period
    double currentIncome = 0.0;
    double currentExpenses = 0.0;
    
    for (final transaction in currentPeriod) {
      switch (transaction.type) {
        case TransactionType.income:
          // Exclude duplicate income transactions for debt and emergency fund withdrawals
          if (transaction.category != 'Debt Income' && 
              transaction.category != 'Emergency Fund Withdrawal') {
            currentIncome += transaction.amount;
          }
          break;
        case TransactionType.debt:
        case TransactionType.emergencyFundWithdrawal: // Emergency fund withdrawal adds to income
          currentIncome += transaction.amount;
          break;
        case TransactionType.expense:
        case TransactionType.recurringExpense:
        case TransactionType.debtPayment:
          currentExpenses += transaction.amount;
          break;
        default:
          break;
      }
    }
    
    // Calculate totals for previous period
    double previousIncome = 0.0;
    double previousExpenses = 0.0;
    
    for (final transaction in previousPeriod) {
      switch (transaction.type) {
        case TransactionType.income:
          // Exclude duplicate income transactions for debt and emergency fund withdrawals
          if (transaction.category != 'Debt Income' && 
              transaction.category != 'Emergency Fund Withdrawal') {
            previousIncome += transaction.amount;
          }
          break;
        case TransactionType.debt:
        case TransactionType.emergencyFundWithdrawal: // Emergency fund withdrawal adds to income
          previousIncome += transaction.amount;
          break;
        case TransactionType.expense:
        case TransactionType.recurringExpense:
        case TransactionType.debtPayment:
          previousExpenses += transaction.amount;
          break;
        default:
          break;
      }
    }
    
    // Calculate percentage changes
    final incomeChange = previousIncome > 0 
        ? ((currentIncome - previousIncome) / previousIncome) * 100 
        : 0.0;
    final expenseChange = previousExpenses > 0 
        ? ((currentExpenses - previousExpenses) / previousExpenses) * 100 
        : 0.0;
    
    return {
      'currentPeriod': {
        'income': currentIncome,
        'expenses': currentExpenses,
        'net': currentIncome - currentExpenses,
        'transactionCount': currentPeriod.length,
      },
      'previousPeriod': {
        'income': previousIncome,
        'expenses': previousExpenses,
        'net': previousIncome - previousExpenses,
        'transactionCount': previousPeriod.length,
      },
      'changes': {
        'income': incomeChange,
        'expenses': expenseChange,
        'net': currentIncome - currentExpenses - (previousIncome - previousExpenses),
      }
    };
  }
}
