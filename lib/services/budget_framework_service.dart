import '../models/budget_prescription.dart';
import 'package:intl/intl.dart';
import '../models/user.dart' as user_models;
import '../widgets/timeframe_filter.dart';
import 'budget_strategy_tips_service.dart';
import 'category_analyzer.dart';

/// Result of category-based budget analysis
class CategoryBasedBudgetAnalysis {
  final double netIncome;
  final FixedNeedsBreakdown fixedNeeds;
  final FlexibleNeedsBreakdown flexibleNeeds;
  final double projectedBudget;
  final double remainingBudget;
  final bool isSustainable;
  final List<String> warnings;
  final List<String> adjustments;

  const CategoryBasedBudgetAnalysis({
    required this.netIncome,
    required this.fixedNeeds,
    required this.flexibleNeeds,
    required this.projectedBudget,
    required this.remainingBudget,
    required this.isSustainable,
    required this.warnings,
    required this.adjustments,
  });
}

/// Breakdown of fixed needs expenses
class FixedNeedsBreakdown {
  final double housingAndUtilities;
  final double debt;
  final double groceries;
  final double healthAndPersonalCare;
  final double education;
  final double childcare;

  double get total => housingAndUtilities + debt + groceries + healthAndPersonalCare + education + childcare;

  const FixedNeedsBreakdown({
    required this.housingAndUtilities,
    required this.debt,
    required this.groceries,
    required this.healthAndPersonalCare,
    required this.education,
    required this.childcare,
  });
}

/// Breakdown of flexible needs expenses
class FlexibleNeedsBreakdown {
  final double food;
  final double transport;

  double get total => food + transport;

  FlexibleNeedsBreakdown({
    required this.food,
    required this.transport,
  });
}

/// Validation result against net income
class BudgetValidationResult {
  final FlexibleNeedsBreakdown adjustedFlexibleNeeds;
  final double adjustedProjectedBudget;
  final double remainingBudget;
  final bool isSustainable;
  final List<String> adjustments;

  const BudgetValidationResult({
    required this.adjustedFlexibleNeeds,
    required this.adjustedProjectedBudget,
    required this.remainingBudget,
    required this.isSustainable,
    required this.adjustments,
  });
}

/// Service for analyzing and calculating budget frameworks
class BudgetFrameworkService {

// BUDGET COMPUTATION START: Main budget calculation method - computes personalized budget from spending data
/// Calculate category-based budget prescription with fixed/flexible needs and wants exclusion
static Future<CategoryBasedBudgetAnalysis> calculateCategoryBasedBudget(
  double netIncome,
  Map<String, double> previousSpending,
  int loggedDays,
  int daysInCurrentMonth,
  DateTime baseMonth,
) async {
  // Validate inputs
  if (netIncome <= 0) {
    throw ArgumentError('Net income must be positive');
  }
  if (loggedDays <= 0) {
    throw ArgumentError('Logged days must be positive');
  }

  // Apply category preservation rules
  final preservedCategories = await CategoryAnalyzer.getPreservedCategories(
    baseMonth,
    previousSpending,
  );

  // BUDGET COMPUTATION STEP 1: Calculate Fixed Needs (exact amounts if logged)
  final fixedNeeds = _calculateFixedNeeds(preservedCategories);

  // BUDGET COMPUTATION STEP 2: Calculate Flexible Needs (averaged and constrained)
  final flexibleNeeds = _calculateFlexibleNeeds(
    preservedCategories,
    loggedDays,
    daysInCurrentMonth,
  );

  // BUDGET COMPUTATION STEP 3: Calculate Projected Budget
  final projectedBudget = fixedNeeds.total + flexibleNeeds.total;

  // BUDGET COMPUTATION STEP 4: Validate against Net Income and apply adjustments
  final validation = _validateAgainstNetIncome(
    fixedNeeds.total,
    flexibleNeeds,
    projectedBudget,
    netIncome,
  );

  // Generate warnings based on validation
  final warnings = _generateBudgetWarnings(validation, netIncome);

  return CategoryBasedBudgetAnalysis(
    netIncome: netIncome,
    fixedNeeds: fixedNeeds,
    flexibleNeeds: validation.adjustedFlexibleNeeds,
    projectedBudget: validation.adjustedProjectedBudget,
    remainingBudget: validation.remainingBudget,
    isSustainable: validation.isSustainable,
    warnings: warnings,
    adjustments: validation.adjustments,
  );
}
// BUDGET COMPUTATION END: Main budget calculation method

// BUDGET COMPUTATION SUB-METHOD: Fixed Needs Calculation - extracts exact fixed expenses from spending data
/// Calculate Fixed Needs (exact logged amounts)
static FixedNeedsBreakdown _calculateFixedNeeds(Map<String, double> spending) {
  return FixedNeedsBreakdown(
    housingAndUtilities: spending['Housing and Utilities'] ?? spending['Housing & Utilities'] ?? 0.0,
    debt: spending['Debt'] ?? spending['Debt/Loans'] ?? spending['Loan Payment'] ?? 0.0,
    groceries: spending['Groceries'] ?? 0.0,
    healthAndPersonalCare: spending['Health and Personal Care'] ?? 0.0,
    education: spending['Education'] ?? 0.0,
    childcare: spending['Childcare'] ?? 0.0,
  );
}

// BUDGET COMPUTATION SUB-METHOD: Flexible Needs Calculation - computes food and transport budgets with averaging and minimum constraints
/// Calculate Flexible Needs (averaged and constrained)
static FlexibleNeedsBreakdown _calculateFlexibleNeeds(
  Map<String, double> spending,
  int loggedDays,
  int daysInCurrentMonth,
) {
  // Food calculation: (Food total logged ÷ Logged days) × Days in current month
  final loggedFoodTotal = spending['Food'] ?? 0.0;
  final foodDailyAverage = loggedDays > 0 ? loggedFoodTotal / loggedDays : 0.0;
  final foodMonthly = foodDailyAverage * daysInCurrentMonth;

  // Constraint: Food must be at least 100 × Days in current month
  final foodMinimum = 100.0 * daysInCurrentMonth;
  final food = foodMonthly > 0 ? foodMonthly : foodMinimum;

  // Transport calculation: (Transport total logged ÷ Logged days) × Days in current month
  final loggedTransportTotal = spending['Transportation'] ?? spending['Transport'] ?? 0.0;
  final transportDailyAverage = loggedDays > 0 ? loggedTransportTotal / loggedDays : 0.0;
  final transportMonthly = transportDailyAverage * daysInCurrentMonth;

  // Constraint: Transport must be at least 50 × Days in current month
  final transportMinimum = 50.0 * daysInCurrentMonth;
  final transport = transportMonthly > 0 ? transportMonthly : transportMinimum;

  return FlexibleNeedsBreakdown(
    food: food,
    transport: transport,
  );
}

// DECISION TREE START: Budget Validation Logic - Evaluates budget sustainability against net income with Cases A, B, C
/// Validate against Net Income and apply adjustments (Cases A, B, C)
static BudgetValidationResult _validateAgainstNetIncome(
  double fixedTotal,
  FlexibleNeedsBreakdown flexibleNeeds,
  double projectedBudget,
  double netIncome,
) {
  final adjustments = <String>[];

  // Case A: Fixed > Net Income
  if (fixedTotal > netIncome) {
    // Set flexible categories to minimums
    const foodMin = 100.0 * 30; // Assuming 30 days for minimum calculation
    const transportMin = 50.0 * 30;
    final minimumsTotal = fixedTotal + foodMin + transportMin;

    final adjustedFlexible = FlexibleNeedsBreakdown(
      food: foodMin,
      transport: transportMin,
    );

    final isSustainable = minimumsTotal <= netIncome;
    final adjustedProjectedBudget = fixedTotal + foodMin + transportMin;
    final remainingBudget = netIncome - adjustedProjectedBudget;

    if (!isSustainable) {
      adjustments.add('Budget unsustainable: Even minimum flexible expenses exceed net income');
    } else {
      adjustments.add('Fixed expenses exceed net income - reduced flexible categories to minimums');
    }

    return BudgetValidationResult(
      adjustedFlexibleNeeds: adjustedFlexible,
      adjustedProjectedBudget: adjustedProjectedBudget,
      remainingBudget: remainingBudget,
      isSustainable: isSustainable,
      adjustments: adjustments,
    );
  }

  // Case B: Fixed ≤ Net Income but Fixed + Flexible > Net Income
  if (projectedBudget > netIncome) {
    // Apply proportional scaling
    final availableForFlexible = netIncome - fixedTotal;
    final scaleFactor = availableForFlexible / flexibleNeeds.total;

    const foodMin = 100.0 * 30; // Assuming 30 days
    const transportMin = 50.0 * 30;

    final scaledFood = flexibleNeeds.food * scaleFactor;
    final scaledTransport = flexibleNeeds.transport * scaleFactor;

    final adjustedFood = scaledFood > foodMin ? scaledFood : foodMin;
    final adjustedTransport = scaledTransport > transportMin ? scaledTransport : transportMin;

    final adjustedFlexible = FlexibleNeedsBreakdown(
      food: adjustedFood,
      transport: adjustedTransport,
    );

    final adjustedProjectedBudget = fixedTotal + adjustedFood + adjustedTransport;
    final isSustainable = adjustedProjectedBudget <= netIncome;
    final remainingBudget = netIncome - adjustedProjectedBudget;

    adjustments.add('Applied proportional scaling to fit within net income');

    return BudgetValidationResult(
      adjustedFlexibleNeeds: adjustedFlexible,
      adjustedProjectedBudget: adjustedProjectedBudget,
      remainingBudget: remainingBudget,
      isSustainable: isSustainable,
      adjustments: adjustments,
    );
  }

  // Case C: Fixed + minimum(Food, Transport) > Net Income
  const foodMin = 100.0 * 30;
  const transportMin = 50.0 * 30;
  final minimumsTotal = fixedTotal + foodMin + transportMin;

  if (minimumsTotal > netIncome) {
    adjustments.add('Budget unsustainable: Fixed expenses + minimum flexible expenses exceed net income');

    return BudgetValidationResult(
      adjustedFlexibleNeeds: FlexibleNeedsBreakdown(food: foodMin, transport: transportMin),
      adjustedProjectedBudget: minimumsTotal,
      remainingBudget: netIncome - minimumsTotal,
      isSustainable: false,
      adjustments: adjustments,
    );
  }

  // Budget is acceptable
  final remainingBudget = netIncome - projectedBudget;
  return BudgetValidationResult(
    adjustedFlexibleNeeds: flexibleNeeds,
    adjustedProjectedBudget: projectedBudget,
    remainingBudget: remainingBudget,
    isSustainable: true,
    adjustments: adjustments,
  );
}
// DECISION TREE END: Budget Validation Logic

/// Generate budget warnings based on validation
static List<String> _generateBudgetWarnings(BudgetValidationResult validation, double netIncome) {
  final warnings = <String>[];

  if (validation.adjustedProjectedBudget > netIncome) {
    warnings.add('Expenses exceed income');
  }

  if (validation.adjustments.isNotEmpty) {
    warnings.add('Flexible categories adjusted to fit net income');
  }

  if (!validation.isSustainable) {
    warnings.add('Budget unsustainable');
  }

  return warnings;
}

/// Calculate framework allocations based on net income
static FrameworkAnalysis calculate50_30_20Framework(double netIncome, Map<String, double> previousSpending) {
    // Validate net income
    if (netIncome <= 0) {
      throw ArgumentError('Net income must be positive');
    }

    final needs = netIncome * 0.50;
    final wants = netIncome * 0.30;
    final savings = netIncome * 0.20;

    final percentages = {
      'Needs': 50.0,
      'Wants': 30.0,
      'Savings': 20.0,
    };

    final amounts = {
      'Needs': needs,
      'Wants': wants,
      'Savings': savings,
    };

    // Validate total doesn't exceed net income
    _validateBudgetTotal(amounts, netIncome);

    final recommendation = _generateFrameworkRecommendation(
      BudgetFramework.framework50_30_20,
      previousSpending,
      amounts,
      netIncome,
    );

    return FrameworkAnalysis(
      framework: BudgetFramework.framework50_30_20,
      percentages: percentages,
      amounts: amounts,
      totalNetIncome: netIncome,
      recommendation: recommendation,
    );
  }

