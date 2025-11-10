import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import '../models/budget_prescription.dart';
import '../models/transaction.dart';
import '../models/user.dart';
import '../services/budget_framework_service.dart';
import '../services/budget_preloader_service.dart';
import '../services/daily_allocation_service.dart';
import '../services/data_cache_service.dart';
import '../services/firebase_service.dart';
import '../services/smart_budget_data_selection_service.dart';
import '../services/category_analyzer.dart';

/// Main service for generating comprehensive budget prescriptions
/// Uses previous month's transaction data to create personalized budget plans
class BudgetPrescriptionService {
  static final DataCacheService _cacheService = DataCacheService();

  /// Generate a complete budget prescription for the current month
  /// Uses smart data selection to find the best month's data for budget calculation
  static Future<BudgetPrescription?> generateBudgetPrescription() async {
    try {
      final now = DateTime.now();
      final currentMonth = DateTime(now.year, now.month, 1);

      // Get user data for income information
      final user = await FirebaseService.getUser();
      if (user == null) {
        return null;
      }

      // Use smart data selection to find the best month's data to use
      final dataSelection = await SmartBudgetDataSelectionService.findBestDataMonth(currentMonth);
      final selectedDataMonth = dataSelection.selectedMonth;

      // Apply category preservation rules
      final preservedCategories = await CategoryAnalyzer.getPreservedCategories(
        selectedDataMonth,
        dataSelection.categorySpending,
      );

      // Analyze the selected month's data
      final dataAnalysis = _PreviousMonthAnalysis(
        categorySpending: preservedCategories,
        daysFilled: dataSelection.daysWithData,
        totalDaysInMonth: dataSelection.totalDaysInMonth,
        dataCompleteness: dataSelection.dataCompleteness,
        confidence: _determineConfidence(dataSelection),
        transactionCount: dataSelection.transactionCount,
      );
      
      // Check if we have sufficient data from the selected month
      final hasAnyTransactionData = dataAnalysis.categorySpending.isNotEmpty;
      final totalSpending = dataAnalysis.categorySpending.values.fold(0.0, (a, b) => a + b);
      
      // Check if user has existing prescriptions to determine if this is their first budget
      final userHasExistingPrescriptions = await hasExistingPrescriptions();
      
      // Apply data validation constraint only for first-time budget generation
      // ✅ Minimum 50% data confidence — ensures enough complete and accurate spending data
      // ✅ At least 15 transactions — confirms the month reflects real spending behavior
      if (!userHasExistingPrescriptions) {
        final meetsMinimumDataRequirements = (dataAnalysis.dataCompleteness >= 50.0 || dataAnalysis.transactionCount >= 15);
        
        if (!hasAnyTransactionData || totalSpending == 0 || !meetsMinimumDataRequirements) {
          return null; // Need sufficient spending data to create first budget
        }
      } else {
        // For existing users, just check for basic data availability
        if (!hasAnyTransactionData || totalSpending == 0) {
          return null; // Need spending data to create budget
        }
      }
      
      // Calculate net income using the selected data month for context
      final monthlyNetIncome = await _calculateMonthlyNetIncome(user, selectedDataMonth);
      
      if (monthlyNetIncome <= 0) {
        return null; // Cannot create prescription with zero or negative income
      }

      // BUDGET COMPUTATION START: Core budget calculation using category-based approach
      // Calculate category-based budget using new rules
      final categoryBasedBudget = await BudgetFrameworkService.calculateCategoryBasedBudget(
        monthlyNetIncome,
        dataAnalysis.categorySpending,
        dataAnalysis.daysFilled,
        dataAnalysis.totalDaysInMonth,
        selectedDataMonth, // Pass base month for category analysis
      );
      // BUDGET COMPUTATION END: Core budget calculation

      // Create a framework analysis representation for backward compatibility
      final recommendedFramework = FrameworkAnalysis(
        framework: BudgetFramework.framework50_30_20, // Default framework for compatibility
        percentages: {'Fixed Needs': 0.0, 'Flexible Needs': 0.0, 'Remaining': 0.0}, // Not used in new logic
        amounts: {
          'Fixed Needs': categoryBasedBudget.fixedNeeds.total,
          'Flexible Needs': categoryBasedBudget.flexibleNeeds.total,
          'Remaining': categoryBasedBudget.remainingBudget,
        },
        totalNetIncome: monthlyNetIncome,
        recommendation: _generateCategoryBasedRecommendation(categoryBasedBudget),
      );

      // Alternative frameworks (keeping for compatibility, but not used in new logic)
      final alternativeFrameworks = <FrameworkAnalysis>[];

      // Calculate allocations based on category-based budget
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

      // Create daily allocations from flexible needs
      final dailyAllocations = <DailyAllocation>[];
      if (categoryBasedBudget.flexibleNeeds.food > 0) {
        dailyAllocations.add(DailyAllocation(
          category: 'Food',
          dailyAmount: categoryBasedBudget.flexibleNeeds.food / daysInMonth,
          icon: '🍽',
          description: 'Daily food budget based on previous spending patterns',
        ));
      }
      if (categoryBasedBudget.flexibleNeeds.transport > 0) {
        dailyAllocations.add(DailyAllocation(
          category: 'Transportation',
          dailyAmount: categoryBasedBudget.flexibleNeeds.transport / daysInMonth,
          icon: '🚗',
          description: 'Daily transportation budget based on previous spending patterns',
        ));
      }

      // Create monthly allocations from fixed needs
      final monthlyAllocations = <MonthlyAllocation>[];
      if (categoryBasedBudget.fixedNeeds.housingAndUtilities > 0) {
        monthlyAllocations.add(MonthlyAllocation(
          category: 'Housing & Utilities',
          monthlyAmount: categoryBasedBudget.fixedNeeds.housingAndUtilities,
          icon: '🏠',
          description: 'Fixed housing and utilities expenses',
          isFixed: true,
        ));
      }
      if (categoryBasedBudget.fixedNeeds.debt > 0) {
        monthlyAllocations.add(MonthlyAllocation(
          category: 'Debt',
          monthlyAmount: categoryBasedBudget.fixedNeeds.debt,
          icon: '💳',
          description: 'Fixed debt payments',
          isFixed: true,
        ));
      }
      if (categoryBasedBudget.fixedNeeds.groceries > 0) {
        monthlyAllocations.add(MonthlyAllocation(
          category: 'Groceries',
          monthlyAmount: categoryBasedBudget.fixedNeeds.groceries,
          icon: '🛒',
          description: 'Fixed grocery expenses',
          isFixed: true,
        ));
      }
      if (categoryBasedBudget.fixedNeeds.healthAndPersonalCare > 0) {
        monthlyAllocations.add(MonthlyAllocation(
          category: 'Health and Personal Care',
          monthlyAmount: categoryBasedBudget.fixedNeeds.healthAndPersonalCare,
          icon: '🏥',
          description: 'Fixed health and personal care expenses',
          isFixed: true,
        ));
      }
      if (categoryBasedBudget.fixedNeeds.education > 0) {
        monthlyAllocations.add(MonthlyAllocation(
          category: 'Education',
          monthlyAmount: categoryBasedBudget.fixedNeeds.education,
          icon: '📚',
          description: 'Fixed education expenses',
          isFixed: true,
        ));
      }
      if (categoryBasedBudget.fixedNeeds.childcare > 0) {
        monthlyAllocations.add(MonthlyAllocation(
          category: 'Childcare',
          monthlyAmount: categoryBasedBudget.fixedNeeds.childcare,
          icon: '👶',
          description: 'Fixed childcare expenses',
          isFixed: true,
        ));
      }

      // Budget adjustments are already handled in the category-based calculation
      final adjustedDailyAllocations = dailyAllocations;
      final adjustedMonthlyAllocations = monthlyAllocations;
      
      // Get current month spending
      final currentMonthSpending = await _getCurrentMonthSpending(currentMonth);

      // Generate budgeting tips based on category-based budget
      final budgetingTips = _generateCategoryBasedBudgetingTips(
        categoryBasedBudget,
        dataAnalysis.categorySpending,
        currentMonthSpending,
        adjustedDailyAllocations,
        adjustedMonthlyAllocations,
        currentMonth,
        user,
      );
      
      // Add motivational nudges based on data completeness
      final motivationalNudges = _generateMotivationalNudges(dataSelection);
      budgetingTips.addAll(motivationalNudges);

      // Get recent spending history for behavior adjustments
      final spendingHistory = await _getRecentSpendingHistory(currentMonth);
      
      // Calculate behavior adjustments based on spending patterns
      final behaviorAdjustments = DailyAllocationService.calculateBehaviorAdjustments(
        adjustedDailyAllocations,
        spendingHistory,
        now,
      );

      // Create the complete budget prescription
      return BudgetPrescription(
        id: '${user.id}_${currentMonth.year}_${currentMonth.month}',
        month: currentMonth,
        monthlyNetIncome: monthlyNetIncome,
        confidence: dataAnalysis.confidence,
        dataCompleteness: dataAnalysis.dataCompleteness,
        dataSourceMonth: selectedDataMonth,
        dataSourceReason: dataSelection.selectionReason,
        previousMonthSpending: dataAnalysis.categorySpending,
        daysFilled: dataAnalysis.daysFilled,
        totalDaysInMonth: dataAnalysis.totalDaysInMonth,
        recommendedFramework: recommendedFramework,
        alternativeFrameworks: alternativeFrameworks,
        dailyAllocations: adjustedDailyAllocations,
        monthlyAllocations: adjustedMonthlyAllocations,
        budgetingTips: budgetingTips,
        behaviorAdjustments: behaviorAdjustments,
        currentMonthSpending: currentMonthSpending,
        lastUpdated: DateTime.now(),
      );

    } catch (e) {
      return null;
    }
  }

