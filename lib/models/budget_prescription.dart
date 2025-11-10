

/// Represents the confidence level of budget prescriptions
enum ConfidenceLevel { high, medium, low }

/// Represents different budgeting frameworks
enum BudgetFramework {
  framework50_30_20, // 50% Needs, 30% Wants, 20% Savings
  framework60_30_10, // 60% Needs, 30% Wants, 10% Savings
  framework60_25_10_5, // 60% Needs, 25% Wants, 10% Savings, 5% Debt
}

/// Represents daily allocation categories
class DailyAllocation {
  final String category;
  final double dailyAmount;
  final String icon;
  final String description;

  const DailyAllocation({
    required this.category,
    required this.dailyAmount,
    required this.icon,
    required this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'dailyAmount': dailyAmount,
      'icon': icon,
      'description': description,
    };
  }

  factory DailyAllocation.fromJson(Map<String, dynamic> json) {
    return DailyAllocation(
      category: json['category'],
      dailyAmount: json['dailyAmount'].toDouble(),
      icon: json['icon'],
      description: json['description'],
    );
  }
}

/// Represents monthly allocation categories
class MonthlyAllocation {
  final String category;
  final double monthlyAmount;
  final String icon;
  final String description;
  final bool isFixed;

  const MonthlyAllocation({
    required this.category,
    required this.monthlyAmount,
    required this.icon,
    required this.description,
    this.isFixed = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'monthlyAmount': monthlyAmount,
      'icon': icon,
      'description': description,
      'isFixed': isFixed,
    };
  }

  factory MonthlyAllocation.fromJson(Map<String, dynamic> json) {
    return MonthlyAllocation(
      category: json['category'],
      monthlyAmount: json['monthlyAmount'].toDouble(),
      icon: json['icon'],
      description: json['description'],
      isFixed: json['isFixed'] ?? true,
    );
  }
}

/// Framework analysis result with percentages
class FrameworkAnalysis {
  final BudgetFramework framework;
  final Map<String, double> percentages;
  final Map<String, double> amounts;
  final double totalNetIncome;
  final String recommendation;

  const FrameworkAnalysis({
    required this.framework,
    required this.percentages,
    required this.amounts,
    required this.totalNetIncome,
    required this.recommendation,
  });

  Map<String, dynamic> toJson() {
    return {
      'framework': framework.toString(),
      'percentages': percentages,
      'amounts': amounts,
      'totalNetIncome': totalNetIncome,
      'recommendation': recommendation,
    };
  }

  factory FrameworkAnalysis.fromJson(Map<String, dynamic> json) {
    return FrameworkAnalysis(
      framework: BudgetFramework.values.firstWhere(
        (e) => e.toString() == json['framework'],
        orElse: () => BudgetFramework.framework50_30_20,
      ),
      percentages: Map<String, double>.from(json['percentages']),
      amounts: Map<String, double>.from(json['amounts']),
      totalNetIncome: json['totalNetIncome'].toDouble(),
      recommendation: json['recommendation'],
    );
  }
}

/// Budgeting tip for budget improvement
class BudgetingTip {
  final String category;
  final String title;
  final String message;
  final String action;
  final String icon;
  final String? strategy; // Optional strategy identifier
  final int? priority;     // Optional priority level (1-5)

  const BudgetingTip({
    required this.category,
    required this.title,
    required this.message,
    required this.action,
    required this.icon,
    this.strategy,
    this.priority,
  });

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'title': title,
      'message': message,
      'action': action,
      'icon': icon,
      'strategy': strategy,
      'priority': priority,
    };
  }

  factory BudgetingTip.fromJson(Map<String, dynamic> json) {
    return BudgetingTip(
      category: json['category'],
      title: json['title'],
      message: json['message'],
      action: json['action'],
      icon: json['icon'],
      strategy: json['strategy'],
      priority: json['priority'],
    );
  }
}

/// Behavior adjustment for daily budget
class BehaviorAdjustment {
  final String type; // 'rollover', 'overspending', 'weekend', 'payday'
  final double adjustment;
  final String reason;
  final DateTime effectiveDate;

  const BehaviorAdjustment({
    required this.type,
    required this.adjustment,
    required this.reason,
    required this.effectiveDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'adjustment': adjustment,
      'reason': reason,
      'effectiveDate': effectiveDate.toIso8601String(),
    };
  }