  static FrameworkAnalysis calculate60_30_10Framework(double netIncome, Map<String, double> previousSpending) {
    // Validate net income
    if (netIncome <= 0) {
      throw ArgumentError('Net income must be positive');
    }

    final needs = netIncome * 0.60;
    final wants = netIncome * 0.30;
    final savings = netIncome * 0.10;

    final percentages = {
      'Needs': 60.0,
      'Wants': 30.0,
      'Savings': 10.0,
    };

    final amounts = {
      'Needs': needs,
      'Wants': wants,
      'Savings': savings,
    };

    // Validate total doesn't exceed net income
    _validateBudgetTotal(amounts, netIncome);

    final recommendation = _generateFrameworkRecommendation(
      BudgetFramework.framework60_30_10,
      previousSpending,
      amounts,
      netIncome,
    );

    return FrameworkAnalysis(
      framework: BudgetFramework.framework60_30_10,
      percentages: percentages,
      amounts: amounts,
      totalNetIncome: netIncome,
      recommendation: recommendation,
    );
  }

  static FrameworkAnalysis calculate60_25_10_5Framework(double netIncome, Map<String, double> previousSpending) {
    // Validate net income
    if (netIncome <= 0) {
      throw ArgumentError('Net income must be positive');
    }

    final needs = netIncome * 0.60;
    final wants = netIncome * 0.25;
    final savings = netIncome * 0.10;
    final debt = netIncome * 0.05;

    final percentages = {
      'Needs': 60.0,
      'Wants': 25.0,
      'Savings': 10.0,
      'Debt': 5.0,
    };

    final amounts = {
      'Needs': needs,
      'Wants': wants,
      'Savings': savings,
      'Debt': debt,
    };

    // Validate total doesn't exceed net income
    _validateBudgetTotal(amounts, netIncome);

    final recommendation = _generateFrameworkRecommendation(
      BudgetFramework.framework60_25_10_5,
      previousSpending,
      amounts,
      netIncome,
    );

    return FrameworkAnalysis(
      framework: BudgetFramework.framework60_25_10_5,
      percentages: percentages,
      amounts: amounts,
      totalNetIncome: netIncome,
      recommendation: recommendation,
    );
  }

  // DECISION TREE START: Framework Selection Logic - Selects budget frameworks based on user characteristics using strategy-based approach
  /// Analyze all frameworks and recommend the best one
  static FrameworkAnalysis getBestFramework(
    double netIncome,
    Map<String, double> previousSpending, {
    List<String>? userDebtStatuses,
  }) {
    // Only use strategy-based approach now
    // Map strategy-based frameworks to existing budget framework values
    final strategy = BudgetStrategyTipsService.determineBudgetStrategy(_createDummyUser(userDebtStatuses));
    
    switch (strategy) {
      case BudgetStrategy.debtHeavyRecovery:
        return calculate60_25_10_5Framework(netIncome, previousSpending);
      case BudgetStrategy.familyCentric:
        // Map to 60/30/10 framework as closest match
        return calculate60_30_10Framework(netIncome, previousSpending);
      case BudgetStrategy.riskControl:
        // Map to 50/30/20 framework as balanced approach
        return calculate50_30_20Framework(netIncome, previousSpending);
      case BudgetStrategy.balanced:
        return calculate50_30_20Framework(netIncome, previousSpending);
      case BudgetStrategy.builder:
        // Map to 60/30/10 framework for growth focus
        return calculate60_30_10Framework(netIncome, previousSpending);
      case BudgetStrategy.conservative:
        // Map to 60/25/10/5 framework for conservative debt approach
        return calculate60_25_10_5Framework(netIncome, previousSpending);
    }
  }
  // DECISION TREE END: Framework Selection Logic

  /// Create a dummy user for strategy determination
  static user_models.User _createDummyUser(List<String>? debtStatuses) {
    return user_models.User(
      id: '',
      email: '',
      name: '',
      password: '',
      monthlyIncome: 0.0,
      createdAt: DateTime.now(),
      debtStatuses: debtStatuses?.map((status) => user_models.DebtStatus.values.firstWhere(
        (e) => e.toString().split('.').last == status.split('.').last,
        orElse: () => user_models.DebtStatus.noDebt,
      )).toList() ?? [user_models.DebtStatus.noDebt],
    );
  }

  /// Validate that total budget allocation doesn't exceed net income
  static void _validateBudgetTotal(Map<String, double> amounts, double netIncome) {
    final total = amounts.values.fold(0.0, (sum, amount) => sum + amount);
    if (total > netIncome) {
      throw ArgumentError('Total budget allocation (₱${total.toStringAsFixed(2)}) exceeds net income (₱${netIncome.toStringAsFixed(2)})');
    }
  }

  /// Generate recommendation text for a framework
  static String _generateFrameworkRecommendation(
    BudgetFramework framework,
    Map<String, double> previousSpending,
    Map<String, double> amounts,
    double netIncome,
  ) {
    final previousNeeds = _calculateNeedsSpending(previousSpending);
    final previousWants = _calculateWantsSpending(previousSpending);
    final previousSavings = previousSpending['Savings'] ?? 0.0;

    final needsAllocation = amounts['Needs']!;
    final wantsAllocation = amounts['Wants']!;
    final savingsAllocation = amounts['Savings']!;

    final recommendations = <String>[];

    // Analyze needs
    if (previousNeeds > needsAllocation) {
      recommendations.add("Your essential expenses exceed the ${framework.name.split('_').last} framework's needs allocation. Consider the 60/30/10 framework for higher needs coverage.");
    } else if (previousNeeds < needsAllocation * 0.8) {
      recommendations.add("You have room to optimize your essential spending or redirect funds to savings and wants.");
    }

    // Analyze wants
    if (previousWants > wantsAllocation) {
      recommendations.add("Consider reducing discretionary spending on entertainment, dining out, or subscriptions to fit within your wants budget.");
    } else {
      recommendations.add("Your wants spending is well-controlled. Great job maintaining discipline!");
    }

    // Analyze savings
    if (previousSavings < savingsAllocation) {
      recommendations.add("Increase your savings rate to build financial security. Consider automating transfers to reach your ${(savingsAllocation / netIncome * 100).toStringAsFixed(0)}% savings goal.");
    } else {
      recommendations.add("Excellent savings discipline! You're on track for financial independence.");
    }

    // Framework-specific advice
    switch (framework) {
      case BudgetFramework.framework50_30_20:
        recommendations.add("This balanced approach prioritizes both present enjoyment and future security.");
        break;
      case BudgetFramework.framework60_30_10:
        recommendations.add("This framework provides more flexibility for essential expenses while maintaining reasonable savings.");
        break;
      case BudgetFramework.framework60_25_10_5:
        recommendations.add("This framework includes dedicated debt repayment to accelerate financial freedom.");
        break;
    }

    return recommendations.join(' ');
  }

  /// Calculate spending on needs categories
  static double _calculateNeedsSpending(Map<String, double> spending) {
    const needsCategories = [
      'Housing & Utilities',
      'Groceries',
      'Transportation',
      'Insurance',
      'Rent/Mortgage',
      'Electric Bill',
      'Water Bill',
      'Internet/WiFi',
      'Phone Bill',
    ];

    return needsCategories.fold(0.0, (sum, category) => sum + (spending[category] ?? 0.0));
  }

  /// Calculate spending on wants categories
  static double _calculateWantsSpending(Map<String, double> spending) {
    const wantsCategories = [
      'Food',
      'Subscription',
      'Others',
    ];

    return wantsCategories.fold(0.0, (sum, category) => sum + (spending[category] ?? 0.0));
  }

  /// Get budgeting tips for a specific framework using strategy-based approach
  static List<BudgetingTip> generateBudgetingTips(
    FrameworkAnalysis framework,
    Map<String, double> previousSpending,
    Map<String, double> currentSpending, {
    List<DailyAllocation>? dailyAllocations,
    List<MonthlyAllocation>? monthlyAllocations,
    DateTime? currentMonth,
    user_models.User? user,
  }) {
    return generateComprehensiveBudgetingTips(
      framework,
      previousSpending,
      currentSpending,
      dailyAllocations: dailyAllocations,
      monthlyAllocations: monthlyAllocations,
      currentMonth: currentMonth,
      user: user,
    );
  }

  /// Generate comprehensive budgeting tips using only strategy-based approach
  static List<BudgetingTip> generateComprehensiveBudgetingTips(
    FrameworkAnalysis framework,
    Map<String, double> previousSpending,
    Map<String, double> currentSpending, {
    List<DailyAllocation>? dailyAllocations,
    List<MonthlyAllocation>? monthlyAllocations,
    DateTime? currentMonth,
    user_models.User? user,
  }) {
    final tips = <BudgetingTip>[];
    
    // Generate strategy-based tips if user data is available
    if (user != null) {
      final strategy = BudgetStrategyTipsService.determineBudgetStrategy(user);
      final strategyTips = BudgetStrategyTipsService.generateStrategyTips(user, strategy);
      
      // Convert strategy tips to regular budgeting tips and add to list
      tips.addAll(strategyTips.map((tip) => tip.toBudgetingTip()));
    }
    
    // Limit to top 5 tips to avoid overwhelming the user
    return tips.take(5).toList();
  }

  // Spending pattern-based tip generation has been removed
  // Only strategy-based tips are now used