  /// Generate recommendation text for category-based budget
  static String _generateCategoryBasedRecommendation(CategoryBasedBudgetAnalysis budget) {
    final recommendations = <String>[];

    if (budget.isSustainable) {
      recommendations.add('Your budget is sustainable with the new category-based approach.');
      if (budget.remainingBudget > 0) {
        recommendations.add('You have ₱${budget.remainingBudget.toStringAsFixed(0)} remaining for unallocated expenses.');
      }
    } else {
      recommendations.add('Your budget exceeds net income. Consider increasing income or reducing fixed expenses.');
    }

    if (budget.warnings.isNotEmpty) {
      recommendations.addAll(budget.warnings);
    }

    if (budget.adjustments.isNotEmpty) {
      recommendations.addAll(budget.adjustments);
    }

    return recommendations.join(' ');
  }

  /// Generate budgeting tips for category-based budget
  static List<BudgetingTip> _generateCategoryBasedBudgetingTips(
    CategoryBasedBudgetAnalysis budget,
    Map<String, double> previousSpending,
    Map<String, double> currentSpending,
    List<DailyAllocation> dailyAllocations,
    List<MonthlyAllocation> monthlyAllocations,
    DateTime currentMonth,
    User? user,
  ) {
    final tips = <BudgetingTip>[];

    // Add warnings as tips
    for (final warning in budget.warnings) {
      tips.add(BudgetingTip(
        category: 'Budget Alert',
        title: 'Budget Warning',
        message: warning,
        action: 'Review your budget allocations and spending patterns.',
        icon: '⚠',
      ));
    }

    // Add adjustments as tips
    for (final adjustment in budget.adjustments) {
      tips.add(BudgetingTip(
        category: 'Budget Adjustment',
        title: 'Budget Modified',
        message: adjustment,
        action: 'Your budget has been adjusted to fit within your net income.',
        icon: '🔄',
      ));
    }

    // Add category-specific tips
    if (budget.fixedNeeds.total > 0) {
      tips.add(BudgetingTip(
        category: 'Fixed Needs',
        title: 'Fixed Expenses',
        message: 'Your fixed needs total ₱${budget.fixedNeeds.total.toStringAsFixed(0)} per month.',
        action: 'These are essential expenses that should be prioritized.',
        icon: '🏠',
      ));
    }

    if (budget.flexibleNeeds.total > 0) {
      tips.add(BudgetingTip(
        category: 'Flexible Needs',
        title: 'Flexible Budget',
        message: 'Food: ₱${budget.flexibleNeeds.food.toStringAsFixed(0)}, Transport: ₱${budget.flexibleNeeds.transport.toStringAsFixed(0)}.',
        action: 'Monitor these categories closely as they can vary.',
        icon: '🍽',
      ));
    }

    if (budget.remainingBudget > 0) {
      tips.add(BudgetingTip(
        category: 'Remaining Budget',
        title: 'Unallocated Funds',
        message: 'You have ₱${budget.remainingBudget.toStringAsFixed(0)} remaining after essential expenses.',
        action: 'Consider saving this amount or allocating to wants categories.',
        icon: '💰',
      ));
    }

    // Add motivational nudges based on data completeness (reuse existing logic)
    final dataSelection = MonthDataSelectionResult(
      selectedMonth: currentMonth,
      categorySpending: previousSpending,
      daysWithData: 30, // Assume full month for simplicity
      totalDaysInMonth: 30,
      dataCompleteness: 100.0,
      transactionCount: 100,
      selectionReason: 'Current month data',
      ruleApplied: BudgetDataSelectionRule.carryForward,
    );
    tips.addAll(_generateMotivationalNudges(dataSelection));

    return tips.take(5).toList(); // Limit to 5 tips
  }

