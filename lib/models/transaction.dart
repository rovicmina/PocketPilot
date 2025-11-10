import 'package:intl/intl.dart';

enum TransactionType { 
  income,
  expense, 
  savings, 
  savingsWithdrawal, 
  debt, 
  debtPayment,
  recurringExpense,
  emergencyFund,
  emergencyFundWithdrawal
}

class Transaction {
  final String id;
  final double amount;
  final TransactionType type;
  final String category;
  final String description;
  final DateTime date;

  Transaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
    required this.description,
    required this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'type': type.toString(),
      'category': category,
      'description': description,
      'date': date.toIso8601String(),
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      amount: json['amount'].toDouble(),
      type: TransactionType.values.firstWhere(
        (e) => e.toString() == json['type'],
      ),
      category: json['category'],
      description: json['description'],
      date: DateTime.parse(json['date']),
    );
  }

  String get formattedAmount {
    final formatter = NumberFormat.currency(symbol: '₱');
    return formatter.format(amount);
  }

  String get formattedDate {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  String get typeIcon {
    switch (type) {
      case TransactionType.expense:
        return '💰';
      case TransactionType.income:
        return '💰';
      case TransactionType.savings:
        return '🏦';
      case TransactionType.savingsWithdrawal:
        return '🏧';
      case TransactionType.debt:
        return '📄';
      case TransactionType.debtPayment:
        return '💰';
      case TransactionType.recurringExpense:
        return '🔄';
      case TransactionType.emergencyFund:
        return '🚨';
      case TransactionType.emergencyFundWithdrawal:
        return '⚡';
    }
  }

  String get typeDisplayName {
    switch (type) {
      case TransactionType.expense:
        return 'Expense';
      case TransactionType.income:
        return 'Income';
      case TransactionType.savings:
        return 'Savings';
      case TransactionType.savingsWithdrawal:
        return 'Withdrawal';
      case TransactionType.debt:
        return 'Debt';
      case TransactionType.debtPayment:
        return 'Debt Payment';
      case TransactionType.recurringExpense:
        return 'Recurring Expense';
      case TransactionType.emergencyFund:
        return 'Emergency Fund';
      case TransactionType.emergencyFundWithdrawal:
        return 'Withdrawal (EF)';
    }
  }
}