  /// Generate context-aware budgeting tips based on date filters and spending data
  static List<BudgetingTip> generateDateFilteredBudgetingTips({
    required TimeFrame timeFrame,
    required DateTime selectedDate,
    required Map<String, double> categoryTotals,
    required double periodExpenses,
    BudgetPrescription? budgetPrescription,
    user_models.User? user,
  }) {
    final tips = <BudgetingTip>[];
    final now = DateTime.now();
    final isToday = timeFrame == TimeFrame.daily && 
                   selectedDate.year == now.year && 
                   selectedDate.month == now.month && 
                   selectedDate.day == now.day;
    
    // Strategy-based tips take priority (show for monthly view or when viewing current month)
    final isCurrentMonth = timeFrame == TimeFrame.monthly &&
                          selectedDate.year == now.year &&
                          selectedDate.month == now.month;
    
    if ((isCurrentMonth || isToday) && budgetPrescription != null && budgetPrescription.budgetingTips.isNotEmpty) {
      // Include up to 3 strategy-based tips from the prescription
      tips.addAll(budgetPrescription.budgetingTips.take(3));
    }
    
    // Add highly personalized tips based on user profile with diversity
    if (user != null) {
      tips.addAll(_generateDiverseBudgetingTips(user, timeFrame, selectedDate, categoryTotals, periodExpenses, budgetPrescription));
    }
    
    // Check if there's no spending for the selected period
    final hasSpending = periodExpenses > 0;
    
    if (!hasSpending) {
      // Always show coaching tips when no transactions are available
      final coachingTips = _generateCoachingTips(timeFrame, selectedDate, budgetPrescription, user);
      tips.addAll(coachingTips);
      return tips.take(3).toList(); // Limit to exactly 3 tips for new users or no-spending periods
    }

    // Get actual budgets if available
    final dailyBudget = budgetPrescription?.totalDailyBudget ?? 0.0;
    final actualDailyBudgets = <String, double>{};
    final actualMonthlyBudgets = <String, double>{};
    
    if (budgetPrescription != null) {
      for (final allocation in budgetPrescription.dailyAllocations) {
        actualDailyBudgets[allocation.category] = allocation.dailyAmount;
      }
      for (final allocation in budgetPrescription.monthlyAllocations) {
        actualMonthlyBudgets[allocation.category] = allocation.monthlyAmount;
      }
    }

    // Generate contextual tips based on timeframe
    switch (timeFrame) {
      case TimeFrame.daily:
        tips.addAll(_generateDailyTips(
          selectedDate, categoryTotals, dailyBudget, actualDailyBudgets, isToday, budgetPrescription
        ));
        break;
      case TimeFrame.weekly:
        tips.addAll(_generateWeeklyTips(
          selectedDate, categoryTotals, dailyBudget, actualDailyBudgets, budgetPrescription
        ));
        break;
      case TimeFrame.monthly:
        tips.addAll(_generateMonthlyTips(
          selectedDate, categoryTotals, actualMonthlyBudgets, budgetPrescription
        ));
        break;
    }

    // Limit to 5 tips total with priority and diversity
    return _selectDiverseTips(tips, 5);
  }

  /// Select diverse tips from the collection ensuring variety across categories
  static List<BudgetingTip> _selectDiverseTips(List<BudgetingTip> allTips, int maxTips) {
    if (allTips.length <= maxTips) {
      return allTips;
    }
    
    // Group tips by category to ensure diversity
    final categoryGroups = <String, List<BudgetingTip>>{};
    for (final tip in allTips) {
      categoryGroups.putIfAbsent(tip.category, () => []).add(tip);
    }
    
    final selectedTips = <BudgetingTip>[];
    final usedCategories = <String>{};
    
    // First pass: Select one tip from each unique category
    for (final tip in allTips) {
      if (!usedCategories.contains(tip.category) && selectedTips.length < maxTips) {
        selectedTips.add(tip);
        usedCategories.add(tip.category);
      }
    }
    
    // Second pass: Fill remaining slots with best remaining tips
    for (final tip in allTips) {
      if (!selectedTips.contains(tip) && selectedTips.length < maxTips) {
        selectedTips.add(tip);
      }
    }
    
    return selectedTips.take(maxTips).toList();
  }

  /// Generate coaching tips for how to spend wisely (when no transactions are available)
  static List<BudgetingTip> _generateCoachingTips(
    TimeFrame timeFrame,
    DateTime selectedDate,
    BudgetPrescription? budgetPrescription,
    user_models.User? user,
  ) {
    final now = DateTime.now();
    final isToday = timeFrame == TimeFrame.daily &&
                   selectedDate.year == now.year &&
                   selectedDate.month == now.month &&
                   selectedDate.day == now.day;

    // Comprehensive coaching tips focusing on HOW to spend well
    final allCoachingTips = [
      // Smart Spending Category
      const BudgetingTip(
        category: 'Smart Spending',
        title: 'The 24-Hour Rule',
        message: 'Before buying anything over ₱1,000, wait 24 hours to decide if you really need it.',
        action: 'This simple pause prevents impulse purchases and helps you make better money decisions.',
        icon: '⏰',
      ),
      const BudgetingTip(
        category: 'Smart Spending',
        title: 'Quality Over Quantity',
        message: 'Buying fewer, higher-quality items often saves money in the long run.',
        action: 'When shopping, ask: "Will this last?" and "Do I really need this?"',
        icon: '⭐',
      ),
      const BudgetingTip(
        category: 'Smart Spending',
        title: 'Understand Wants vs Needs',
        message: 'Learning to distinguish between wants and needs is key to smart spending.',
        action: 'Before each purchase, ask: "Is this a want or a need?" and spend accordingly.',
        icon: '🤔',
      ),
      
      // Budget Planning Category
      const BudgetingTip(
        category: 'Budget Planning',
        title: 'Plan Your Week\'s Expenses',
        message: 'Planning ahead helps you spend intentionally rather than impulsively.',
        action: 'List your expected expenses for the week and allocate money for each category.',
        icon: '📅',
      ),
      const BudgetingTip(
        category: 'Budget Planning',
        title: 'Create Monthly Budget Reviews',
        message: 'Regular budget check-ins help you stay on track and adjust as needed.',
        action: 'Set a monthly date to review your budget performance and plan improvements.',
        icon: '📊',
      ),
      
      // Money Tracking Category
      const BudgetingTip(
        category: 'Money Tracking',
        title: 'Track Every Peso',
        message: 'Small expenses add up quickly - ₱50 daily coffee becomes ₱1,500 monthly.',
        action: 'Record every purchase, no matter how small, to build awareness of your spending habits.',
        icon: '📝',
      ),
      const BudgetingTip(
        category: 'Money Tracking',
        title: 'Use Receipt Photos',
        message: 'Taking photos of receipts makes expense tracking easier and more accurate.',
        action: 'Snap a photo of every receipt and categorize expenses weekly.',
        icon: '📸',
      ),
      
      // Savings Strategy Category
      const BudgetingTip(
        category: 'Savings Strategy',
        title: 'Pay Yourself First',
        message: 'Save money before spending on anything else to ensure you meet your financial goals.',
        action: 'When you receive income, immediately set aside your savings before other expenses.',
        icon: '💰',
      ),
      const BudgetingTip(
        category: 'Savings Strategy',
        title: 'Automate Your Savings',
        message: 'Automatic transfers make saving effortless and consistent.',
        action: 'Set up automatic transfers to savings on payday so you save without thinking.',
        icon: '🔄',
      ),
      
      // Smart Shopping Category
      const BudgetingTip(
        category: 'Smart Shopping',
        title: 'Compare Prices Before Buying',
        message: 'Spending 10 minutes comparing prices can save you hundreds of pesos.',
        action: 'Check at least 3 stores or websites before making purchases over ₱500.',
        icon: '🔍',
      ),
      const BudgetingTip(
        category: 'Smart Shopping',
        title: 'Use Shopping Lists',
        message: 'Shopping lists prevent impulse purchases and help you stay focused.',
        action: 'Always shop with a list and stick to it - avoid browsing without purpose.',
        icon: '📋',
      ),
      
      // Emergency Preparedness Category
      const BudgetingTip(
        category: 'Emergency Preparedness',
        title: 'Build Your Emergency Fund',
        message: 'An emergency fund prevents you from going into debt when unexpected expenses arise.',
        action: 'Start by saving ₱500 monthly until you have 3 months of expenses saved.',
        icon: '🛡',
      ),
      
      // Daily Habits Category
      const BudgetingTip(
        category: 'Daily Habits',
        title: 'Review Daily Budget Each Morning',
        message: 'Starting your day with budget awareness helps you make better spending choices.',
        action: 'Check your budget and planned expenses each morning before leaving home.',
        icon: '🌅',
      ),
      const BudgetingTip(
        category: 'Daily Habits',
        title: 'End-of-Day Money Review',
        message: 'Reflecting on daily spending helps you learn and improve your money habits.',
        action: 'Spend 5 minutes each evening reviewing what you bought and why.',
        icon: '🌙',
      ),
      
      // Money Management Category
      const BudgetingTip(
        category: 'Money Management',
        title: 'Use the Envelope Method',
        message: 'Physical cash for each budget category makes spending limits more real and tangible.',
        action: 'Try using cash envelopes for food and transportation to control these daily expenses.',
        icon: '💵',
      ),
      const BudgetingTip(
        category: 'Money Management',
        title: 'Separate Accounts Strategy',
        message: 'Different accounts for different purposes help you manage money more effectively.',
        action: 'Use separate accounts for bills, savings, and spending money to avoid confusion.',
        icon: '🏦',
      ),
      
      // Financial Goals Category
      const BudgetingTip(
        category: 'Financial Goals',
        title: 'Set Clear Money Goals',
        message: 'Having specific financial goals makes it easier to say no to unnecessary purchases.',
        action: 'Write down 3 financial goals and the target dates for achieving them.',
        icon: '🎯',
      ),
      const BudgetingTip(
        category: 'Financial Goals',
        title: 'Visualize Your Financial Future',
        message: 'Clear vision of your financial future motivates better daily money decisions.',
        action: 'Create a vision board or write a detailed description of your ideal financial life.',
        icon: '🔮',
      ),
    ];
    
    // Add user-specific coaching based on their profile
    if (user != null) {
      final userSpecificTips = _generateUserSpecificCoachingTips(user, budgetPrescription);
      allCoachingTips.addAll(userSpecificTips);
    }
    
    // Add time-specific coaching tips
    if (isToday && budgetPrescription != null) {
      final dailyBudget = budgetPrescription.totalDailyBudget;
      allCoachingTips.add(BudgetingTip(
        category: 'Today\'s Budget',
        title: 'Your Daily Budget: ₱${dailyBudget.toStringAsFixed(0)}',
        message: 'You have ₱${dailyBudget.toStringAsFixed(0)} allocated for today\'s expenses.',
        action: 'Prioritize essential expenses like food and transportation, and track every purchase.',
        icon: '💰',
      ));
    }
    
    // Shuffle and select 3 diverse tips to ensure variety
    allCoachingTips.shuffle();
    
    // Ensure we have tips from different categories and content types
    final selectedTips = <BudgetingTip>[];
    final usedCategories = <String>{};
    final usedTitles = <String>{};
    
    // Define primary category groups to ensure maximum diversity
    const categoryGroups = {
      'spending': ['Smart Spending'],
      'shopping': ['Smart Shopping'],
      'planning': ['Budget Planning', 'Financial Planning', 'Today\'s Budget'],
      'tracking': ['Money Tracking'],
      'savings': ['Savings Strategy'],
      'habits': ['Money Habits', 'Daily Habits'],
      'management': ['Money Management'],
      'goals': ['Financial Goals'],
      'emergency': ['Emergency Preparedness'],
      'profile': ['Young Adult Finance', 'Building Wealth', 'Financial Security', 'Budget Basics', 'Growing Wealth', 'Wealth Building'],
      'situation': ['Family Finance', 'Debt Freedom', 'Business Finance']
    };
    
    // Create reverse mapping from category to group
    final categoryToGroup = <String, String>{};
    categoryGroups.forEach((group, categories) {
      for (final category in categories) {
        categoryToGroup[category] = group;
      }
    });
    
    final usedGroups = <String>{};
    
    // First pass: Select one tip from each different category group
    for (final tip in allCoachingTips) {
      final group = categoryToGroup[tip.category] ?? 'other';
      if (!usedGroups.contains(group) && 
          !usedCategories.contains(tip.category) && 
          !usedTitles.contains(tip.title) && 
          selectedTips.length < 3) {
        selectedTips.add(tip);
        usedCategories.add(tip.category);
        usedTitles.add(tip.title);
        usedGroups.add(group);
      }
    }
    
    // Second pass: Fill remaining slots with tips from unused categories
    for (final tip in allCoachingTips) {
      if (!usedCategories.contains(tip.category) && 
          !usedTitles.contains(tip.title) && 
          selectedTips.length < 3) {
        selectedTips.add(tip);
        usedCategories.add(tip.category);
        usedTitles.add(tip.title);
      }
    }
    
    // Third pass: If we still need more tips, ensure they're different from existing ones
    for (final tip in allCoachingTips) {
      if (!selectedTips.contains(tip) && 
          !usedTitles.contains(tip.title) && 
          _isTipContentDifferent(tip, selectedTips) &&
          selectedTips.length < 3) {
        selectedTips.add(tip);
      }
    }
    
    return selectedTips;
  }
  