  /// Generate motivational nudges based on data completeness
  static List<BudgetingTip> _generateMotivationalNudges(MonthDataSelectionResult dataSelection) {
    final tips = <BudgetingTip>[];
    final completeness = dataSelection.dataCompleteness;
    
    if (completeness >= 60 && completeness < 70) {
      tips.add(const BudgetingTip(
        category: 'Motivation',
        title: 'Almost There!',
        message: 'You\'re close to a strong budget!',
        action: 'Log a few more days to reach 70% for a more reliable budget.',
        icon: '💪',
      ));
    } else if (completeness >= 70 && completeness < 80) {
      tips.add(const BudgetingTip(
        category: 'Motivation',
        title: 'Great Job!',
        message: 'You\'re doing well with your budget tracking!',
        action: 'To make this month reliable and carry-over ready, aim for 80% data completeness.',
        icon: '👏',
      ));
    } else if (completeness >= 80) {
      tips.add(const BudgetingTip(
        category: 'Motivation',
        title: 'Excellent Work!',
        message: 'This month\'s data is reliable!',
        action: 'Your data will be used for future budgets if needed.',
        icon: '🏆',
      ));
    }
    
    return tips;
  }

  /// Determine confidence level based on data selection result
  static ConfidenceLevel _determineConfidence(MonthDataSelectionResult dataSelection) {
    // Higher confidence for reliable data (80%+ or 25+ transactions)
    if (dataSelection.dataCompleteness >= 80 || dataSelection.transactionCount >= 25) {
      return ConfidenceLevel.high;
    }
    
    // Medium-high confidence for strong data (70%+ or 20+ transactions)
    if (dataSelection.dataCompleteness >= 70 || dataSelection.transactionCount >= 20) {
      return ConfidenceLevel.medium; // We'll use medium for now, but could add medium-high if needed
    }
    
    // Medium confidence for usable data (50%+ or 15+ transactions)
    if (dataSelection.dataCompleteness >= 50 || dataSelection.transactionCount >= 15) {
      return ConfidenceLevel.medium;
    }
    
    // Low confidence for insufficient data
    return ConfidenceLevel.low;
  }