  factory BehaviorAdjustment.fromJson(Map<String, dynamic> json) {
    return BehaviorAdjustment(
      type: json['type'],
      adjustment: json['adjustment'].toDouble(),
      reason: json['reason'],
      effectiveDate: DateTime.parse(json['effectiveDate']),
    );
  }
}

/// Complete budget prescription containing all analysis and recommendations
class BudgetPrescription {
  final String id;
  final DateTime month;
  final double monthlyNetIncome;
  final ConfidenceLevel confidence;
  final double dataCompleteness; // Percentage 0-100
  
  // Data source information (NEW: Smart data selection)
  final DateTime dataSourceMonth; // Which month's data was actually used
  final String dataSourceReason; // Reason for data selection (carry-forward, most populated, etc.)
  
  // Previous month analysis
  final Map<String, double> previousMonthSpending;
  final int daysFilled;
  final int totalDaysInMonth;
  
  // Framework analysis
  final FrameworkAnalysis recommendedFramework;
  final List<FrameworkAnalysis> alternativeFrameworks;
  
  // Allocations
  final List<DailyAllocation> dailyAllocations;
  final List<MonthlyAllocation> monthlyAllocations;
  
  // Budgeting and adjustments
  final List<BudgetingTip> budgetingTips;
  final List<BehaviorAdjustment> behaviorAdjustments;
  
  // Current spending status
  final Map<String, double> currentMonthSpending;
  final DateTime lastUpdated;

  const BudgetPrescription({
    required this.id,
    required this.month,
    required this.monthlyNetIncome,
    required this.confidence,
    required this.dataCompleteness,
    required this.dataSourceMonth,
    required this.dataSourceReason,
    required this.previousMonthSpending,
    required this.daysFilled,
    required this.totalDaysInMonth,
    required this.recommendedFramework,
    required this.alternativeFrameworks,
    required this.dailyAllocations,
    required this.monthlyAllocations,
    required this.budgetingTips,
    required this.behaviorAdjustments,
    required this.currentMonthSpending,
    required this.lastUpdated,
  });

  /// Calculate total daily budget
  double get totalDailyBudget {
    return dailyAllocations.fold(0.0, (sum, allocation) => sum + allocation.dailyAmount);
  }

  /// Calculate total monthly fixed budget
  double get totalMonthlyBudget {
    return monthlyAllocations.fold(0.0, (sum, allocation) => sum + allocation.monthlyAmount);
  }

  /// Calculate total monthly budget including daily allocations
  double get totalMonthlyBudgetIncludingDaily {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    return totalMonthlyBudget + (totalDailyBudget * daysInMonth);
  }

  /// Check if budget exceeds monthly net income
  bool get exceedsMonthlyNet {
    return totalMonthlyBudgetIncludingDaily > monthlyNetIncome;
  }

  /// Calculate budget utilization percentage
  double get budgetUtilizationPercentage {
    if (monthlyNetIncome <= 0) return 0.0;
    return (totalMonthlyBudgetIncludingDaily / monthlyNetIncome) * 100;
  }

  /// Get remaining budget after all allocations
  double get remainingBudget {
    return monthlyNetIncome - totalMonthlyBudgetIncludingDaily;
  }

  /// Get remaining flexible budget for the day
  double getRemainingDailyBudget(DateTime date) {
    // This would be calculated based on current day's spending
    // Implementation depends on transaction tracking
    return totalDailyBudget;
  }

