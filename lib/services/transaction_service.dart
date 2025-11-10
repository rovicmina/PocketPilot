import '../models/transaction.dart';
import '../models/debt.dart';
import 'firebase_service.dart';
import 'budget_preloader_service.dart';
import 'budget_prescription_service.dart';
import 'real_time_update_service.dart';
import 'transaction_notifier.dart';
import 'widget_data_service.dart';

class TransactionService {
  static Future<List<Transaction>> getAllTransactions() async {
    return await FirebaseService.getTransactions();
  }

  static Future<List<Transaction>> getTransactionsByDateRange(
      DateTime startDate, DateTime endDate) async {
    // Use the new date-based Firebase query for better performance
    return await FirebaseService.getTransactionsByDateRange(startDate, endDate);
  }

  static Future<List<Transaction>> getTransactionsByDate(DateTime date) async {
    // Get transactions for a specific date
    return await FirebaseService.getTransactionsByDate(date);
  }

  static Future<List<Transaction>> getTransactionsByMonth(int year, int month) async {
    // Get transactions for a specific month
    return await FirebaseService.getTransactionsByMonth(year, month);
  }

  static Future<List<Transaction>> getTransactionsByYear(int year) async {
    // Get transactions for a specific year
    return await FirebaseService.getTransactionsByYear(year);
  }

  static Future<List<Transaction>> getTransactionsByType(
    TransactionType type, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    List<Transaction> transactions;
    if (startDate != null && endDate != null) {
      transactions = await getTransactionsByDateRange(startDate, endDate);
    } else {
      transactions = await getAllTransactions();
    }
    return transactions.where((transaction) => transaction.type == type).toList();
  }

  static Future<List<Transaction>> getTransactionsByCategory(
    String category, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    List<Transaction> transactions;
    if (startDate != null && endDate != null) {
      transactions = await getTransactionsByDateRange(startDate, endDate);
    } else {
      transactions = await getAllTransactions();
    }
    return transactions.where((transaction) => transaction.category == category).toList();
  }

  static Future<double> getTotalByType(
    TransactionType type, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    List<Transaction> transactions;
    
    if (startDate != null && endDate != null) {
      transactions = await getTransactionsByDateRange(startDate, endDate);
    } else {
      transactions = await getAllTransactions();
    }
    
    return transactions
        .where((transaction) => transaction.type == type)
        .fold<double>(0.0, (double sum, Transaction transaction) => sum + transaction.amount);
  }

  /// Get total income including debt transactions (which are treated as income)
  /// Excludes duplicate income transactions for debt and emergency fund withdrawals
  static Future<double> getTotalIncomeWithDebt({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    List<Transaction> transactions;
    
    if (startDate != null && endDate != null) {
      transactions = await getTransactionsByDateRange(startDate, endDate);
    } else {
      transactions = await getAllTransactions();
    }
    
    return transactions
        .where((transaction) => 
            (transaction.type == TransactionType.income && 
             transaction.category != 'Debt Income' && 
             transaction.category != 'Emergency Fund Withdrawal') ||
            transaction.type == TransactionType.debt ||
            transaction.type == TransactionType.emergencyFundWithdrawal)
        .fold<double>(0.0, (double sum, Transaction transaction) => sum + transaction.amount);
  }

  static Future<double> getCurrentBalance() async {
    final income = await getTotalByType(TransactionType.income);
    final expenses = await getTotalByType(TransactionType.expense);
    final savings = await getTotalByType(TransactionType.savings);
    final savingsWithdrawals = await getTotalByType(TransactionType.savingsWithdrawal);
    final debt = await getTotalByType(TransactionType.debt);
    final debtPayments = await getTotalByType(TransactionType.debtPayment);
    final emergencyFund = await getTotalByType(TransactionType.emergencyFund);
    final emergencyFundWithdrawals = await getTotalByType(TransactionType.emergencyFundWithdrawal);
    
    // Emergency fund transactions don't affect current balance since they're managed separately
    return income + savingsWithdrawals + debt + emergencyFundWithdrawals - expenses - savings - debtPayments - emergencyFund;
  }

  static Future<Map<String, double>> getMonthlyTotals(DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);
    
    return await getPeriodTotals(startOfMonth, endOfMonth);
  }

  static Future<Map<String, double>> getPeriodTotals(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final income = await getTotalByType(
      TransactionType.income,
      startDate: startDate,
      endDate: endDate,
    );
    final expenses = await getTotalByType(
      TransactionType.expense,
      startDate: startDate,
      endDate: endDate,
    );
    final savings = await getTotalByType(
      TransactionType.savings,
      startDate: startDate,
      endDate: endDate,
    );
    final savingsWithdrawals = await getTotalByType(
      TransactionType.savingsWithdrawal,
      startDate: startDate,
      endDate: endDate,
    );
    final debt = await getTotalByType(
      TransactionType.debt,
      startDate: startDate,
      endDate: endDate,
    );
    final debtPayments = await getTotalByType(
      TransactionType.debtPayment,
      startDate: startDate,
      endDate: endDate,
    );
    
    return {
      'income': income,
      'expenses': expenses,
      'savings': savings - savingsWithdrawals,
      'debt': debt - debtPayments,
      'balance': income + savingsWithdrawals + debt - expenses - savings - debtPayments,
    };
  }