  /// Check if a tip's content is sufficiently different from already selected tips
  static bool _isTipContentDifferent(BudgetingTip newTip, List<BudgetingTip> existingTips) {
    for (final existing in existingTips) {
      // Check for similar keywords in titles
      final newTitleWords = newTip.title.toLowerCase().split(' ');
      final existingTitleWords = existing.title.toLowerCase().split(' ');
      final commonWords = newTitleWords.where((word) => 
        existingTitleWords.contains(word) && word.length > 3).length;
      
      // If more than 1 significant word is shared, consider it similar
      if (commonWords > 1) {
        return false;
      }
      
      // Check for similar keywords in messages
      final newMessageWords = newTip.message.toLowerCase().split(' ');
      final existingMessageWords = existing.message.toLowerCase().split(' ');
      final commonMessageWords = newMessageWords.where((word) => 
        existingMessageWords.contains(word) && word.length > 4).length;
      
      // If more than 2 significant words are shared in message, consider it similar
      if (commonMessageWords > 2) {
        return false;
      }
    }
    
    return true;
  }
  
  /// Generate user-specific coaching tips based on their profile
  static List<BudgetingTip> _generateUserSpecificCoachingTips(
    user_models.User user,
    BudgetPrescription? budgetPrescription,
  ) {
    final tips = <BudgetingTip>[];
    final monthlyNet = user.monthlyNet ?? 0.0;
    final age = user.birthYear != null ? DateTime.now().year - user.birthYear! : null;
    
    // Age-specific coaching
    if (age != null) {
      if (age <= 25) {
        tips.add(BudgetingTip(
          category: 'Young Adult Finance',
          title: 'Start Strong Financial Habits Now',
          message: 'The money habits you build in your 20s will shape your entire financial future.',
          action: 'Focus on learning to budget, save regularly, and avoid lifestyle inflation as your income grows.',
          icon: '🚀',
        ));
      } else if (age <= 35) {
        tips.add(BudgetingTip(
          category: 'Building Wealth',
          title: 'Maximize Your Peak Earning Years',
          message: 'Your 30s are crucial for building wealth - increase savings as your income grows.',
          action: 'Aim to save 20% of your income and invest in your future through skills and assets.',
          icon: '📈',
        ));
      } else if (age <= 50) {
        tips.add(BudgetingTip(
          category: 'Financial Security',
          title: 'Secure Your Financial Foundation',
          message: 'Focus on building strong emergency funds and retirement savings.',
          action: 'Ensure you have 6 months of expenses saved and are investing for retirement.',
          icon: '🏦',
        ));
      }
    }
    
    // Income-level coaching
    if (monthlyNet > 0) {
      if (monthlyNet <= 30000) {
        tips.add(BudgetingTip(
          category: 'Budget Basics',
          title: 'Master the Fundamentals',
          message: 'With your current income, focus on the basics: track expenses and avoid debt.',
          action: 'Prioritize essential expenses and build a small emergency fund of ₱5,000 first.',
          icon: '🎯',
        ));
      } else if (monthlyNet <= 60000) {
        tips.add(BudgetingTip(
          category: 'Growing Wealth',
          title: 'Build Your Financial Foundation',
          message: 'Your income allows for both comfort and savings - find the right balance.',
          action: 'Aim for 50% needs, 30% wants, and 20% savings to build long-term wealth.',
          icon: '⚖',
        ));
      } else {
        tips.add(BudgetingTip(
          category: 'Wealth Building',
          title: 'Accelerate Your Wealth Building',
          message: 'With higher income comes greater opportunity to build significant wealth.',
          action: 'Consider investing 25-30% of income and explore advanced financial strategies.',
          icon: '💎',
        ));
      }
    }
    
    // Family situation coaching
    if (user.hasKids == true) {
      tips.add(BudgetingTip(
        category: 'Family Finance',
        title: 'Plan for Your Family\'s Future',
        message: 'Teaching kids about money while securing their future requires careful planning.',
        action: 'Set up education savings and involve age-appropriate kids in family budget discussions.',
        icon: '👪',
      ));
    }
    
    // Debt status coaching
    if (user.debtStatuses.isNotEmpty) {
      tips.add(BudgetingTip(
        category: 'Debt Freedom',
        title: 'Create Your Debt-Free Plan',
        message: 'Every peso spent wisely brings you closer to financial freedom.',
        action: 'List all debts, pay minimums on all, then focus extra payments on one debt at a time.',
        icon: '🔓',
      ));
    }
    
    // Business owner coaching
    if (user.isBusinessOwner == true) {
      tips.add(BudgetingTip(
        category: 'Business Finance',
        title: 'Separate Business and Personal Money',
        message: 'Clear separation between business and personal finances protects both.',
        action: 'Use separate accounts and track business vs personal expenses carefully.',
        icon: '💼',
      ));
    }
    
    return tips;
  }

  /// Generate daily-specific tips
  static List<BudgetingTip> _generateDailyTips(
    DateTime selectedDate,
    Map<String, double> categoryTotals,
    double dailyBudget,
    Map<String, double> actualDailyBudgets,
    bool isToday,
    BudgetPrescription? budgetPrescription,
  ) {
    final tips = <BudgetingTip>[];
    
    // Focus on daily categories (Food and Transportation)
    final dailyCategories = ['Food', 'Transportation'];
    final dailyCategorySpending = dailyCategories.fold(0.0, (sum, category) =>
        sum + (categoryTotals[category] ?? 0.0));

    if (dailyBudget > 0) {
      final spendingRatio = dailyCategorySpending / dailyBudget;
      
      if (isToday) {
        if (spendingRatio > 1.0) {
          final excess = dailyCategorySpending - dailyBudget;
          tips.add(BudgetingTip(
            category: 'Daily Budget',
            title: 'Daily Budget Exceeded',
            message: 'You\'ve spent ₱${dailyCategorySpending.toStringAsFixed(0)} today, exceeding your daily budget by ₱${excess.toStringAsFixed(0)}.',
            action: 'Consider reducing spending tomorrow or finding ways to balance your weekly budget.',
            icon: '⚠',
          ));
        } else if (spendingRatio > 0.8) {
          final remaining = dailyBudget - dailyCategorySpending;
          tips.add(BudgetingTip(
            category: 'Daily Budget',
            title: 'Daily Budget Alert',
            message: 'You\'ve fully used ${(spendingRatio * 100).toStringAsFixed(0)}% of today\'s daily budget.',
            action: 'Only ₱${remaining.toStringAsFixed(0)} remaining for daily expenses today.',
            icon: '🚨',
          ));
        } else if (spendingRatio <= 0.5) {
          tips.add(BudgetingTip(
            category: 'Daily Budget',
            title: 'Great Spending Control',
            message: 'Excellent discipline! You\'ve only fully used ${(spendingRatio * 100).toStringAsFixed(0)}% of today\'s budget.',
            action: 'Keep up the good work and consider saving the extra amount.',
            icon: '✅',
          ));
        }
      } else {
        // Historical day analysis
        if (spendingRatio > 1.2) {
          tips.add(BudgetingTip(
            category: 'Daily Analysis',
            title: 'High Spending Day',
            message: 'On ${DateFormat('MMM d').format(selectedDate)}, you spent significantly above your daily budget.',
            action: 'Look for patterns - was this a special occasion or could spending be optimized?',
            icon: '📈',
          ));
        } else if (spendingRatio <= 0.3) {
          tips.add(BudgetingTip(
            category: 'Daily Analysis',
            title: 'Low Spending Day',
            message: 'Very light spending on ${DateFormat('MMM d').format(selectedDate)} - well done!',
            action: 'Consider if this pattern could be maintained on other days.',
            icon: '🌟',
          ));
        }
      }
    }
    
    // Category-specific analysis
    for (final category in dailyCategories) {
      final categorySpending = categoryTotals[category] ?? 0.0;
      final categoryBudget = actualDailyBudgets[category];
      
      if (categoryBudget != null && categoryBudget > 0 && categorySpending > 0) {
        final categoryRatio = categorySpending / categoryBudget;
        
        if (categoryRatio > 1.2) {
          tips.add(BudgetingTip(
            category: category,
            title: '$category Overspending',
            message: 'Spent ₱${categorySpending.toStringAsFixed(0)} on $category (${(categoryRatio * 100).toStringAsFixed(0)}% of budget).',
            action: category == 'Food' ? 'Consider cooking at home or finding more budget-friendly options.' :
                   'Look for alternative transportation methods to reduce costs.',
            icon: category == 'Food' ? '🍽️' : '🚗',
          ));
        }
      }
    }
    
    return tips;
  }

  /// Generate weekly-specific tips
  static List<BudgetingTip> _generateWeeklyTips(
    DateTime selectedDate,
    Map<String, double> categoryTotals,
    double dailyBudget,
    Map<String, double> actualDailyBudgets,
    BudgetPrescription? budgetPrescription,
  ) {
    final tips = <BudgetingTip>[];
    
    if (dailyBudget > 0) {
      final weeklyBudget = dailyBudget * 7;
      final dailyCategories = ['Food', 'Transportation'];
      final weeklySpending = dailyCategories.fold(0.0, (sum, category) => 
          sum + (categoryTotals[category] ?? 0.0));
      
      final spendingRatio = weeklySpending / weeklyBudget;
      
      if (spendingRatio > 1.1) {
        final excess = weeklySpending - weeklyBudget;
        tips.add(BudgetingTip(
          category: 'Weekly Budget',
          title: 'Weekly Budget Exceeded',
          message: 'This week\'s daily expenses totaled ₱${weeklySpending.toStringAsFixed(0)}, exceeding the weekly budget by ₱${excess.toStringAsFixed(0)}.',
          action: 'Plan more carefully for next week and identify areas where you can cut back.',
          icon: '📉',
        ));
      } else if (spendingRatio <= 0.8) {
        final saved = weeklyBudget - weeklySpending;
        tips.add(BudgetingTip(
          category: 'Weekly Budget',
          title: 'Great Weekly Control',
          message: 'Excellent week! You saved ₱${saved.toStringAsFixed(0)} from your weekly daily budget.',
          action: 'Consider allocating this extra amount to savings or a future goal.',
          icon: '🎆',
        ));
      }
    }
    
    // Weekly pattern analysis
    final totalSpending = categoryTotals.values.fold(0.0, (sum, amount) => sum + amount);
    if (totalSpending > 0) {
      tips.add(BudgetingTip(
        category: 'Weekly Analysis',
        title: 'Weekly Spending Pattern',
        message: 'Total spending this week: ₱${totalSpending.toStringAsFixed(0)}.',
        action: 'Review your weekly patterns to identify trends and optimize future spending.',
        icon: '📊',
      ));
    }
    
    return tips;
  }

