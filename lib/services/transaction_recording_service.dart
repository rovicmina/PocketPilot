import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import '../models/debt.dart';
import '../models/goal.dart';
import '../models/user.dart' as user_models;
import 'transaction_service.dart';
import 'firebase_service.dart';
import 'transaction_notifier.dart';
import 'user_notifier.dart';

/// Comprehensive service for recording all types of transactions
/// Ensures all transactions are properly saved to the database
class TransactionRecordingService {
  // Transaction notifier for real-time updates
  static final TransactionNotifier _transactionNotifier = TransactionNotifier();
  
  // User notifier for profile updates
  static final UserNotifier _userNotifier = UserNotifier();
  
  /// Record a manual transaction (from Add Transaction page)
  static Future<bool> recordManualTransaction({
    required double amount,
    required TransactionType type,
    required String category,
    required String description,
    DateTime? date,
  }) async {
    try {
      final transactionDate = date ?? DateTime.now();
      final transaction = Transaction(
        id: TransactionService.generateTransactionId(),
        amount: amount,
        type: type,
        category: category,
        description: description,
        date: transactionDate,
      );
      
      await TransactionService.addTransaction(transaction);
      debugPrint('Manual transaction recorded: ${transaction.id}');
      
      // For expense transactions, update the max monthly expense
      if (type == TransactionType.expense || type == TransactionType.recurringExpense) {
        // Update max monthly expense in the background
        _updateMaxMonthlyExpense(transactionDate);
      }
      
      // Notify listeners about the new transaction
      _transactionNotifier.notifyTransactionAdded();
      
      return true;
    } catch (e) {
      debugPrint('Error recording manual transaction: $e');
      return false;
    }
  }

  /// Record income transaction
  static Future<bool> recordIncome({
    required double amount,
    required String description,
    String category = 'Income',
    DateTime? date,
  }) async {
    return await recordManualTransaction(
      amount: amount,
      type: TransactionType.income,
      category: category,
      description: description,
      date: date,
    );
  }

  /// Record expense transaction
  static Future<bool> recordExpense({
    required double amount,
    required String category,
    required String description,
    DateTime? date,
  }) async {
    return await recordManualTransaction(
      amount: amount,
      type: TransactionType.expense,
      category: category,
      description: description,
      date: date,
    );
  }

  /// Record savings deposit
  static Future<bool> recordSavingsDeposit({
    required double amount,
    required String description,
    String? goalName,
    DateTime? date,
  }) async {
    return await recordManualTransaction(
      amount: amount,
      type: TransactionType.savings,
      category: goalName ?? 'General Savings',
      description: description,
      date: date,
    );
  }

  /// Record savings withdrawal
  static Future<bool> recordSavingsWithdrawal({
    required double amount,
    required String description,
    String? goalName,
    DateTime? date,
  }) async {
    return await recordManualTransaction(
      amount: amount,
      type: TransactionType.savingsWithdrawal,
      category: goalName ?? 'General Savings',
      description: description,
      date: date,
    );
  }

  /// Record debt-related income (taking a loan)
  static Future<bool> recordDebtIncome({
    required double amount,
    required String description,
    String category = 'Loan',
    DateTime? date,
  }) async {
    try {
      // First record the debt transaction
      final debtSuccess = await recordManualTransaction(
        amount: amount,
        type: TransactionType.debt,
        category: category,
        description: description,
        date: date,
      );
      
      if (debtSuccess) {
        // Also record an income transaction for the debt amount
        await recordManualTransaction(
          amount: amount,
          type: TransactionType.income,
          category: 'Debt Income',
          description: 'Debt income: $description',
          date: date,
        );
      }
      
      return debtSuccess;
    } catch (e) {
      debugPrint('Error recording debt income: $e');
      return false;
    }
  }

  /// Record debt payment
  static Future<bool> recordDebtPayment({
    required double amount,
    required String debtName,
    required String description,
    DateTime? date,
  }) async {
    return await recordManualTransaction(
      amount: amount,
      type: TransactionType.debtPayment,
      category: debtName,
      description: description,
      date: date,
    );
  }

