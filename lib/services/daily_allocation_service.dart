import 'package:flutter/material.dart';
import '../models/budget_prescription.dart';
import '../models/user.dart';
import 'budget_strategy_tips_service.dart';

/// Service for calculating daily budget allocations
class DailyAllocationService {
  /// Calculate daily allocations from monthly framework using actual spending data
  static List<DailyAllocation> calculateDailyAllocations(
    FrameworkAnalysis framework,
    Map<String, double> previousSpending,
    int daysInMonth, {
    double? maxDailyBudget,
  }) {
    final dailyAllocations = <DailyAllocation>[];

    // Get last month's daily spending averages for flexible categories
    final lastMonthDailyAverages = _calculateDailySpendingAverages(previousSpending, daysInMonth);
    
    // Get framework allocation for Needs
    final needsAllocation = framework.amounts['Needs'] ?? 0.0;
    
    // Calculate food allocation
    final foodAllocation = _calculateCategoryAllocation(
      'Food',
      lastMonthDailyAverages,
      needsAllocation,
      daysInMonth,
      isNeed: true,
    );
    
    dailyAllocations.add(DailyAllocation(
      category: 'Food',
      dailyAmount: foodAllocation,
      icon: '🍽',
      description: 'Meals, snacks, and beverages',
    ));

    // Calculate transportation allocation
    final transportAllocation = _calculateCategoryAllocation(
      'Transportation',
      lastMonthDailyAverages,
      needsAllocation,
      daysInMonth,
      isNeed: true,
    );
    
    dailyAllocations.add(DailyAllocation(
      category: 'Transportation',
      dailyAmount: transportAllocation,
      icon: '🚗',
      description: 'Commute, fuel, parking, ride-sharing',
    ));

    // Note: Entertainment and Personal Care are excluded from daily budget allocations
    // Users should manage these expenses from their flexible spending or wants allocation

    // Apply max daily budget constraint if provided
    if (maxDailyBudget != null) {
      final totalDaily = dailyAllocations.fold(0.0, (sum, allocation) => sum + allocation.dailyAmount);
      if (totalDaily > maxDailyBudget) {
        final scaleFactor = maxDailyBudget / totalDaily;
        return dailyAllocations.map((allocation) => DailyAllocation(
          category: allocation.category,
          dailyAmount: allocation.dailyAmount * scaleFactor,
          icon: allocation.icon,
          description: allocation.description,
        )).toList();
      }
    }

    return dailyAllocations;
  }