  /// Generate monthly-specific tips
  static List<BudgetingTip> _generateMonthlyTips(
    DateTime selectedDate,
    Map<String, double> categoryTotals,
    Map<String, double> actualMonthlyBudgets,
    BudgetPrescription? budgetPrescription,
  ) {
    final tips = <BudgetingTip>[];
    final totalSpending = categoryTotals.values.fold(0.0, (sum, amount) => sum + amount);
    
    if (budgetPrescription != null) {
      final monthlyBudget = budgetPrescription.totalMonthlyBudgetIncludingDaily;
      final spendingRatio = totalSpending / monthlyBudget;
      
      if (spendingRatio > 1.0) {
        final excess = totalSpending - monthlyBudget;
        tips.add(BudgetingTip(
          category: 'Monthly Budget',
          title: 'Monthly Budget Exceeded',
          message: 'Total spending for ${DateFormat('MMMM yyyy').format(selectedDate)} was ₱${totalSpending.toStringAsFixed(0)}, exceeding budget by ₱${excess.toStringAsFixed(0)}.',
          action: 'Analyze your spending categories and adjust future budgets or reduce discretionary spending.',
          icon: '🚨',
        ));
      } else if (spendingRatio <= 0.85) {
        final saved = monthlyBudget - totalSpending;
        tips.add(BudgetingTip(
          category: 'Monthly Budget',
          title: 'Excellent Monthly Control',
          message: 'Great job! You saved ₱${saved.toStringAsFixed(0)} from your monthly budget.',
          action: 'Consider increasing your savings rate or setting aside this extra for emergency fund.',
          icon: '🎉',
        ));
      }
    }
    
    // Category analysis for monthly view
    for (final entry in actualMonthlyBudgets.entries) {
      final category = entry.key;
      final budget = entry.value;
      final spent = categoryTotals[category] ?? 0.0;
      
      if (budget > 0 && spent > 0) {
        final categoryRatio = spent / budget;
        
        if (categoryRatio > 1.1) {
          tips.add(BudgetingTip(
            category: category,
            title: '$category Over Budget',
            message: '$category spending was ₱${spent.toStringAsFixed(0)} (${(categoryRatio * 100).toStringAsFixed(0)}% of budget).',
            action: 'Consider ways to reduce $category expenses next month or adjust the budget allocation.',
            icon: _getCategoryIcon(category),
          ));
        }
      }
    }
    
    return tips;
  }

