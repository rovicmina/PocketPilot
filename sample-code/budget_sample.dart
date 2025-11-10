// Sample code demonstrating data model structure
// This is a simplified example for demonstration purposes only

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

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'monthlyBudget': monthlyBudget,
      'categoryBudgets': categoryBudgets,
      'month': month.toIso8601String(),
    };
  }

  // Create from JSON data
  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'],
      monthlyBudget: (json['monthlyBudget'] as num).toDouble(),
      categoryBudgets: Map<String, double>.from(json['categoryBudgets']),
      month: DateTime.parse(json['month']),
    );
  }

  // Calculate total of all category budgets
  double get totalCategoryBudgets {
    return categoryBudgets.values.fold(0.0, (sum, amount) => sum + amount);
  }

  // Calculate remaining budget
  double get remainingBudget {
    return monthlyBudget - totalCategoryBudgets;
  }

  // Check if over budget
  bool get isOverBudget {
    return totalCategoryBudgets > monthlyBudget;
  }
}