  /// Calculate monthly fixed allocations using actual previous spending
  static List<MonthlyAllocation> calculateMonthlyAllocations(
    FrameworkAnalysis framework,
    Map<String, double> previousSpending, {
    List<String>? userDebtStatuses,
    User? user, // Add user parameter to calculate strategy-based savings
  }) {
    final monthlyAllocations = <MonthlyAllocation>[];

    // Housing & Utilities - use exact amount from last month
    final housingCategories = ['Housing & Utilities', 'Rent/Mortgage', 'Electric Bill', 'Water Bill', 'Internet/WiFi', 'Phone Bill'];
    final housingAmount = housingCategories.fold(0.0, (sum, category) => sum + (previousSpending[category] ?? 0.0));
    
    if (housingAmount > 0) {
      monthlyAllocations.add(MonthlyAllocation(
        category: 'Housing & Utilities',
        monthlyAmount: housingAmount,
        icon: '🏠',
        description: 'Rent, mortgage, utilities, internet, phone - based on last month',
        isFixed: true,
      ));
    }

    // Insurance - use exact amount from last month
    final insuranceAmount = previousSpending['Insurance'] ?? 0.0;
    if (insuranceAmount > 0) {
      monthlyAllocations.add(MonthlyAllocation(
        category: 'Insurance',
        monthlyAmount: insuranceAmount,
        icon: '🛡',
        description: 'Health, auto, life, property insurance - based on last month',
        isFixed: true,
      ));
    }

    // Savings - use budget strategy allocation to match dashboard target
    double savingsAmount;
    if (user != null && (user.monthlyNet ?? 0.0) > 0) {
      // Calculate savings based on user's budget strategy to match dashboard
      final strategy = BudgetStrategyTipsService.determineBudgetStrategy(user);
      final allocations = BudgetStrategyTipsService.getStrategyAllocations(
        strategy, 
        numberOfChildren: user.numberOfChildren,
      );
      final savingsPercentage = allocations['Savings'] ?? 20.0;
      savingsAmount = user.monthlyNet! * (savingsPercentage / 100.0);
    } else {
      // Fallback to framework allocation if no user data
      savingsAmount = framework.amounts['Savings']!;
    }
    
    monthlyAllocations.add(MonthlyAllocation(
      category: 'Savings',
      monthlyAmount: savingsAmount,
      icon: '🏦',
      description: 'Investments, goals',
      isFixed: true,
    ));

    // Debt payments - only include if user has debt (not 'DebtStatus.noDebt')
    final hasDebt = userDebtStatuses != null && 
        userDebtStatuses.isNotEmpty && 
        !userDebtStatuses.contains('DebtStatus.noDebt');
    
    if (hasDebt) {
      final debtCategories = ['Debt/Loans', 'Loan Payment'];
      final previousDebtPayments = debtCategories.fold(0.0, (sum, category) => sum + (previousSpending[category] ?? 0.0));
      
      if (previousDebtPayments > 0) {
        monthlyAllocations.add(MonthlyAllocation(
          category: 'Debt Payments',
          monthlyAmount: previousDebtPayments,
          icon: '💳',
          description: 'Loan payments, credit cards - based on last month',
          isFixed: true,
        ));
      } else if (framework.amounts.containsKey('Debt')) {
        final debtAmount = framework.amounts['Debt']!;
        monthlyAllocations.add(MonthlyAllocation(
          category: 'Debt Payments',
          monthlyAmount: debtAmount,
          icon: '💳',
          description: 'Loan payments, credit cards, mortgages',
          isFixed: true,
        ));
      }
    }

    // Subscriptions - use exact amount from last month
    final subscriptionsAmount = previousSpending['Subscription'] ?? 0.0;
    if (subscriptionsAmount > 0) {
      monthlyAllocations.add(MonthlyAllocation(
        category: 'Subscriptions',
        monthlyAmount: subscriptionsAmount,
        icon: '📱',
        description: 'Streaming, software, memberships - based on last month',
        isFixed: true,
      ));
    }

    // Groceries - use exact amount from last month (monthly allocation)
    final groceriesAmount = previousSpending['Groceries'] ?? 0.0;
    if (groceriesAmount > 0) {
      monthlyAllocations.add(MonthlyAllocation(
        category: 'Groceries',
        monthlyAmount: groceriesAmount,
        icon: '🛒',
        description: 'Grocery shopping - based on last month',
        isFixed: true,
      ));
    }

    return monthlyAllocations;
  }

  /// Calculate behavior adjustments for daily budgets
  static List<BehaviorAdjustment> calculateBehaviorAdjustments(
    List<DailyAllocation> dailyAllocations,
    Map<DateTime, double> spendingHistory,
    DateTime currentDate,
  ) {
    final adjustments = <BehaviorAdjustment>[];
    final now = currentDate;

    // Check for unused budget rollover from yesterday
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdaySpent = spendingHistory[yesterday] ?? 0.0;
    final dailyBudget = dailyAllocations.fold(0.0, (sum, allocation) => sum + allocation.dailyAmount);
    
    if (yesterdaySpent < dailyBudget) {
      final rollover = dailyBudget - yesterdaySpent;
      adjustments.add(BehaviorAdjustment(
        type: 'rollover',
        adjustment: rollover,
        reason: 'Unused budget from yesterday rolls over to today',
        effectiveDate: now,
      ));
    }

    // Check for overspending penalty
    if (yesterdaySpent > dailyBudget) {
      final overspend = yesterdaySpent - dailyBudget;
      adjustments.add(BehaviorAdjustment(
        type: 'overspending',
        adjustment: -overspend,
        reason: 'Yesterday\'s overspending reduces today\'s budget',
        effectiveDate: now,
      ));
    }

    // Weekend bonus (Friday, Saturday)
    if (now.weekday == 5 || now.weekday == 6) {
      final weekendBonus = dailyBudget * 0.2;
      adjustments.add(BehaviorAdjustment(
        type: 'weekend',
        adjustment: weekendBonus,
        reason: 'Weekend bonus for social activities',
        effectiveDate: now,
      ));
    }

    // Payday bonus (assumed to be 15th and 30th)
    if (now.day == 15 || now.day == 30 || (now.day >= 28 && now.day <= 31 && now.month != (now.add(const Duration(days: 3))).month)) {
      final paydayBonus = dailyBudget * 0.15;
      adjustments.add(BehaviorAdjustment(
        type: 'payday',
        adjustment: paydayBonus,
        reason: 'Payday celebration allowance',
        effectiveDate: now,
      ));
    }

    return adjustments;
  }