  static Future<Map<String, double>> getCategoryTotals({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    List<Transaction> transactions;
    
    if (startDate != null && endDate != null) {
      transactions = await getTransactionsByDateRange(startDate, endDate);
    } else {
      transactions = await getAllTransactions();
    }
    
    final Map<String, double> categoryTotals = {};
    
    for (final transaction in transactions) {
      if (transaction.type == TransactionType.expense) {
        categoryTotals[transaction.category] = 
            (categoryTotals[transaction.category] ?? 0) + transaction.amount;
      }
    }
    
    return categoryTotals;
  }

  static Future<List<Transaction>> getRecentTransactions({int limit = 10}) async {
    final transactions = await getAllTransactions();
    transactions.sort((a, b) => b.date.compareTo(a.date));
    return transactions.take(limit).toList();
  }

  static Future<Map<DateTime, double>> getDailySpending(DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);
    
    final transactions = await getTransactionsByDateRange(startOfMonth, endOfMonth);
    final Map<DateTime, double> dailySpending = {};
    
    for (final transaction in transactions) {
      if (transaction.type == TransactionType.expense) {
        final date = DateTime(transaction.date.year, transaction.date.month, transaction.date.day);
        dailySpending[date] = (dailySpending[date] ?? 0) + transaction.amount;
      }
    }
    
    return dailySpending;
  }

  // New methods for line chart data
  static Future<Map<DateTime, Map<String, double>>> getIncomeExpenseOverTime({
    required DateTime startDate,
    required DateTime endDate,
    required String period, // 'daily', 'weekly', 'monthly'
  }) async {
    final transactions = await getTransactionsByDateRange(startDate, endDate);
    final Map<DateTime, Map<String, double>> timeSeriesData = {};
    
    for (final transaction in transactions) {
      DateTime periodKey;
      
      switch (period) {
        case 'daily':
          periodKey = DateTime(transaction.date.year, transaction.date.month, transaction.date.day);
          break;
        case 'weekly':
          final daysSinceMonday = transaction.date.weekday - 1;
          periodKey = transaction.date.subtract(Duration(days: daysSinceMonday));
          periodKey = DateTime(periodKey.year, periodKey.month, periodKey.day);
          break;
        case 'monthly':
          periodKey = DateTime(transaction.date.year, transaction.date.month, 1);
          break;
        default:
          periodKey = DateTime(transaction.date.year, transaction.date.month, transaction.date.day);
      }
      
      if (!timeSeriesData.containsKey(periodKey)) {
        timeSeriesData[periodKey] = {'income': 0.0, 'expenses': 0.0};
      }
      
      if (transaction.type == TransactionType.income) {
        timeSeriesData[periodKey]!['income'] = 
            (timeSeriesData[periodKey]!['income'] ?? 0) + transaction.amount;
      } else if (transaction.type == TransactionType.expense || 
                 transaction.type == TransactionType.recurringExpense) {
        timeSeriesData[periodKey]!['expenses'] = 
            (timeSeriesData[periodKey]!['expenses'] ?? 0) + transaction.amount;
      }
    }
    
    return timeSeriesData;
  }