  /// Calculate monthly net income from user data or transactions
  static Future<double> _calculateMonthlyNetIncome(User user, DateTime month) async {
    // First try to use user's declared monthly net income (preferred)
    if (user.monthlyNet != null && user.monthlyNet! > 0) {
      return user.monthlyNet!;
    }

    // Fallback to monthlyIncome if monthlyNet is not set
    if (user.monthlyIncome > 0) {
      return user.monthlyIncome;
    }

    // Otherwise, calculate from previous month's income transactions
    final transactions = await _cacheService.getMonthlyTransactions(month);
    final income = transactions
        .where((t) => 
            (t.type == TransactionType.income && 
             t.category != 'Debt Income' && 
             t.category != 'Emergency Fund Withdrawal') ||
            t.type == TransactionType.debt ||
            t.type == TransactionType.emergencyFundWithdrawal)
        .fold(0.0, (total, t) => total + t.amount);

    // If no income data, use a reasonable default based on expenses
    if (income == 0) {
      final expenses = transactions
          .where((t) => t.type == TransactionType.expense || t.type == TransactionType.recurringExpense)
          .fold(0.0, (total, t) => total + t.amount);
      
      // Assume income is 120% of expenses (reasonable margin)
      final estimatedIncome = expenses * 1.2;
      return estimatedIncome;
    }

    return income;
  }