  /// Check if spending is on track for the month
  bool get isOnTrack {
    final now = DateTime.now();
    final daysIntoMonth = now.day;
    
    final expectedSpending = (totalDailyBudget * daysIntoMonth) + totalMonthlyBudget;
    final actualSpending = currentMonthSpending.values.fold(0.0, (sum, amount) => sum + amount);
    
    return actualSpending <= expectedSpending * 1.1; // 10% tolerance
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'month': month.toIso8601String(),
      'monthlyNetIncome': monthlyNetIncome,
      'confidence': confidence.toString(),
      'dataCompleteness': dataCompleteness,
      'dataSourceMonth': dataSourceMonth.toIso8601String(),
      'dataSourceReason': dataSourceReason,
      'previousMonthSpending': previousMonthSpending,
      'daysFilled': daysFilled,
      'totalDaysInMonth': totalDaysInMonth,
      'recommendedFramework': recommendedFramework.toJson(),
      'alternativeFrameworks': alternativeFrameworks.map((f) => f.toJson()).toList(),
      'dailyAllocations': dailyAllocations.map((d) => d.toJson()).toList(),
      'monthlyAllocations': monthlyAllocations.map((m) => m.toJson()).toList(),
      'budgetingTips': budgetingTips.map((c) => c.toJson()).toList(),
      'behaviorAdjustments': behaviorAdjustments.map((b) => b.toJson()).toList(),
      'currentMonthSpending': currentMonthSpending,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory BudgetPrescription.fromJson(Map<String, dynamic> json) {
    return BudgetPrescription(
      id: json['id'],
      month: DateTime.parse(json['month']),
      monthlyNetIncome: json['monthlyNetIncome'].toDouble(),
      confidence: ConfidenceLevel.values.firstWhere(
        (e) => e.toString() == json['confidence'],
        orElse: () => ConfidenceLevel.low,
      ),
      dataCompleteness: json['dataCompleteness'].toDouble(),
      dataSourceMonth: DateTime.parse(json['dataSourceMonth'] ?? json['month']), // Fallback for old data
      dataSourceReason: json['dataSourceReason'] ?? 'Legacy data (previous month)',
      previousMonthSpending: Map<String, double>.from(json['previousMonthSpending']),
      daysFilled: json['daysFilled'],
      totalDaysInMonth: json['totalDaysInMonth'],
      recommendedFramework: FrameworkAnalysis.fromJson(json['recommendedFramework']),
      alternativeFrameworks: (json['alternativeFrameworks'] as List)
          .map((f) => FrameworkAnalysis.fromJson(f))
          .toList(),
      dailyAllocations: (json['dailyAllocations'] as List)
          .map((d) => DailyAllocation.fromJson(d))
          .toList(),
      monthlyAllocations: (json['monthlyAllocations'] as List)
          .map((m) => MonthlyAllocation.fromJson(m))
          .toList(),
      budgetingTips: (json['budgetingTips'] as List)
          .map((c) => BudgetingTip.fromJson(c))
          .toList(),
      behaviorAdjustments: (json['behaviorAdjustments'] as List)
          .map((b) => BehaviorAdjustment.fromJson(b))
          .toList(),
      currentMonthSpending: Map<String, double>.from(json['currentMonthSpending']),
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }

  BudgetPrescription copyWith({
    String? id,
    DateTime? month,
    double? monthlyNetIncome,
    ConfidenceLevel? confidence,
    double? dataCompleteness,
    DateTime? dataSourceMonth,
    String? dataSourceReason,
    Map<String, double>? previousMonthSpending,
    int? daysFilled,
    int? totalDaysInMonth,
    FrameworkAnalysis? recommendedFramework,
    List<FrameworkAnalysis>? alternativeFrameworks,
    List<DailyAllocation>? dailyAllocations,
    List<MonthlyAllocation>? monthlyAllocations,
    List<BudgetingTip>? budgetingTips,
    List<BehaviorAdjustment>? behaviorAdjustments,
    Map<String, double>? currentMonthSpending,
    DateTime? lastUpdated,
  }) {
    return BudgetPrescription(
      id: id ?? this.id,
      month: month ?? this.month,
      monthlyNetIncome: monthlyNetIncome ?? this.monthlyNetIncome,
      confidence: confidence ?? this.confidence,
      dataCompleteness: dataCompleteness ?? this.dataCompleteness,
      dataSourceMonth: dataSourceMonth ?? this.dataSourceMonth,
      dataSourceReason: dataSourceReason ?? this.dataSourceReason,
      previousMonthSpending: previousMonthSpending ?? this.previousMonthSpending,
      daysFilled: daysFilled ?? this.daysFilled,
      totalDaysInMonth: totalDaysInMonth ?? this.totalDaysInMonth,
      recommendedFramework: recommendedFramework ?? this.recommendedFramework,
      alternativeFrameworks: alternativeFrameworks ?? this.alternativeFrameworks,
      dailyAllocations: dailyAllocations ?? this.dailyAllocations,
      monthlyAllocations: monthlyAllocations ?? this.monthlyAllocations,
      budgetingTips: budgetingTips ?? this.budgetingTips,
      behaviorAdjustments: behaviorAdjustments ?? this.behaviorAdjustments,
      currentMonthSpending: currentMonthSpending ?? this.currentMonthSpending,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}