  /// Record emergency fund deposit
  static Future<bool> recordEmergencyFundDeposit({
    required double amount,
    required String description,
    DateTime? date,
  }) async {
    try {
      // First record the transaction
      final success = await recordManualTransaction(
        amount: amount,
        type: TransactionType.emergencyFund,
        category: 'Savings (EF)', // Updated category
        description: description.isEmpty ? 'Emergency Fund (S)' : description, // Default name
        date: date,
      );
      
      if (success) {
        // Then update the user's emergency fund balance
        await _updateUserEmergencyFund(amount, isDeposit: true);
      }
      
      return success;
    } catch (e) {
      debugPrint('Error recording emergency fund deposit: $e');
      return false;
    }
  }

  /// Record emergency fund withdrawal
  static Future<bool> recordEmergencyFundWithdrawal({
    required double amount,
    required String description,
    DateTime? date,
  }) async {
    try {
      // Check if user has sufficient emergency fund balance
      final user = await FirebaseService.getUser();
      if (user == null) {
        debugPrint('Error: User not found for emergency fund withdrawal');
        return false;
      }
      
      final currentEmergencyFund = user.emergencyFundAmount ?? 0.0;
      if (currentEmergencyFund < amount) {
        debugPrint('Error: Insufficient emergency fund balance. Available: ₱${currentEmergencyFund.toStringAsFixed(2)}, Requested: ₱${amount.toStringAsFixed(2)}');
        return false;
      }
      
      // First record the emergency fund withdrawal transaction
      final withdrawalSuccess = await recordManualTransaction(
        amount: amount,
        type: TransactionType.emergencyFundWithdrawal,
        category: 'Withdrawal (EF)', // Updated category
        description: description.isEmpty ? 'Emergency Fund (W)' : description, // Default name
        date: date,
      );
      
      if (withdrawalSuccess) {
        // Also record an income transaction for the withdrawn amount
        await recordManualTransaction(
          amount: amount,
          type: TransactionType.income,
          category: 'Emergency Fund Withdrawal',
          description: description.isEmpty ? 'Emergency Fund (W)' : 'Emergency fund withdrawal: $description',
          date: date,
        );
        
        // Then update the user's emergency fund balance
        await _updateUserEmergencyFund(amount, isDeposit: false);
      }
      
      return withdrawalSuccess;
    } catch (e) {
      debugPrint('Error recording emergency fund withdrawal: $e');
      return false;
    }
  }

  /// Private method to update user's emergency fund balance
  static Future<void> _updateUserEmergencyFund(double amount, {required bool isDeposit}) async {
    try {
      final user = await FirebaseService.getUser();
      if (user == null) {
        debugPrint('Error: User not found for emergency fund update');
        return;
      }
      
      final currentEmergencyFund = user.emergencyFundAmount ?? 0.0;
      final newEmergencyFund = isDeposit 
          ? currentEmergencyFund + amount
          : currentEmergencyFund - amount;
      
      // Ensure the emergency fund doesn't go below zero
      final updatedEmergencyFund = newEmergencyFund < 0 ? 0.0 : newEmergencyFund;
      
      // Update user's savings investments based on the requirements:
      // 1. If user has 'No Savings' selected, remove it and add 'Emergency Fund'
      // 2. If user has other savings, add 'Emergency Fund' to the list
      // 3. If user already has 'Emergency Fund' selected, no change needed
      List<user_models.SavingsInvestments> updatedSavingsInvestments = List.from(user.savingsInvestments);
      
      // Handle the case where user has 'No Savings' selected
      if (updatedSavingsInvestments.contains(user_models.SavingsInvestments.noSavings)) {
        updatedSavingsInvestments.remove(user_models.SavingsInvestments.noSavings);
      }
      
      // Add 'Emergency Fund' if not already present
      if (!updatedSavingsInvestments.contains(user_models.SavingsInvestments.emergencyFund)) {
        updatedSavingsInvestments.add(user_models.SavingsInvestments.emergencyFund);
      }
      
      final updatedUser = user.copyWith(
        emergencyFundAmount: updatedEmergencyFund,
        savingsInvestments: updatedSavingsInvestments,
      );
      
      await FirebaseService.saveUser(updatedUser);
      debugPrint('Updated emergency fund balance: ₱${updatedEmergencyFund.toStringAsFixed(2)}');
      
      // Notify listeners about emergency fund update
      _userNotifier.notifyEmergencyFundUpdated();
      // Notify listeners about profile update (since savings investments changed)
      _userNotifier.notifyProfileUpdated();
    } catch (e) {
      debugPrint('Error updating user emergency fund: $e');
    }
  }

