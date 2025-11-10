import 'transaction.dart';
import '../widgets/timeframe_filter.dart';
import '../services/transaction_service.dart';

class Budget {
  final String id;
  final double monthlyBudget;
  final Map<String, double> categoryBudgets;
  final DateTime month;

  Budget({
    required this.id,
    required this.monthlyBudget,
    required this.categoryBudgets,
    required this.month,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'monthlyBudget': monthlyBudget,
      'categoryBudgets': categoryBudgets,
      'month': month.toIso8601String(),
    };
  }

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'],
      monthlyBudget: (json['monthlyBudget'] as num).toDouble(),
      categoryBudgets: Map<String, double>.from(json['categoryBudgets']),
      month: DateTime.parse(json['month']),
    );
  }

  Budget copyWith({
    String? id,
    double? monthlyBudget,
    Map<String, double>? categoryBudgets,
    DateTime? month,
  }) {
    return Budget(
      id: id ?? this.id,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      categoryBudgets: categoryBudgets ?? this.categoryBudgets,
      month: month ?? this.month,
    );
  }

  double get totalCategoryBudgets {
    return categoryBudgets.values.fold(0.0, (sum, amount) => sum + amount);
  }

  double get remainingBudget {
    return monthlyBudget - totalCategoryBudgets;
  }

  bool get isOverBudget {
    return totalCategoryBudgets > monthlyBudget;
  }

  double getBudgetForCategory(String category) {
    return categoryBudgets[category] ?? 0.0;
  }

  Budget updateCategoryBudget(String category, double amount) {
    final updatedBudgets = Map<String, double>.from(categoryBudgets);
    updatedBudgets[category] = amount;
    return copyWith(categoryBudgets: updatedBudgets);
  }
}

class BudgetCategory {
  static List<String> defaultCategories = [
    'Housing & Utilities',
    'Food',
    'Groceries',
    'Transportation',
    'Debt/Loans',
    'Health & Personal Care',
    'Entertainment & Lifestyle',
    'Education',
    'Childcare',
    'Tithes & Donations',
    'Others'
  ];

  static String getCategoryIcon(String category) {
    switch (category) {
      case 'Housing & Utilities':
        return '🏠';
      case 'Food':
        return '🍽️';
      case 'Groceries':
        return '🛒';
      case 'Transportation':
        return '🚗';
      case 'Debt/Loans':
        return '💳';
      case 'Health & Personal Care':
        return '🏥';
      case 'Entertainment & Lifestyle':
        return '🎬';
      case 'Education':
        return '📚';
      case 'Childcare':
        return '👶';
      case 'Tithes & Donations':
        return '🙏';
      case 'Others':
        return '📦';
      case 'Savings':
        return '🏦';
      default:
        return '📦';
    }
  }

}

// Enhanced Budget Management for new features
class BudgetManager {
  final String userId;
  double currentBalance;
  double totalSavings;
  double totalDebt;
  final double highSpendThreshold;
  final List<String> selectedCategories;
  final Map<String, List<Transaction>> transactionsByTimeframe;

  BudgetManager({
    required this.userId,
    required this.currentBalance,
    this.totalSavings = 0.0,
    this.totalDebt = 0.0,
    this.highSpendThreshold = 1000.0,
    this.selectedCategories = const [],
    this.transactionsByTimeframe = const {},
  });

  // Enhanced budget calculation methods with transaction tracking
  Future<Transaction> addIncome(double amount, String description, {bool isFromDebt = false}) async {
    currentBalance += amount;
    final type = isFromDebt ? TransactionType.debt : TransactionType.income;
    if (isFromDebt) {
      totalDebt += amount;
    }
    final transaction = Transaction(
      id: TransactionService.generateTransactionId(),
      amount: amount,
      type: type,
      category: isFromDebt ? 'Debt Income' : 'Income',
      description: description,
      date: DateTime.now(),
    );

    // Automatically save transaction to database
    await TransactionService.addTransaction(transaction);
    return transaction;
  }