  /// Get current month spending by category
  static Future<Map<String, double>> _getCurrentMonthSpending(DateTime month) async {
    final transactions = await _cacheService.getMonthlyTransactions(month);
    final categorySpending = <String, double>{};

    for (final transaction in transactions) {
      if (transaction.type == TransactionType.expense || transaction.type == TransactionType.recurringExpense) {
        categorySpending[transaction.category] = 
          (categorySpending[transaction.category] ?? 0) + transaction.amount;
      }
    }

    return categorySpending;
  }

  /// Get recent daily spending history for behavior adjustments
  static Future<Map<DateTime, double>> _getRecentSpendingHistory(DateTime month) async {
    final transactions = await _cacheService.getMonthlyTransactions(month);
    final dailySpending = <DateTime, double>{};

    for (final transaction in transactions) {
      if (transaction.type == TransactionType.expense) {
        final date = DateTime(transaction.date.year, transaction.date.month, transaction.date.day);
        dailySpending[date] = (dailySpending[date] ?? 0) + transaction.amount;
      }
    }

    return dailySpending;
  }

  /// Save prescription to Firebase
  static Future<bool> saveBudgetPrescription(BudgetPrescription prescription) async {
    try {
      final userId = FirebaseService.currentUserId;
      if (userId == null) return false;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('budget_prescriptions')
          .doc(prescription.id)
          .set(prescription.toJson());

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get saved prescription for a specific month
  static Future<BudgetPrescription?> getBudgetPrescription(DateTime month) async {
    try {
      final userId = FirebaseService.currentUserId;
      if (userId == null) return null;

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('budget_prescriptions')
          .where('month', isEqualTo: DateTime(month.year, month.month, 1).toIso8601String())
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return BudgetPrescription.fromJson(snapshot.docs.first.data());
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check if user has any existing budget prescriptions
  static Future<bool> hasExistingPrescriptions() async {
    try {
      final userId = FirebaseService.currentUserId;
      if (userId == null) return false;

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('budget_prescriptions')
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Update prescription with current month data
  static Future<BudgetPrescription?> updatePrescriptionWithCurrentData(
    BudgetPrescription prescription
  ) async {
    final currentMonthSpending = await _getCurrentMonthSpending(prescription.month);
    final spendingHistory = await _getRecentSpendingHistory(prescription.month);

    final behaviorAdjustments = DailyAllocationService.calculateBehaviorAdjustments(
      prescription.dailyAllocations,
      spendingHistory,
      DateTime.now(),
    );

    // Get user data for enhanced budgeting tips
    final user = await FirebaseService.getUser();

    final updatedBudgetingTips = BudgetFrameworkService.generateBudgetingTips(
      prescription.recommendedFramework,
      prescription.previousMonthSpending,
      currentMonthSpending,
      dailyAllocations: prescription.dailyAllocations,
      monthlyAllocations: prescription.monthlyAllocations,
      currentMonth: prescription.month,
      user: user,
    );

    return prescription.copyWith(
      currentMonthSpending: currentMonthSpending,
      behaviorAdjustments: behaviorAdjustments,
      budgetingTips: updatedBudgetingTips,
      lastUpdated: DateTime.now(),
    );
  }

  /// Invalidate prescriptions that use the specified month as data source
  /// This should be called when transactions are added/deleted in a month that could affect prescriptions
  static Future<void> invalidatePrescriptionsUsingDataSourceMonth(DateTime dataSourceMonth) async {
    try {
      final userId = FirebaseService.currentUserId;
      if (userId == null) return;

      final dataSourceMonthString = DateTime(dataSourceMonth.year, dataSourceMonth.month, 1).toIso8601String();

      // Query prescriptions where dataSourceMonth matches
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('budget_prescriptions')
          .where('dataSourceMonth', isEqualTo: dataSourceMonthString)
          .get();

      // Delete matching prescriptions
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }

      // Also invalidate preloaded data
      BudgetPreloaderService.invalidatePreloadedData();
    } catch (e) {
      // Silent error handling
    }
  }
}

/// Internal class for previous month analysis results
class _PreviousMonthAnalysis {
  final Map<String, double> categorySpending;
  final int daysFilled;
  final int totalDaysInMonth;
  final double dataCompleteness;
  final ConfidenceLevel confidence;
  final int transactionCount;

  _PreviousMonthAnalysis({
    required this.categorySpending,
    required this.daysFilled,
    required this.totalDaysInMonth,
    required this.dataCompleteness,
    required this.confidence,
    required this.transactionCount,
  });
}