  /// Get appropriate icon for category
  static String _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'housing & utilities':
      case 'housing':
        return '🏠';
      case 'insurance':
        return '🛡️';
      case 'subscriptions':
        return '📱';
      case 'savings':
        return '💰';
      case 'emergency fund':
        return '🚨';
      case 'debt/loans':
      case 'debt':
        return '💳';
      default:
        return '💡';
    }
  }

  /// Generate diverse budgeting tips covering saving, spending, planning, and tracking
  static List<BudgetingTip> _generateDiverseBudgetingTips(
    user_models.User user,
    TimeFrame timeFrame,
    DateTime selectedDate,
    Map<String, double> categoryTotals,
    double periodExpenses,
    BudgetPrescription? budgetPrescription,
  ) {
    final now = DateTime.now();
    final monthlyNet = user.monthlyNet ?? 0.0;
    final age = user.birthYear != null ? now.year - user.birthYear! : null;
    final totalSpending = categoryTotals.values.fold(0.0, (sum, amount) => sum + amount);

    // Define tip categories for diversity
    final diverseTips = {
      'critical': <BudgetingTip>[],      // Critical alerts (debt, overspending)
      'saving': <BudgetingTip>[],        // Saving and investment tips
      'spending': <BudgetingTip>[],      // Smart spending advice
      'planning': <BudgetingTip>[],      // Financial planning tips
      'tracking': <BudgetingTip>[],      // Budget tracking and monitoring
    };
    
    // 1. CRITICAL TIPS (Priority 1)
    _addCriticalTips(diverseTips['critical']!, user, categoryTotals, totalSpending, monthlyNet);
    
    // 2. SAVING TIPS (Priority 2)
    _addSavingTips(diverseTips['saving']!, user, categoryTotals, monthlyNet);
    
    // 3. SPENDING TIPS (Priority 3)
    _addSmartSpendingTips(diverseTips['spending']!, user, categoryTotals, monthlyNet, age);
    
    // 4. PLANNING TIPS (Priority 4)
    _addPlanningTips(diverseTips['planning']!, user, categoryTotals, monthlyNet, age);
    
    // 5. TRACKING TIPS (Priority 5)
    _addTrackingTips(diverseTips['tracking']!, user, categoryTotals, monthlyNet, timeFrame);
    
    // Select one tip from each category for maximum diversity
    final selectedTips = <BudgetingTip>[];
    
    // Always include critical tips first if available
    if (diverseTips['critical']!.isNotEmpty) {
      selectedTips.add(diverseTips['critical']!.first);
    }
    
    // Then add one from each other category in order of importance
    final categories = ['saving', 'spending', 'planning', 'tracking'];
    for (final category in categories) {
      if (diverseTips[category]!.isNotEmpty && selectedTips.length < 5) {
        selectedTips.add(diverseTips[category]!.first);
      }
    }
    
    // If we have less than 5 tips, fill remaining slots with best tips from any category
    if (selectedTips.length < 5) {
      final allRemainingTips = <BudgetingTip>[];
      for (final category in diverseTips.keys) {
        if (category != 'critical') {
          allRemainingTips.addAll(diverseTips[category]!.skip(1)); // Skip first already added
        }
      }
      
      final remainingSlots = 5 - selectedTips.length;
      selectedTips.addAll(allRemainingTips.take(remainingSlots));
    }
    
    return selectedTips;
  }
  
  /// Add critical financial situation tips
  static void _addCriticalTips(
    List<BudgetingTip> tips,
    user_models.User user,
    Map<String, double> categoryTotals,
    double totalSpending,
    double monthlyNet,
  ) {
    // Overspending alert (most critical) - Multiple variations for daily change
    if (monthlyNet > 0 && totalSpending > monthlyNet * 1.1) {
      final criticalTips = [
        BudgetingTip(
          category: 'Urgent',
          title: 'Spending Alert',
          message: 'You\'re spending ${((totalSpending / monthlyNet) * 100).toStringAsFixed(0)}% of your income.',
          action: 'Review expenses now - find what to cut back.',
          icon: '🚨',
        ),
        BudgetingTip(
          category: 'Urgent',
          title: 'Budget Exceeded',
          message: 'Your spending is ₱${(totalSpending - monthlyNet).toStringAsFixed(0)} over budget.',
          action: 'Stop non-essential purchases immediately.',
          icon: '🚫',
        ),
        const BudgetingTip(
          category: 'Urgent',
          title: 'Income vs Spending',
          message: 'Spending more than you earn leads to debt.',
          action: 'List all expenses and eliminate what\'s not necessary.',
          icon: '⚠',
        ),
        const BudgetingTip(
          category: 'Urgent',
          title: 'Financial Emergency',
          message: 'Overspending puts your financial future at risk.',
          action: 'Cut all wants spending until you\'re back on track.',
          icon: '🆘',
        ),
        const BudgetingTip(
          category: 'Urgent',
          title: 'Money Hemorrhage',
          message: 'Your money is flowing out faster than it comes in.',
          action: 'Track every peso today - see where money is going.',
          icon: '🩸',
        ),
        const BudgetingTip(
          category: 'Urgent',
          title: 'Spending Pattern Alert',
          message: 'Current spending habits will lead to financial trouble.',
          action: 'Take immediate action - cut spending by 20% this week.',
          icon: '📉',
        ),
        const BudgetingTip(
          category: 'Urgent',
          title: 'Budget Crisis Mode',
          message: 'You\'re in financial crisis territory with this spending.',
          action: 'Switch to survival mode - only essentials allowed.',
          icon: '🔴',
        ),
      ];
      tips.addAll(criticalTips);
    }
    
    // Credit card debt (critical) - Multiple variations for daily variety
    if (user.debtStatuses.contains(user_models.DebtStatus.creditCardDebt)) {
      final debtTips = [
        const BudgetingTip(
          category: 'Debt',
          title: 'Pay Off Credit Cards',
          message: 'Credit card interest rates eat away at your money.',
          action: 'Pay minimums on all, then focus extra on highest rate card.',
          icon: '💳',
        ),
        const BudgetingTip(
          category: 'Debt',
          title: 'Stop Using Credit Cards',
          message: 'Adding more debt while paying off cards slows progress.',
          action: 'Use cash or debit only until cards are paid off.',
          icon: '🚫',
        ),
        const BudgetingTip(
          category: 'Debt',
          title: 'Debt Avalanche Method',
          message: 'Pay highest interest rate debts first to save money.',
          action: 'List all debts by interest rate, attack the highest one.',
          icon: '🏄',
        ),
        const BudgetingTip(
          category: 'Debt',
          title: 'Credit Card Interest is Killing You',
          message: 'Credit cards charge 20-30% interest - that\'s money lost forever.',
          action: 'Calculate how much interest you pay monthly - you\'ll be shocked.',
          icon: '🔥',
        ),
        const BudgetingTip(
          category: 'Debt',
          title: 'Debt Snowball Alternative',
          message: 'Pay smallest balances first for psychological wins.',
          action: 'Choose avalanche (save money) or snowball (build momentum).',
          icon: '⛄',
        ),
        const BudgetingTip(
          category: 'Debt',
          title: 'Cut Up the Cards',
          message: 'Physical cards tempt you to spend more.',
          action: 'Remove cards from wallet, keep one for emergencies only.',
          icon: '✂',
        ),
        const BudgetingTip(
          category: 'Debt',
          title: 'Negotiate Interest Rates',
          message: 'Banks will often lower rates for good customers.',
          action: 'Call your credit card company and ask for lower rates.',
          icon: '📞',
        ),
        const BudgetingTip(
          category: 'Debt',
          title: 'Balance Transfer Option',
          message: 'Lower interest cards can help you pay off faster.',
          action: 'Research 0% balance transfer offers carefully.',
          icon: '🔄',
        ),
        const BudgetingTip(
          category: 'Debt',
          title: 'Extra Payments Work Magic',
          message: 'Even ₱500 extra monthly cuts years off debt.',
          action: 'Find ₱500 to add to minimum payments this month.',
          icon: '✨',
        ),
        const BudgetingTip(
          category: 'Debt',
          title: 'Debt is an Emergency',
          message: 'High interest debt is a financial emergency.',
          action: 'Treat debt payoff with the urgency it deserves.',
          icon: '🆘',
        ),
      ];
      tips.addAll(debtTips);
    }
    
    // Emergency situation
    final emergencyFund = user.emergencyFundAmount ?? 0.0;
    if (emergencyFund < monthlyNet * 0.5 && user.profession == user_models.Profession.unemployed) {
      tips.add(BudgetingTip(
        category: 'Emergency',
        title: 'Survival Mode',
        message: 'Focus only on absolute necessities right now.',
        action: 'Cut everything except housing, food, and utilities.',
        icon: '🆘',
      ));
    }
  }
  
  /// Add saving and investment tips
  static void _addSavingTips(
    List<BudgetingTip> tips,
    user_models.User user,
    Map<String, double> categoryTotals,
    double monthlyNet,
  ) {
    final emergencyFund = user.emergencyFundAmount ?? 0.0;
    final currentSavings = categoryTotals['Savings'] ?? 0.0;
    
    // Emergency fund priority - Multiple variations for daily rotation
    if (emergencyFund < monthlyNet * 3) {
      final emergencyTips = [
        const BudgetingTip(
          category: 'Emergency Fund',
          title: 'Build Your Safety Net',
          message: 'Your emergency fund is below 3 months of expenses.',
          action: 'Save all extra money until you reach 3 months of expenses.',
          icon: '🛡',
        ),
        const BudgetingTip(
          category: 'Emergency Fund',
          title: 'Start Small, Build Big',
          message: 'Even ₱500 weekly adds up to ₱26,000 yearly.',
          action: 'Set aside ₱100 daily for emergency fund.',
          icon: '🌱',
        ),
        const BudgetingTip(
          category: 'Emergency Fund',
          title: 'Automate Your Safety',
          message: 'Automatic transfers make saving effortless.',
          action: 'Set up auto-transfer of ₱2,000 monthly to emergency fund.',
          icon: '🤖',
        ),
        const BudgetingTip(
          category: 'Emergency Fund',
          title: 'Emergency Fund First',
          message: 'Build emergency fund before investing.',
          action: 'Emergency fund protects your investments from early withdrawal.',
          icon: '🎯',
        ),
        const BudgetingTip(
          category: 'Emergency Fund',
          title: 'Sleep Better at Night',
          message: 'Emergency funds provide peace of mind.',
          action: 'Imagine the relief of having 3 months of expenses saved.',
          icon: '😴',
        ),
        const BudgetingTip(
          category: 'Emergency Fund',
          title: 'Life Happens Fund',
          message: 'Car repairs, medical bills, job loss - life is unpredictable.',
          action: 'Every peso in emergency fund protects your future.',
          icon: '🌪',
        ),
        const BudgetingTip(
          category: 'Emergency Fund',
          title: 'Financial Independence Starts Here',
          message: 'Emergency fund is step one to financial freedom.',
          action: 'Make emergency fund your top financial priority.',
          icon: '🛤',
        ),
        const BudgetingTip(
          category: 'Emergency Fund',
          title: 'Round Up Your Purchases',
          message: 'Round up spending to nearest ₱50 and save the difference.',
          action: 'Use a round-up app or do it manually each day.',
          icon: '🔄',
        ),
        const BudgetingTip(
          category: 'Emergency Fund',
          title: 'Side Hustle for Safety',
          message: 'Extra income can fast-track your emergency fund.',
          action: 'Put all side income directly into emergency savings.',
          icon: '💼',
        ),
        const BudgetingTip(
          category: 'Emergency Fund',
          title: 'Separate Emergency Account',
          message: 'Keep emergency fund in a different bank.',
          action: 'Make it harder to access for non-emergencies.',
          icon: '🏦',
        ),
      ];
      tips.addAll(emergencyTips);
    }
    
    // Investment encouragement - Multiple variations for daily variety
    if (user.savingsInvestments.contains(user_models.SavingsInvestments.investments)) {
      final investmentTips = [
        const BudgetingTip(
          category: 'Investment',
          title: 'Keep Investing',
          message: 'You\'re already investing - great job!',
          action: 'Invest the same amount each month for steady growth.',
          icon: '📈',
        ),
        const BudgetingTip(
          category: 'Investment',
          title: 'Dollar-Cost Averaging',
          message: 'Regular investing smooths out market ups and downs.',
          action: 'Invest the same amount monthly regardless of market conditions.',
          icon: '📊',
        ),
        const BudgetingTip(
          category: 'Investment',
          title: 'Review and Rebalance',
          message: 'Check your investment allocation quarterly.',
          action: 'Ensure your portfolio matches your risk tolerance.',
          icon: '⚖',
        ),
        const BudgetingTip(
          category: 'Investment',
          title: 'Time in Market Beats Timing',
          message: 'Staying invested long-term builds real wealth.',
          action: 'Don\'t try to time the market - just stay consistent.',
          icon: '⏰',
        ),
        const BudgetingTip(
          category: 'Investment',
          title: 'Compound Interest is Magic',
          message: 'Your money makes money, then that money makes money.',
          action: 'Let your investments compound - don\'t withdraw early.',
          icon: '✨',
        ),
        const BudgetingTip(
          category: 'Investment',
          title: 'Increase Investment Rate',
          message: 'Can you invest ₱1,000 more monthly?',
          action: 'Small increases now create huge differences later.',
          icon: '🚀',
        ),
        const BudgetingTip(
          category: 'Investment',
          title: 'Diversify Your Holdings',
          message: 'Don\'t put all eggs in one investment basket.',
          action: 'Spread investments across different asset types.',
          icon: '🧺',
        ),
        const BudgetingTip(
          category: 'Investment',
          title: 'Automate Investments',
          message: 'Set it and forget it - automation removes emotions.',
          action: 'Set up automatic investment transfers.',
          icon: '🤖',
        ),
        const BudgetingTip(
          category: 'Investment',
          title: 'Education Pays Dividends',
          message: 'Knowledge about investing reduces fear and improves returns.',
          action: 'Read one investing article or book monthly.',
          icon: '📚',
        ),
        const BudgetingTip(
          category: 'Investment',
          title: 'Stay the Course',
          message: 'Market volatility tests your commitment to investing.',
          action: 'Remember your long-term goals when markets get scary.',
          icon: '🧭',
        ),
      ];
      tips.addAll(investmentTips);
    } else if (monthlyNet > 25000 && emergencyFund >= monthlyNet * 3) {
      final newInvestorTips = [
        const BudgetingTip(
          category: 'Investment',
          title: 'Start Investing',
          message: 'With your emergency fund ready, consider investing.',
          action: 'Start with ₱2,000 monthly in index funds.',
          icon: '💰',
        ),
        const BudgetingTip(
          category: 'Investment',
          title: 'Learn Before You Leap',
          message: 'Understand investments before putting money in.',
          action: 'Read about index funds and stock market basics.',
          icon: '📚',
        ),
        const BudgetingTip(
          category: 'Investment',
          title: 'Start with Index Funds',
          message: 'Index funds are simple and low-cost for beginners.',
          action: 'Consider Philippine stock index funds for local exposure.',
          icon: '🇵🇭',
        ),
        const BudgetingTip(
          category: 'Investment',
          title: 'UITF vs Mutual Funds',
          message: 'Both are good starting points for Filipino investors.',
          action: 'Compare fees and performance between different funds.',
          icon: '🏦',
        ),
        const BudgetingTip(
          category: 'Investment',
          title: 'Start Small and Learn',
          message: 'Begin with ₱1,000 monthly to learn the ropes.',
          action: 'Increase investments as you gain confidence and knowledge.',
          icon: '🌱',
        ),
        const BudgetingTip(
          category: 'Investment',
          title: 'COL Financial for Beginners',
          message: 'Online brokers make investing accessible to Filipinos.',
          action: 'Research COL, First Metro, BPI Trade for stock investing.',
          icon: '💻',
        ),
        const BudgetingTip(
          category: 'Investment',
          title: 'Don\'t Wait for Perfect Time',
          message: 'The best time to invest was yesterday, second best is today.',
          action: 'Start investing this month, even with a small amount.',
          icon: '⌚',
        ),
        const BudgetingTip(
          category: 'Investment',
          title: 'Risk vs Return',
          message: 'Higher returns require taking some risk.',
          action: 'Start with moderate risk investments and learn gradually.',
          icon: '⚖',
        ),
      ];
      tips.addAll(newInvestorTips);
    }
    
    // Age-specific saving advice
    if (user.birthYear != null) {
      final age = DateTime.now().year - user.birthYear!;
      if (age <= 30 && currentSavings < monthlyNet * 0.2) {
        final youngSaverTips = [
          const BudgetingTip(
            category: 'Early Saving',
            title: 'Save More While Young',
            message: 'Time is your biggest wealth-building advantage.',
            action: 'Try to save 20% of income - even ₱1,000 monthly helps.',
            icon: '🚀',
          ),
          const BudgetingTip(
            category: 'Early Saving',
            title: 'Compound Interest Magic',
            message: '₱1,000 monthly at 20 becomes ₱500,000 at 30.',
            action: 'Start saving now, even if it\'s a small amount.',
            icon: '✨',
          ),
          const BudgetingTip(
            category: 'Early Saving',
            title: 'Pay Yourself First',
            message: 'Save before spending on anything else.',
            action: 'Transfer savings immediately when you get paid.',
            icon: '💵',
          ),
        ];
        tips.addAll(youngSaverTips);
      }
    }
    
    // Retirement savings
    if (user.birthYear != null) {
      final age = DateTime.now().year - user.birthYear!;
      if (age >= 25 && age <= 50) {
        tips.add(BudgetingTip(
          category: 'Retirement',
          title: 'Plan for Retirement',
          message: 'Start retirement savings early for maximum growth.',
          action: 'Aim to save 10-15% of income for retirement.',
          icon: '🏖',
        ));
      }
    }
  }
  
  /// Add smart spending tips
  static void _addSmartSpendingTips(
    List<BudgetingTip> tips,
    user_models.User user,
    Map<String, double> categoryTotals,
    double monthlyNet,
    int? age,
  ) {
    final foodSpending = categoryTotals['Food'] ?? 0.0;
    final transportSpending = categoryTotals['Transportation'] ?? 0.0;
    final entertainmentSpending = categoryTotals['Entertainment & Lifestyle'] ?? 0.0;
    
    // Food spending optimization - Multiple variations for daily rotation
    if (foodSpending > monthlyNet * 0.25) {
      final foodTips = [
        BudgetingTip(
          category: 'Food Spending',
          title: 'Reduce Food Costs',
          message: 'Food spending is ${((foodSpending / monthlyNet) * 100).toStringAsFixed(0)}% of your income.',
          action: 'Try meal prep, cook at home, or find cheaper dining options.',
          icon: '🍽',
        ),
        const BudgetingTip(
          category: 'Food Spending',
          title: 'Meal Prep Sundays',
          message: 'Preparing meals in advance saves money and time.',
          action: 'Cook large batches on Sunday for the whole week.',
          icon: '🍲',
        ),
        const BudgetingTip(
          category: 'Food Spending',
          title: 'Shop with a List',
          message: 'Grocery lists prevent impulse purchases.',
          action: 'Plan meals, make a list, and stick to it.',
          icon: '📝',
        ),
        const BudgetingTip(
          category: 'Food Spending',
          title: 'Cook More, Order Less',
          message: 'Home cooking costs 3x less than food delivery.',
          action: 'Limit food delivery to once per week maximum.',
          icon: '🏠',
        ),
        const BudgetingTip(
          category: 'Food Spending',
          title: 'Find Affordable Favorites',
          message: 'Local carinderias offer tasty, budget-friendly meals.',
          action: 'Explore neighborhood food options for daily meals.',
          icon: '🇵🇭',
        ),
        const BudgetingTip(
          category: 'Food Spending',
          title: 'Bulk Buying Saves Money',
          message: 'Buy rice, canned goods, and staples in bulk.',
          action: 'Stock up on non-perishables when they\'re on sale.',
          icon: '🍚',
        ),
        const BudgetingTip(
          category: 'Food Spending',
          title: 'Leftovers are Money',
          message: 'Throwing away food is throwing away money.',
          action: 'Plan to use leftovers for lunch the next day.',
          icon: '♾',
        ),
        const BudgetingTip(
          category: 'Food Spending',
          title: 'Happy Hour Dining',
          message: 'Many restaurants offer discounts during off-peak hours.',
          action: 'Eat out during lunch or early dinner for better prices.',
          icon: '🍹',
        ),
        const BudgetingTip(
          category: 'Food Spending',
          title: 'Coffee Shop Budget Killer',
          message: '₱150 daily coffee = ₱54,000 yearly.',
          action: 'Make coffee at home or limit to 2x per week.',
          icon: '☕',
        ),
        const BudgetingTip(
          category: 'Food Spending',
          title: 'Seasonal Shopping',
          message: 'Buy fruits and vegetables when they\'re in season.',
          action: 'Seasonal produce is cheaper and more nutritious.',
          icon: '🍅',
        ),
        const BudgetingTip(
          category: 'Food Spending',
          title: 'Water Instead of Drinks',
          message: 'Soft drinks add up quickly in restaurants.',
          action: 'Order water and save ₱50-100 per meal.',
          icon: '💧',
        ),
      ];
      tips.addAll(foodTips);
    }
    
    // Transportation spending - Multiple variations for Metro Manila and other areas
    if (transportSpending > monthlyNet * 0.15) {
      if (user.city?.toLowerCase().contains('manila') == true) {
        final manilaTransportTips = [
          const BudgetingTip(
            category: 'Transport',
            title: 'Cut Transport Costs',
            message: 'Metro Manila transport eats up your budget.',
            action: 'Use MRT/LRT, carpool, or work from home.',
            icon: '🚇',
          ),
          const BudgetingTip(
            category: 'Transport',
            title: 'Buy Monthly Passes',
            message: 'MRT/LRT monthly passes are cheaper than daily tickets.',
            action: 'Get stored value cards for regular commuting.',
            icon: '💳',
          ),
          const BudgetingTip(
            category: 'Transport',
            title: 'Carpool with Colleagues',
            message: 'Sharing rides cuts costs and reduces traffic stress.',
            action: 'Organize carpools with office mates.',
            icon: '🚗',
          ),
          const BudgetingTip(
            category: 'Transport',
            title: 'Walk When Possible',
            message: 'Short trips on foot save money and improve health.',
            action: 'Walk for trips under 1km when time allows.',
            icon: '🚶',
          ),
          const BudgetingTip(
            category: 'Transport',
            title: 'Avoid Rush Hour Surge',
            message: 'Grab and taxi rates spike during peak hours.',
            action: 'Adjust your schedule to avoid surge pricing.',
            icon: '🕒',
          ),
          const BudgetingTip(
            category: 'Transport',
            title: 'Jeepney + MRT Combo',
            message: 'Mix public transport for cheapest routes.',
            action: 'Plan multi-modal trips to save on transport costs.',
            icon: '🚌',
          ),
          const BudgetingTip(
            category: 'Transport',
            title: 'Work from Home Days',
            message: 'Remote work saves ₱300-500 daily transport.',
            action: 'Negotiate WFH days with your employer.',
            icon: '🏠',
          ),
          const BudgetingTip(
            category: 'Transport',
            title: 'Bike to Work',
            message: 'Cycling is free transport and great exercise.',
            action: 'Use bike lanes - save money and stay fit.',
            icon: '🚴',
          ),
          const BudgetingTip(
            category: 'Transport',
            title: 'Early Bird Commute',
            message: 'Travel before 7 AM for less crowded, cheaper rides.',
            action: 'Start work earlier to avoid peak hour costs.',
            icon: '🌅',
          ),
          const BudgetingTip(
            category: 'Transport',
            title: 'UV Express vs Taxi',
            message: 'UV Express costs half of what taxis charge.',
            action: 'Learn UV routes for your regular destinations.',
            icon: '🚐',
          ),
        ];
        tips.addAll(manilaTransportTips);
      } else {
        final generalTransportTips = [
          const BudgetingTip(
            category: 'Transport',
            title: 'Optimize Travel',
            message: 'Transport costs are high for your area.',
            action: 'Combine trips or find cheaper options.',
            icon: '🚌',
          ),
          const BudgetingTip(
            category: 'Transport',
            title: 'Plan Your Routes',
            message: 'Efficient routes save fuel and time.',
            action: 'Combine errands into single trips.',
            icon: '🗺',
          ),
          const BudgetingTip(
            category: 'Transport',
            title: 'Consider a Bike',
            message: 'Bicycles are great for short-distance travel.',
            action: 'Use bikes for trips under 5km.',
            icon: '🚲',
          ),
          const BudgetingTip(
            category: 'Transport',
            title: 'Public Transport First',
            message: 'Buses and jeepneys are usually cheapest.',
            action: 'Use ride-hailing only when necessary.',
            icon: '🚍',
          ),
          const BudgetingTip(
            category: 'Transport',
            title: 'Fuel Efficiency',
            message: 'Maintain your vehicle for better gas mileage.',
            action: 'Keep tires inflated and engine tuned.',
            icon: '⛽',
          ),
          const BudgetingTip(
            category: 'Transport',
            title: 'Carpool Networks',
            message: 'Share rides with neighbors and coworkers.',
            action: 'Create or join local carpool groups.',
            icon: '👥',
          ),
          const BudgetingTip(
            category: 'Transport',
            title: 'Walk More, Drive Less',
            message: 'Walking is free and good for your health.',
            action: 'Walk for errands within 1-2km.',
            icon: '🚶',
          ),
        ];
        tips.addAll(generalTransportTips);
      }
    }
    
    // Entertainment spending balance
    if (entertainmentSpending > monthlyNet * 0.15) {
      final entertainmentTips = [
        const BudgetingTip(
          category: 'Entertainment',
          title: 'Balance Fun and Finance',
          message: 'Entertainment spending is quite high.',
          action: 'Find free/cheap activities - parks, home cooking with friends.',
          icon: '🎉',
        ),
        const BudgetingTip(
          category: 'Entertainment',
          title: 'Free Fun Activities',
          message: 'Philippines has many free entertainment options.',
          action: 'Visit public parks, beaches, or free museum days.',
          icon: '🏖',
        ),
        const BudgetingTip(
          category: 'Entertainment',
          title: 'Home Entertainment',
          message: 'Netflix night costs less than cinema.',
          action: 'Host movie nights or potluck dinners at home.',
          icon: '🏠',
        ),
        const BudgetingTip(
          category: 'Entertainment',
          title: 'Happy Hour Instead',
          message: 'Early dining discounts save 20-30%.',
          action: 'Choose happy hour times for dining out.',
          icon: '🍹',
        ),
      ];
      tips.addAll(entertainmentTips);
    } else if (entertainmentSpending < monthlyNet * 0.05 && age != null && age <= 35) {
      final lifestyleTips = [
        const BudgetingTip(
          category: 'Lifestyle',
          title: 'Enjoy Life Too',
          message: 'You\'re very disciplined with entertainment spending.',
          action: 'Budget some fun money - balance saving with living.',
          icon: '😊',
        ),
        const BudgetingTip(
          category: 'Lifestyle',
          title: 'Treat Yourself Sometimes',
          message: 'All saving and no fun can lead to budget burnout.',
          action: 'Set aside ₱500 monthly for guilt-free fun.',
          icon: '🎆',
        ),
      ];
      tips.addAll(lifestyleTips);
    }
    
    // General smart spending
    final generalSpendingTips = [
      const BudgetingTip(
        category: 'Smart Spending',
        title: '24-Hour Rule',
        message: 'Wait a day before buying non-essentials.',
        action: 'Sleep on purchases over ₱1,000.',
        icon: '⏰',
      ),
      const BudgetingTip(
        category: 'Smart Spending',
        title: 'Compare Prices',
        message: 'Shop around before making big purchases.',
        action: 'Check at least 3 stores or websites for prices.',
        icon: '🔍',
      ),
      const BudgetingTip(
        category: 'Smart Spending',
        title: 'Quality vs Quantity',
        message: 'Buy fewer, better things that last longer.',
        action: 'Invest in quality items for frequently used products.',
        icon: '⭐',
      ),
    ];
    tips.addAll(generalSpendingTips);
  }
  
  /// Add financial planning tips
  static void _addPlanningTips(
    List<BudgetingTip> tips,
    user_models.User user,
    Map<String, double> categoryTotals,
    double monthlyNet,
    int? age,
  ) {
    // Family planning
    if (user.hasKids == true) {
      final familyTips = [
        const BudgetingTip(
          category: 'Family Planning',
          title: 'Plan for Your Kids',
          message: 'Children\'s future needs planning today.',
          action: 'Start education savings - even ₱1,000 monthly helps.',
          icon: '👪',
        ),
        const BudgetingTip(
          category: 'Family Planning',
          title: 'College Fund Strategy',
          message: 'College costs increase every year.',
          action: 'Save ₱2,000 monthly per child for education.',
          icon: '🎓',
        ),
        const BudgetingTip(
          category: 'Family Planning',
          title: 'Insurance for Family',
          message: 'Protect your family\'s financial future.',
          action: 'Get life insurance coverage worth 10x your annual income.',
          icon: '🛡',
        ),
        const BudgetingTip(
          category: 'Family Planning',
          title: 'Teach Kids About Money',
          message: 'Financial education starts at home.',
          action: 'Give kids allowances and teach them to save.',
          icon: '📚',
        ),
      ];
      tips.addAll(familyTips);
    }
    
    // Home ownership planning
    if (user.householdSituation == user_models.HouseholdSituation.renting && monthlyNet > 30000) {
      final homeTips = [
        const BudgetingTip(
          category: 'Home Planning',
          title: 'Consider Buying a Home',
          message: 'Your income level suggests you might afford homeownership.',
          action: 'Save ₱5,000 monthly for down payment.',
          icon: '🏠',
        ),
        const BudgetingTip(
          category: 'Home Planning',
          title: 'House vs Condo',
          message: 'Consider location, maintenance, and resale value.',
          action: 'Research both options and calculate total costs.',
          icon: '🏢',
        ),
        const BudgetingTip(
          category: 'Home Planning',
          title: 'Pre-qualify for Loan',
          message: 'Know your buying power before house hunting.',
          action: 'Get pre-qualified with banks for home loans.',
          icon: '💰',
        ),
        const BudgetingTip(
          category: 'Home Planning',
          title: 'Factor in ALL Costs',
          message: 'Home ownership has hidden costs beyond mortgage.',
          action: 'Budget for maintenance, taxes, and repairs.',
          icon: '🔧',
        ),
      ];
      tips.addAll(homeTips);
    }
    
    // Retirement planning
    if (age != null && age >= 40) {
      final retirementTips = [
        const BudgetingTip(
          category: 'Retirement',
          title: 'Plan for Retirement',
          message: 'Retirement planning becomes more urgent with age.',
          action: 'Ensure 15% of income goes to retirement savings.',
          icon: '🏖',
        ),
        const BudgetingTip(
          category: 'Retirement',
          title: 'SSS and Other Benefits',
          message: 'Maximize government retirement benefits.',
          action: 'Check SSS contributions and consider voluntary payments.',
          icon: '🇾🇭',
        ),
        const BudgetingTip(
          category: 'Retirement',
          title: 'Retirement Lifestyle',
          message: 'Plan the lifestyle you want in retirement.',
          action: 'Calculate how much you\'ll need monthly when retired.',
          icon: '🌅',
        ),
      ];
      tips.addAll(retirementTips);
    }
    
    // Career/income planning
    if (user.isBusinessOwner == true) {
      final businessTips = [
        const BudgetingTip(
          category: 'Business Planning',
          title: 'Plan for Income Swings',
          message: 'Business income varies - plan for ups and downs.',
          action: 'Save 40% during good months for lean periods.',
          icon: '📊',
        ),
        const BudgetingTip(
          category: 'Business Planning',
          title: 'Separate Business and Personal',
          message: 'Keep business and personal finances separate.',
          action: 'Open separate bank accounts for business expenses.',
          icon: '💼',
        ),
        const BudgetingTip(
          category: 'Business Planning',
          title: 'Business Emergency Fund',
          message: 'Businesses need emergency funds too.',
          action: 'Save 3 months of business expenses separately.',
          icon: '🏦',
        ),
      ];
      tips.addAll(businessTips);
    } else if (age != null && age <= 35 && monthlyNet < 50000) {
      final careerTips = [
        const BudgetingTip(
          category: 'Career Growth',
          title: 'Invest in Your Skills',
          message: 'Your biggest asset is your earning potential.',
          action: 'Take courses, get certifications to boost income.',
          icon: '📚',
        ),
        const BudgetingTip(
          category: 'Career Growth',
          title: 'Side Hustle Options',
          message: 'Extra income accelerates financial goals.',
          action: 'Consider freelancing or part-time work.',
          icon: '💻',
        ),
        const BudgetingTip(
          category: 'Career Growth',
          title: 'Network for Success',
          message: 'Connections often lead to better opportunities.',
          action: 'Join professional groups and attend industry events.',
          icon: '🤝',
        ),
      ];
      tips.addAll(careerTips);
    }
    
    // General planning tips - Multiple variations for daily rotation
    final generalPlanningTips = [
      const BudgetingTip(
        category: 'Goal Setting',
        title: 'Set SMART Financial Goals',
        message: 'Specific goals are more likely to be achieved.',
        action: 'Write down 3 financial goals with deadlines.',
        icon: '🎯',
      ),
      const BudgetingTip(
        category: 'Financial Review',
        title: 'Monthly Money Meeting',
        message: 'Regular reviews keep you on track.',
        action: 'Schedule monthly budget reviews.',
        icon: '📅',
      ),
      const BudgetingTip(
        category: 'Planning',
        title: 'Plan for Major Expenses',
        message: 'Avoid debt by planning for big purchases.',
        action: 'Save separately for appliances, vacations, or car repairs.',
        icon: '📋',
      ),
      const BudgetingTip(
        category: 'Planning',
        title: 'Create a 5-Year Plan',
        message: 'Long-term planning guides daily money decisions.',
        action: 'Visualize where you want to be financially in 5 years.',
        icon: '🔮',
      ),
      const BudgetingTip(
        category: 'Planning',
        title: 'Seasonal Expense Planning',
        message: 'Christmas, birthdays, and vacations happen every year.',
        action: 'Save monthly for predictable seasonal expenses.',
        icon: '🎄',
      ),
      const BudgetingTip(
        category: 'Planning',
        title: 'Backup Plan for Income Loss',
        message: 'Having a plan reduces financial anxiety.',
        action: 'Know what expenses you\'d cut if income dropped 50%.',
        icon: '🌂',
      ),
      const BudgetingTip(
        category: 'Planning',
        title: 'Track Your Net Worth',
        message: 'Net worth shows your overall financial progress.',
        action: 'Calculate assets minus debts quarterly.',
        icon: '📈',
      ),
      const BudgetingTip(
        category: 'Planning',
        title: 'Plan Your Next Raise',
        message: 'Decide how to use salary increases before you get them.',
        action: 'Commit to saving 50% of any future raise.',
        icon: '📈',
      ),
      const BudgetingTip(
        category: 'Planning',
        title: 'Financial Date Nights',
        message: 'Couples who plan money together stay together.',
        action: 'Schedule monthly money talks with your partner.',
        icon: '💑',
      ),
      const BudgetingTip(
        category: 'Planning',
        title: 'Insurance Review',
        message: 'Protect your financial plan with proper insurance.',
        action: 'Review health, life, and property insurance annually.',
        icon: '🛡',
      ),
    ];
    tips.addAll(generalPlanningTips);
  }
  
  /// Add budget tracking and monitoring tips
  static void _addTrackingTips(
    List<BudgetingTip> tips,
    user_models.User user,
    Map<String, double> categoryTotals,
    double monthlyNet,
    TimeFrame timeFrame,
  ) {
    final now = DateTime.now();
    final dayOfMonth = now.day;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final monthProgress = dayOfMonth / daysInMonth;
    
    // Multiple tracking tip variations for daily rotation
    final trackingTips = [
      const BudgetingTip(
        category: 'Daily Tracking',
        title: 'Track Daily Spending',
        message: 'Daily tracking builds strong money awareness.',
        action: 'Log expenses right after you spend.',
        icon: '✏',
      ),
      const BudgetingTip(
        category: 'Weekly Review',
        title: 'Weekly Money Check',
        message: 'Start the week by reviewing last week\'s spending.',
        action: 'Set spending intentions for this week.',
        icon: '📅',
      ),
      const BudgetingTip(
        category: 'Budget Tracking',
        title: 'Photo Receipt Habit',
        message: 'Take photos of receipts to track spending later.',
        action: 'Review and categorize receipt photos weekly.',
        icon: '📷',
      ),
      const BudgetingTip(
        category: 'Expense Tracking',
        title: 'Track Small Expenses Too',
        message: '₱50 here and ₱100 there adds up quickly.',
        action: 'Don\'t ignore small purchases - they matter.',
        icon: '🔍',
      ),
      const BudgetingTip(
        category: 'Budget Monitoring',
        title: 'Check Budget Progress',
        message: 'Know where you stand with your budget mid-month.',
        action: 'Review spending vs budget every 2 weeks.',
        icon: '📊',
      ),
      const BudgetingTip(
        category: 'Spending Awareness',
        title: 'Cash Envelope Method',
        message: 'Physical cash makes spending more real.',
        action: 'Try cash envelopes for food and transport.',
        icon: '💰',
      ),
      const BudgetingTip(
        category: 'Financial Tracking',
        title: 'Use Apps for Tracking',
        message: 'Smartphone apps make expense tracking easier.',
        action: 'Find a tracking app that works for your lifestyle.',
        icon: '📱',
      ),
      const BudgetingTip(
        category: 'Budget Review',
        title: 'End of Month Analysis',
        message: 'Learn from each month to improve the next.',
        action: 'Analyze what went right and wrong this month.',
        icon: '🔍',
      ),
      const BudgetingTip(
        category: 'Spending Patterns',
        title: 'Identify Spending Triggers',
        message: 'Notice when and why you overspend.',
        action: 'Track your mood and situations when spending.',
        icon: '🧐',
      ),
      const BudgetingTip(
        category: 'Goal Tracking',
        title: 'Track Progress to Goals',
        message: 'Seeing progress motivates you to continue.',
        action: 'Update your goal progress weekly.',
        icon: '🎯',
      ),
      const BudgetingTip(
        category: 'Account Monitoring',
        title: 'Check Account Balances',
        message: 'Know your account balances daily.',
        action: 'Check bank apps each morning.',
        icon: '🏦',
      ),
      const BudgetingTip(
        category: 'Category Analysis',
        title: 'Analyze Spending Categories',
        message: 'Which categories consistently go over budget?',
        action: 'Focus improvement efforts on problem categories.',
        icon: '📉',
      ),
      const BudgetingTip(
        category: 'Receipt Organization',
        title: 'Organize Your Receipts',
        message: 'Good record keeping helps with budgeting.',
        action: 'Keep receipts organized by month and category.',
        icon: '📄',
      ),
      const BudgetingTip(
        category: 'Trend Analysis',
        title: 'Spot Spending Trends',
        message: 'Look for patterns in your spending over time.',
        action: 'Compare monthly spending for the last 3 months.',
        icon: '📈',
      ),
      const BudgetingTip(
        category: 'Budget Alerts',
        title: 'Set Spending Alerts',
        message: 'Get notifications when categories are nearly maxed.',
        action: 'Set up bank alerts for unusual spending.',
        icon: '🔔',
      ),
    ];
    
    // Add time-specific tips based on current situation
    if (timeFrame == TimeFrame.monthly) {
      final totalSpending = categoryTotals.values.fold(0.0, (sum, amount) => sum + amount);
      final expectedSpending = monthlyNet * 0.8 * monthProgress; // Assume 80% should be spent
      
      if (totalSpending > expectedSpending * 1.2) {
        trackingTips.add(const BudgetingTip(
          category: 'Budget Tracking',
          title: 'Track Monthly Progress',
          message: 'You\'re spending faster than planned this month.',
          action: 'Check which categories are over budget.',
          icon: '📱',
        ));
      }
    }
    
    // Weekly tracking habit
    if (now.weekday == 1) { // Monday
      trackingTips.add(const BudgetingTip(
        category: 'Weekly Review',
        title: 'Monday Money Check',
        message: 'Start the week by reviewing last week\'s spending.',
        action: 'Set spending intentions for this week.',
        icon: '📅',
      ));
    }
    
    // Goal tracking based on emergency fund
    final emergencyFund = user.emergencyFundAmount ?? 0.0;
    if (emergencyFund > 0 && emergencyFund < monthlyNet * 6) {
      final progress = (emergencyFund / (monthlyNet * 6) * 100).toStringAsFixed(0);
      trackingTips.add(BudgetingTip(
        category: 'Goal Tracking',
        title: 'Track Emergency Fund Goal',
        message: 'Emergency fund is $progress% complete.',
        action: 'Keep tracking progress to stay motivated.',
        icon: '🎯',
      ));
    }
    
    tips.addAll(trackingTips);
  }
}

extension BudgetFrameworkExtension on BudgetFramework {
  String get name {
    switch (this) {
      case BudgetFramework.framework50_30_20:
        return '50/30/20';
      case BudgetFramework.framework60_30_10:
        return '60/30/10';
      case BudgetFramework.framework60_25_10_5:
        return '60/25/10/5';
    }
  }

  String get description {
    switch (this) {
      case BudgetFramework.framework50_30_20:
        return 'Balanced approach: 50% Needs, 30% Wants, 20% Savings - Based on your spending patterns';
      case BudgetFramework.framework60_30_10:
        return 'Higher needs coverage: 60% Needs, 30% Wants, 10% Savings - From last month\'s data';
      case BudgetFramework.framework60_25_10_5:
        return 'Debt focused: 60% Needs, 25% Wants, 10% Savings, 5% Debt - Using your spending history';
    }
  }
}