  Future<Transaction?> subtractExpense(double amount, String category, String description, {bool isRecurring = false}) async {
    if (currentBalance - amount < 0) {
      return null; // Cannot go negative
    }
    currentBalance -= amount;
    final transaction = Transaction(
      id: TransactionService.generateTransactionId(),
      amount: amount,
      type: isRecurring ? TransactionType.recurringExpense : TransactionType.expense,
      category: category,
      description: description,
      date: DateTime.now(),
    );

    // Automatically save transaction to database
    await TransactionService.addTransaction(transaction);
    return transaction;
  }

  Future<Transaction?> addToSavings(double amount, String description, {String? goalName}) async {
    if (currentBalance - amount < 0) {
      return null; // Cannot go negative
    }
    currentBalance -= amount;
    totalSavings += amount;
    final transaction = Transaction(
      id: TransactionService.generateTransactionId(),
      amount: amount,
      type: TransactionType.savings,
      category: goalName ?? 'General Savings',
      description: description,
      date: DateTime.now(),
    );

    // Automatically save transaction to database
    await TransactionService.addTransaction(transaction);
    return transaction;
  }

  Future<Transaction?> withdrawFromSavings(double amount, String description, {String? goalName}) async {
    if (totalSavings - amount < 0) {
      return null; // Cannot withdraw more than saved
    }
    totalSavings -= amount;
    currentBalance += amount;
    final transaction = Transaction(
      id: TransactionService.generateTransactionId(),
      amount: amount,
      type: TransactionType.savingsWithdrawal,
      category: goalName ?? 'General Savings',
      description: description,
      date: DateTime.now(),
    );

    // Automatically save transaction to database
    await TransactionService.addTransaction(transaction);
    return transaction;
  }

  Future<Transaction> addDebtIncome(double amount, String description) async {
    return await addIncome(amount, description, isFromDebt: true);
  }

  Future<Transaction?> payDebt(double amount, String description, String debtName) async {
    if (currentBalance - amount < 0 || totalDebt - amount < 0) {
      return null; // Cannot go negative or pay more than owed
    }
    currentBalance -= amount;
    totalDebt -= amount;
    final transaction = Transaction(
      id: TransactionService.generateTransactionId(),
      amount: amount,
      type: TransactionType.debtPayment,
      category: debtName,
      description: description,
      date: DateTime.now(),
    );

    // Automatically save transaction to database
    await TransactionService.addTransaction(transaction);
    return transaction;
  }

  // Timeframe filtering methods
  Map<String, double> getFilteredTotals(TimeFrame timeframe, DateTime date) {
    final transactions = _getTransactionsForTimeframe(timeframe, date);
    
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
          expenses += transaction.amount;
          break;
        case TransactionType.savings:
          savings += transaction.amount;
          break;
        case TransactionType.savingsWithdrawal:
          savings -= transaction.amount;
          break;
        case TransactionType.debtPayment:
          expenses += transaction.amount;
          break;
        case TransactionType.emergencyFund:
          // Emergency fund is tracked separately, doesn't affect regular savings
          break;
      }
    }
    
    return {
      'income': income,
      'expenses': expenses,
      'savings': savings,
      'net': income - expenses,
    };
  }

  List<Transaction> _getTransactionsForTimeframe(TimeFrame timeframe, DateTime date) {
    final key = '${timeframe.toString()}_${date.toString()}';
    return transactionsByTimeframe[key] ?? [];
  }

  String getSpendingLevel(double dailySpend) {
    if (dailySpend >= highSpendThreshold) return 'high';
    if (dailySpend >= highSpendThreshold * 0.6) return 'medium';
    return 'low';
  }

  // Enhanced balance monitoring
  bool get isLowBalance => currentBalance < 500.0;
  bool get isCriticalBalance => currentBalance < 100.0;
  double get availableBudget => currentBalance;
  double get totalSaved => totalSavings;
  double get remainingDebt => totalDebt;

  // Budget status
  Map<String, dynamic> getBudgetStatus() {
    return {
      'currentBalance': currentBalance,
      'totalSavings': totalSavings,
      'totalDebt': totalDebt,
      'isLowBalance': isLowBalance,
      'isCriticalBalance': isCriticalBalance,
    };
  }
}