  /// Record transaction from BudgetManager operations
  static Future<bool> recordBudgetManagerTransaction(Transaction transaction) async {
    try {
      await TransactionService.addTransaction(transaction);
      debugPrint('BudgetManager transaction recorded: ${transaction.id}');
      
      // Notify listeners about the new transaction
      _transactionNotifier.notifyTransactionAdded();
      
      return true;
    } catch (e) {
      debugPrint('Error recording BudgetManager transaction: $e');
      return false;
    }
  }

  /// Batch record multiple transactions
  static Future<bool> recordMultipleTransactions(List<Transaction> transactions) async {
    try {
      if (transactions.isEmpty) return true;
      
      await FirebaseService.saveTransactions(transactions);
      debugPrint('Batch recorded ${transactions.length} transactions');
      
      // Notify listeners about the new transactions
      _transactionNotifier.notifyTransactionAdded();
      
      return true;
    } catch (e) {
      debugPrint('Error batch recording transactions: $e');
      return false;
    }
  }

  /// Record transaction when a debt is created
  static Future<bool> recordNewDebt(Debt debt) async {
    return await recordDebtIncome(
      amount: debt.totalAmount,
      description: 'New debt: ${debt.name}',
      category: 'Loan',
    );
  }

  /// Record transaction when a debt payment is made
  static Future<bool> recordDebtPaymentTransaction(Debt debt, double paymentAmount) async {
    return await recordDebtPayment(
      amount: paymentAmount,
      debtName: debt.name,
      description: 'Payment for ${debt.name}',
    );
  }

  /// Record transaction when contributing to a goal
  static Future<bool> recordGoalContribution(Goal goal, double amount) async {
    return await recordSavingsDeposit(
      amount: amount,
      description: 'Contribution to ${goal.name}',
      goalName: goal.name,
    );
  }

  /// Validate transaction before recording
  static bool validateTransaction({
    required double amount,
    required String category,
    required String description,
  }) {
    if (amount <= 0) {
      debugPrint('Invalid transaction: Amount must be positive');
      return false;
    }
    
    if (category.trim().isEmpty) {
      debugPrint('Invalid transaction: Category cannot be empty');
      return false;
    }
    
    // Description is now optional - no validation needed
    
    return true;
  }

  /// Get all transactions for verification
  static Future<List<Transaction>> getAllRecordedTransactions() async {
    try {
      return await TransactionService.getAllTransactions();
    } catch (e) {
      debugPrint('Error getting all transactions: $e');
      return [];
    }
  }

  /// Verify if a transaction exists in the database
  static Future<bool> verifyTransactionExists(String transactionId) async {
    try {
      final transactions = await getAllRecordedTransactions();
      return transactions.any((t) => t.id == transactionId);
    } catch (e) {
      debugPrint('Error verifying transaction: $e');
      return false;
    }
  }

  /// Update max monthly expense by recalculating from historical data
  /// This ensures that when large transactions are added or deleted, the max is properly recalculated
  static Future<void> _updateMaxMonthlyExpense(DateTime transactionDate) async {
    try {
      // Get current user
      final user = await FirebaseService.getUser();
      if (user == null) return;

      // Recalculate the true maximum from historical data
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

          final categoryTotals = await TransactionService.getExpenseCategoryTotals(
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