  /// Calculate adjusted daily budget for a specific date
  static double calculateAdjustedDailyBudget(
    List<DailyAllocation> dailyAllocations,
    List<BehaviorAdjustment> adjustments,
    DateTime date,
  ) {
    final baseBudget = dailyAllocations.fold(0.0, (sum, allocation) => sum + allocation.dailyAmount);
    
    final todayAdjustments = adjustments.where((adjustment) {
      return adjustment.effectiveDate.year == date.year &&
             adjustment.effectiveDate.month == date.month &&
             adjustment.effectiveDate.day == date.day;
    });

    final totalAdjustment = todayAdjustments.fold(0.0, (sum, adjustment) => sum + adjustment.adjustment);
    
    return baseBudget + totalAdjustment;
  }

  /// Calculate daily spending averages from last month's data
  static Map<String, double> _calculateDailySpendingAverages(Map<String, double> previousSpending, int daysInMonth) {
    final dailyAverages = <String, double>{};
    
    // Convert monthly totals to daily averages
    previousSpending.forEach((category, monthlyTotal) {
      dailyAverages[category] = monthlyTotal / daysInMonth;
    });
    
    return dailyAverages;
  }

  /// Calculate allocation for a specific category using exact last month's spending
  static double _calculateCategoryAllocation(
    String category,
    Map<String, double> dailyAverages,
    double frameworkAllocation,
    int daysInMonth, {
    required bool isNeed,
  }) {
    // Step 1: Get last month's exact daily spend for this category
    final lastMonthDaily = dailyAverages[category] ?? 0.0;
    
    // Step 2: For fixed expenses, use exact amount (no adjustment)
    const fixedCategories = ['Housing & Utilities', 'Insurance', 'Subscription', 'Groceries'];
    if (fixedCategories.contains(category)) {
      return lastMonthDaily; // Return exact daily amount
    }
    
    // Step 3: For flexible categories, check against framework limits
    final lastMonthTotal = lastMonthDaily * daysInMonth;
    
    // Step 4: Get all spending in the same framework category (Needs or Wants)
    final categoryGroup = isNeed ? _getNeedsCategories() : _getWantsCategories();
    final totalGroupSpending = categoryGroup.fold(0.0, (sum, cat) => sum + (dailyAverages[cat] ?? 0.0) * daysInMonth);
    
    // Step 5: Calculate this category's share of the group
    double categoryShare = 0.0;
    if (totalGroupSpending > 0) {
      categoryShare = lastMonthTotal / totalGroupSpending;
    } else if (category == 'Food') {
      categoryShare = 0.50; // Default food to 50% of needs if no data
    } else if (category == 'Transportation') {
      categoryShare = 0.25; // Default transport to 25% of needs if no data
    } else {
      categoryShare = 0.15; // Default others to 15% if no data
    }
    
    // Step 6: Calculate target monthly allocation based on framework
    final targetMonthly = frameworkAllocation * categoryShare;
    
    // Step 7: Compare with last month's spending and trim if overspending
    final adjustedMonthly = lastMonthTotal > targetMonthly ? targetMonthly : lastMonthTotal;
    
    // Step 8: Convert back to daily allowance
    final dailyAllocation = adjustedMonthly / daysInMonth;
    
    // Ensure minimum viable amounts for essential categories
    if (category == 'Food' && dailyAllocation < 100) {
      return 100; // Minimum ₱100/day for food
    } else if (category == 'Transportation' && dailyAllocation < 50) {
      return 50; // Minimum ₱50/day for transport
    }
    
    return dailyAllocation;
  }

  /// Get categories that belong to Needs
  static List<String> _getNeedsCategories() {
    return [
      'Housing & Utilities',
      'Food',
      'Groceries',
      'Transportation',
      'Insurance',
      'Rent/Mortgage',
      'Electric Bill',
      'Water Bill',
      'Internet/WiFi',
      'Phone Bill',
    ];
  }

  /// Get categories that belong to Wants
  static List<String> _getWantsCategories() {
    return [
      'Subscription',
      'Others',
    ];
  }

  /// Get category-specific daily limits
  static Map<String, double> getCategoryDailyLimits(List<DailyAllocation> allocations) {
    final limits = <String, double>{};
    for (final allocation in allocations) {
      limits[allocation.category] = allocation.dailyAmount;
    }
    return limits;
  }

  /// Check if spending in a category is approaching limit
  static bool isCategoryNearLimit(
    String category,
    double spentInCategory,
    Map<String, double> categoryLimits,
    {double threshold = 0.8}
  ) {
    final limit = categoryLimits[category];
    if (limit == null || limit == 0) return false;
    return (spentInCategory / limit) >= threshold;
  }
}

extension TimeOfDayExtension on TimeOfDay {
  String format24Hour() {
    final hour = this.hour.toString().padLeft(2, '0');
    final minute = this.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}