  static Future<Map<String, double>> getExpenseCategoryTotals({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    List<Transaction> transactions;
    
    if (startDate != null && endDate != null) {
      transactions = await getTransactionsByDateRange(startDate, endDate);
    } else {
      transactions = await getAllTransactions();
    }
    
    final Map<String, double> categoryTotals = {};
    
    for (final transaction in transactions) {
      if (transaction.type == TransactionType.expense || 
          transaction.type == TransactionType.recurringExpense) {
        categoryTotals[transaction.category] = 
            (categoryTotals[transaction.category] ?? 0) + transaction.amount;
      }
    }
    
    return categoryTotals;
  }

  static final TransactionNotifier _transactionNotifier = TransactionNotifier();
  
  static Future<void> addTransaction(Transaction transaction) async {
    await FirebaseService.addTransaction(transaction);

    // Check if this is an expense transaction and update max monthly expense if needed
    if (transaction.type == TransactionType.expense || transaction.type == TransactionType.recurringExpense) {
      await _updateMaxMonthlyExpense(transaction.date);

      // Invalidate prescriptions that use this month as data source since the data has changed
      final transactionMonth = DateTime(transaction.date.year, transaction.date.month, 1);
      await BudgetPrescriptionService.invalidatePrescriptionsUsingDataSourceMonth(transactionMonth);
    }

    // Invalidate preloaded budget data since new transaction affects budget calculations
    BudgetPreloaderService.invalidatePreloadedData();

    // Notify all listeners about the new transaction for real-time updates
    _transactionNotifier.notifyTransactionAdded();

    // Update widget data for home screen widgets
    await WidgetDataService.updateWidgetData();

    // Trigger comprehensive real-time updates across the app
    await RealTimeUpdateService.onTransactionAdded();
  }

  /// Delete a transaction and handle all necessary cleanup
  static Future<void> deleteTransaction(Transaction transaction) async {
    await FirebaseService.deleteTransactionByDate(transaction.id, transaction.date);

    // Check if this is an expense transaction and update max monthly expense if needed
    if (transaction.type == TransactionType.expense || transaction.type == TransactionType.recurringExpense) {
      await _updateMaxMonthlyExpense(transaction.date);
    }

    // Invalidate prescriptions that use this month as data source since the data has changed
    final transactionMonth = DateTime(transaction.date.year, transaction.date.month, 1);
    await BudgetPrescriptionService.invalidatePrescriptionsUsingDataSourceMonth(transactionMonth);

    // Invalidate preloaded budget data since transaction affects budget calculations
    BudgetPreloaderService.invalidatePreloadedData();

    // Notify all listeners about the transaction deletion for real-time updates
    _transactionNotifier.notifyTransactionDeleted();

    // Update widget data for home screen widgets
    await WidgetDataService.updateWidgetData();

    // Trigger comprehensive real-time updates across the app
    await RealTimeUpdateService.onTransactionDeleted();
  }

  // Note: Delete functionality removed as per requirements
  // Transactions cannot be deleted, only recorded

  static String generateTransactionId() {
    return 'txn_${DateTime.now().millisecondsSinceEpoch}';
  }

  // Helper methods for debt management
  static Future<void> recordDebtPayment(Debt debt, double amount) async {
    final transaction = Transaction(
      id: generateTransactionId(),
      amount: amount,
      type: TransactionType.debtPayment,
      category: 'Debt Payment',
      description: 'Payment for ${debt.name}',
      date: DateTime.now(),
    );
    
    await addTransaction(transaction);
    
    // Update debt status
    final updatedDebt = debt.copyWith(
      remainingAmount: debt.remainingAmount - amount,
      isPaidOff: debt.remainingAmount - amount <= 0,
    );
    
    await FirebaseService.saveDebt(updatedDebt);
  }

  static Future<void> recordDebtIncome(Debt debt) async {
    final transaction = Transaction(
      id: generateTransactionId(),
      amount: debt.totalAmount,
      type: TransactionType.debt,
      category: 'Loan',
      description: 'New debt: ${debt.name}',
      date: DateTime.now(),
    );
    
    await addTransaction(transaction);
  }

  // Helper methods for savings management
  static Future<void> recordSavingsDeposit(String category, double amount, String description) async {
    final transaction = Transaction(
      id: generateTransactionId(),
      amount: amount,
      type: TransactionType.savings,
      category: category,
      description: description,
      date: DateTime.now(),
    );
    
    await addTransaction(transaction);
  }

  static Future<void> recordSavingsWithdrawal(String category, double amount, String description) async {
    final transaction = Transaction(
      id: generateTransactionId(),
      amount: amount,
      type: TransactionType.savingsWithdrawal,
      category: category,
      description: description,
      date: DateTime.now(),
    );
    
    await addTransaction(transaction);
  }

  // Batch transaction recording for multiple transactions
  static Future<void> recordTransactions(List<Transaction> transactions) async {
    await FirebaseService.saveTransactions(transactions);

    // Check for expense transactions and update max monthly expense if needed
    final expenseTransactions = transactions.where((t) =>
        t.type == TransactionType.expense || t.type == TransactionType.recurringExpense);
    if (expenseTransactions.isNotEmpty) {
      // Get unique months from expense transactions
      final months = expenseTransactions.map((t) => DateTime(t.date.year, t.date.month)).toSet();
      for (final month in months) {
        await _updateMaxMonthlyExpense(month);

        // Invalidate prescriptions that use this month as data source
        await BudgetPrescriptionService.invalidatePrescriptionsUsingDataSourceMonth(month);
      }
    }

    // Invalidate preloaded budget data since new transactions affect budget calculations
    if (transactions.isNotEmpty) {
      BudgetPreloaderService.invalidatePreloadedData();

      // Notify all listeners about the new transactions for real-time updates
      _transactionNotifier.notifyTransactionAdded();

      // Trigger comprehensive real-time updates across the app
      await RealTimeUpdateService.onTransactionAdded();
    }
  }

  // Helper method to record income transaction
  static Future<void> recordIncome(double amount, String description, {String category = 'Income'}) async {
    final transaction = Transaction(
      id: generateTransactionId(),
      amount: amount,
      type: TransactionType.income,
      category: category,
      description: description,
      date: DateTime.now(),
    );

    await addTransaction(transaction);
  }

  // Helper method to record expense transaction
  static Future<void> recordExpense(double amount, String category, String description) async {
    final transaction = Transaction(
      id: generateTransactionId(),
      amount: amount,
      type: TransactionType.expense,
      category: category,
      description: description,
      date: DateTime.now(),
    );

    await addTransaction(transaction);
  }

  // Helper method to ensure all transactions from BudgetManager are saved
  static Future<void> syncBudgetManagerTransactions(List<Transaction> transactions) async {
    if (transactions.isNotEmpty) {
      await recordTransactions(transactions);
    }
  }

  // Convenient date-based query methods
  static Future<List<Transaction>> getTodayTransactions() async {
    final today = DateTime.now();
    return await getTransactionsByDate(today);
  }

  static Future<List<Transaction>> getYesterdayTransactions() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return await getTransactionsByDate(yesterday);
  }

  static Future<List<Transaction>> getThisWeekTransactions() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    return await getTransactionsByDateRange(startOfWeek, endOfWeek);
  }

  static Future<List<Transaction>> getThisMonthTransactions() async {
    final now = DateTime.now();
    return await getTransactionsByMonth(now.year, now.month);
  }

  static Future<List<Transaction>> getLastMonthTransactions() async {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    return await getTransactionsByMonth(lastMonth.year, lastMonth.month);
  }

  static Future<List<Transaction>> getThisYearTransactions() async {
    final now = DateTime.now();
    return await getTransactionsByYear(now.year);
  }

  static Future<List<Transaction>> getLastNDaysTransactions(int days) async {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));
    return await getTransactionsByDateRange(startDate, now);
  }

  // Get transactions for a specific week
  static Future<List<Transaction>> getWeekTransactions(DateTime weekStart) async {
    final weekEnd = weekStart.add(const Duration(days: 6));
    return await getTransactionsByDateRange(weekStart, weekEnd);
  }

  // Get transactions between two specific dates (inclusive)
  static Future<List<Transaction>> getTransactionsBetween(DateTime start, DateTime end) async {
    return await getTransactionsByDateRange(start, end);
  }

  // Get transaction count for a specific date
  static Future<int> getTransactionCountByDate(DateTime date) async {
    final transactions = await getTransactionsByDate(date);
    return transactions.length;
  }

  // Get transaction total amount for a specific date
  static Future<double> getTransactionTotalByDate(DateTime date, {TransactionType? type}) async {
    final transactions = await getTransactionsByDate(date);
    if (type != null) {
      return transactions
          .where((t) => t.type == type)
          .fold<double>(0.0, (sum, t) => sum + t.amount);
    }
    return transactions.fold<double>(0.0, (sum, t) => sum + t.amount);
  }

  // Update max monthly expense by recalculating from historical data
  // This ensures that when large transactions are deleted, the max is properly recalculated
  static Future<void> _updateMaxMonthlyExpense(DateTime transactionDate) async {
    try {
      // Get current user
      final user = await FirebaseService.getUser();
      if (user == null) return;

      // Instead of just checking if the current month's total exceeds the max,
      // we should recalculate the true maximum from historical data
      final now = DateTime.now();
      double maxExpenses = 0.0;

      // Check the current month and last 11 months for historical data (12 months total)
      for (int i = 0; i <= 11; i++) {
        // Handle month and year boundaries properly
        DateTime monthDate;
        if (now.month - i <= 0) {
          // We need to go back to previous year(s)
          final monthsBack = now.month - i;
          final yearsBack = (monthsBack.abs() / 12).floor();
          final finalMonth = 12 - (monthsBack.abs() % 12);
          monthDate = DateTime(now.year - yearsBack - 1, finalMonth, 1);
        } else {
          monthDate = DateTime(now.year, now.month - i, 1);
        }

        try {
          final startOfMonth = DateTime(monthDate.year, monthDate.month, 1);
          final endOfMonth = DateTime(monthDate.year, monthDate.month + 1, 0);

          final categoryTotals = await getExpenseCategoryTotals(
            startDate: startOfMonth,
            endDate: endOfMonth,
          );

          final monthTotal = categoryTotals.values.fold(0.0, (sum, amount) => sum + amount);

          if (monthTotal > maxExpenses) {
            maxExpenses = monthTotal;
          }
        } catch (e) {
          continue;
        }
      }

      // Always update the user's maxMonthlyExpense with the recalculated value
      final updatedUser = user.copyWith(maxMonthlyExpense: maxExpenses);
      await FirebaseService.saveUser(updatedUser);
    } catch (e) {
      // Silent error handling
    }
  }
}
