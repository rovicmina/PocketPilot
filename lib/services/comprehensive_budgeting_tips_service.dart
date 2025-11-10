import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/user.dart' as user_models;
import '../models/budget_prescription.dart';
import 'budget_strategy_tips_service.dart';
import 'budget_prescription_service.dart';
import 'budget_framework_service.dart';

/// Enum for different budgeting frameworks
enum BudgetingFramework {
  debtHeavyRecovery, // 70/20/10
  familyCentric,     // 60/25/15
  riskControl,       // 40/40/20
  balanced,          // 50/30/20
  builder,           // 60/20/20
  conservative,      // 75/10/15
  pocketPilotGeneral, // General tips
  motivational,      // Motivational tips
}

/// Tip category types
enum TipCategory {
  general,
  spending,
  savings,
}

/// Comprehensive budgeting tip structure
class ComprehensiveBudgetingTip {
  final String title;
  final String message;
  final String icon;
  final BudgetingFramework framework;
  final TipCategory category;

  const ComprehensiveBudgetingTip({
    required this.title,
    required this.message,
    required this.icon,
    required this.framework,
    required this.category,
  });

  /// Remove gender prefix from title or message
  /// Only removes the prefix if it's at the beginning and followed by a space
  String _removeGenderPrefix(String text) {
    // Check for exact matches at the beginning of the string
    if (text.startsWith('Neutral: ')) {
      return text.substring(9); // Remove 'Neutral: ' (9 characters including space)
    } else if (text.startsWith('Male: ')) {
      return text.substring(6); // Remove 'Male: ' (6 characters including space)
    } else if (text.startsWith('Female: ')) {
      return text.substring(8); // Remove 'Female: ' (8 characters including space)
    }
    return text; // Return as is if no prefix
  }

  /// Convert to BudgetingTip for compatibility
  BudgetingTip toBudgetingTip({double? monthlyNet, CategoryBasedBudgetAnalysis? budgetAnalysis}) {
    String processedTitle = title;
    String processedMessage = message;
    
    // Remove gender prefixes from title and message
    processedTitle = _removeGenderPrefix(processedTitle);
    processedMessage = _removeGenderPrefix(processedMessage);
    
    // If we have budgetAnalysis, replace formulas with actual amounts
    if (budgetAnalysis != null) {
      processedTitle = _replaceFormulasWithActualAmounts(processedTitle, budgetAnalysis);
      processedMessage = _replaceFormulasWithActualAmounts(processedMessage, budgetAnalysis);
    } 
    // Fallback to monthlyNet if budgetAnalysis is not available
    else if (monthlyNet != null && monthlyNet > 0) {
      processedTitle = _replaceFormulasWithAmounts(processedTitle, monthlyNet);
      processedMessage = _replaceFormulasWithAmounts(processedMessage, monthlyNet);
    }
    
    return BudgetingTip(
      category: _getCategoryString(framework),
      title: processedTitle,
      message: processedMessage,
      action: '', // Action is included in message for comprehensive tips
      icon: icon,
    );
  }
  
  /// Replace formulas with actual user expense amounts
  String _replaceFormulasWithActualAmounts(String message, CategoryBasedBudgetAnalysis budgetAnalysis) {
    String result = message;
    
    // Get actual expense amounts from the budget analysis
    final fixedTotal = budgetAnalysis.fixedNeeds.total;
    final flexibleTotal = budgetAnalysis.flexibleNeeds.total;
    final housingAndUtilities = budgetAnalysis.fixedNeeds.housingAndUtilities;
    final debt = budgetAnalysis.fixedNeeds.debt;
    final groceries = budgetAnalysis.fixedNeeds.groceries;
    final healthAndPersonalCare = budgetAnalysis.fixedNeeds.healthAndPersonalCare;
    final education = budgetAnalysis.fixedNeeds.education;
    final childcare = budgetAnalysis.fixedNeeds.childcare;
    final food = budgetAnalysis.flexibleNeeds.food;
    final transport = budgetAnalysis.flexibleNeeds.transport;
    
    // Replace formulas with actual user expense amounts
    // We map generic percentage-based formulas to actual user expense categories
    final replacements = {
      // Fixed needs formulas
      '₱(monthlyNet × 0.70)': '₱${fixedTotal.toStringAsFixed(0)}',
      '₱(monthlyNet × 0.65)': '₱${(fixedTotal + food * 0.8).toStringAsFixed(0)}',
      '₱(monthlyNet × 0.60)': '₱${(fixedTotal + food * 0.6).toStringAsFixed(0)}',
      '₱(monthlyNet × 0.50)': '₱${(fixedTotal * 0.8).toStringAsFixed(0)}',
      '₱(monthlyNet × 0.40)': '₱${(fixedTotal * 0.6).toStringAsFixed(0)}',
      
      // Flexible needs formulas
      '₱(monthlyNet × 0.30)': '₱${flexibleTotal.toStringAsFixed(0)}',
      '₱(monthlyNet × 0.25)': '₱${(food * 0.7).toStringAsFixed(0)}',
      '₱(monthlyNet × 0.20)': '₱${(debt > 0 ? debt : transport * 0.8).toStringAsFixed(0)}',
      '₱(monthlyNet × 0.15)': '₱${groceries.toStringAsFixed(0)}',
      '₱(monthlyNet × 0.10)': '₱${(food * 0.3).toStringAsFixed(0)}',
      
      // Specific category formulas
      '₱(monthlyNet × 0.08)': '₱${(education > 0 ? education : transport * 0.5).toStringAsFixed(0)}',
      '₱(monthlyNet × 0.05)': '₱${(debt > 0 ? debt * 0.3 : transport * 0.3).toStringAsFixed(0)}',
      '₱(monthlyNet × 0.03)': '₱${(healthAndPersonalCare * 0.5).toStringAsFixed(0)}',
      '₱(monthlyNet × 0.02)': '₱${(debt > 0 ? debt * 0.1 : transport * 0.1).toStringAsFixed(0)}',
      '₱(monthlyNet × 0.01)': '₱${(debt > 0 ? debt * 0.05 : transport * 0.05).toStringAsFixed(0)}',
    };
    
    for (var entry in replacements.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    
    return result;
  }
  
  /// Replace formulas like ₱(monthlyNet × 0.20) with actual amounts
  String _replaceFormulasWithAmounts(String message, double monthlyNet) {
    String result = message;
    
    // Define all percentages used in the tips
    final percentages = [
      0.01, 0.02, 0.03, 0.05, 0.08, 0.10, 0.15, 0.20, 0.25, 0.30, 
      0.40, 0.50, 0.60, 0.65, 0.70, 0.75, 0.80, 0.85, 0.90, 0.95
    ];
    
    for (var percentage in percentages) {
      final amount = monthlyNet * percentage;
      final formattedAmount = '₱${amount.toStringAsFixed(0)}';
      // Format the percentage to match exactly what's in the tips (with 2 decimal places)
      final formattedPercentage = percentage.toStringAsFixed(2);
      final formula = '₱(monthlyNet × $formattedPercentage)';
      result = result.replaceAll(formula, formattedAmount);
    }
    
    return result;
  }

  String _getCategoryString(BudgetingFramework framework) {
    // For universal tips, use specific categories
    if (framework == BudgetingFramework.pocketPilotGeneral) {
      return 'App General';
    } else if (framework == BudgetingFramework.motivational) {
      return 'Motivational';
    }
    
    // For framework-specific tips, use the category enum
    switch (category) {
      case TipCategory.general:
        return 'General';
      case TipCategory.spending:
        return 'Spending';
      case TipCategory.savings:
        return 'Savings';
    }
  }
}

/// Service for managing comprehensive budgeting tips library
class ComprehensiveBudgetingTipsService {
  /// Get daily randomized tips based on user's framework
  static Future<List<BudgetingTip>> getDailyTips(user_models.User? user) async {
    final framework = _determineUserFramework(user);
    
    // Try to get actual budget analysis for personalized tips
    CategoryBasedBudgetAnalysis? budgetAnalysis;
    try {
      final prescription = await BudgetPrescriptionService.generateBudgetPrescription();
      if (prescription != null) {
        // Use the existing BudgetFrameworkService to create the analysis
        budgetAnalysis = await BudgetFrameworkService.calculateCategoryBasedBudget(
          prescription.monthlyNetIncome,
          prescription.previousMonthSpending,
          prescription.daysFilled,
          prescription.totalDaysInMonth,
          DateTime.now(), // base month
        );
      }
    } catch (e) {
      // If we can't get budget analysis, we'll fall back to using monthlyNet
    }

    final tips = <BudgetingTip>[];

    // Framework tips (3 tips)
    tips.addAll(await _getFrameworkTips(framework, user, budgetAnalysis));

    // Universal tips (2 tips)
    tips.addAll(await _getUniversalTips(user, budgetAnalysis));

    return tips;
  }

  // DECISION TREE START: Framework Selection Logic - Maps user characteristics to appropriate budgeting framework
  /// Determine user's budgeting framework
  static BudgetingFramework _determineUserFramework(user_models.User? user) {
    if (user == null) return BudgetingFramework.balanced;

    // Use existing strategy determination logic
    final strategy = BudgetStrategyTipsService.determineBudgetStrategy(user);

    switch (strategy) {
      case BudgetStrategy.debtHeavyRecovery:
        return BudgetingFramework.debtHeavyRecovery; // 70/20/10 - Debt-focused recovery
      case BudgetStrategy.familyCentric:
        return BudgetingFramework.familyCentric; // 60/25/15 - Family-oriented planning
      case BudgetStrategy.riskControl:
        return BudgetingFramework.riskControl; // 40/40/20 - Risk management
      case BudgetStrategy.balanced:
        return BudgetingFramework.balanced; // 50/30/20 - Default balanced approach
      case BudgetStrategy.builder:
        return BudgetingFramework.builder; // 60/20/20 - Wealth building focus
      case BudgetStrategy.conservative:
        return BudgetingFramework.conservative; // 75/10/15 - Conservative approach
      // Survival strategy removed as it's not being used in the app
    }
  }
  // DECISION TREE END: Framework Selection Logic

  /// Get framework-specific tips (1 general, 1 spending, 1 savings)
  static Future<List<BudgetingTip>> _getFrameworkTips(
      BudgetingFramework framework, user_models.User? user, CategoryBasedBudgetAnalysis? budgetAnalysis) async {
    final tips = <BudgetingTip>[];
    final monthlyNet = user?.monthlyNet;

    // Get randomized tips for each category
    final generalTip = _getRandomTip(framework, TipCategory.general, user);
    final spendingTip = _getRandomTip(framework, TipCategory.spending, user);
    final savingsTip = _getRandomTip(framework, TipCategory.savings, user);

    if (generalTip != null) {
      tips.add(generalTip.toBudgetingTip(monthlyNet: monthlyNet, budgetAnalysis: budgetAnalysis));
    }
    if (spendingTip != null) {
      tips.add(spendingTip.toBudgetingTip(monthlyNet: monthlyNet, budgetAnalysis: budgetAnalysis));
    }
    if (savingsTip != null) {
      tips.add(savingsTip.toBudgetingTip(monthlyNet: monthlyNet, budgetAnalysis: budgetAnalysis));
    }

    return tips;
  }

  /// Get universal tips (1 general, 1 motivational)
  static Future<List<BudgetingTip>> _getUniversalTips(
      user_models.User? user, CategoryBasedBudgetAnalysis? budgetAnalysis) async {
    final tips = <BudgetingTip>[];
    final monthlyNet = user?.monthlyNet;

    final generalTip = _getRandomTip(BudgetingFramework.pocketPilotGeneral, TipCategory.general, user);
    final motivationalTip = _getRandomTip(BudgetingFramework.motivational, TipCategory.general, user);

    if (generalTip != null) {
      tips.add(generalTip.toBudgetingTip(monthlyNet: monthlyNet, budgetAnalysis: budgetAnalysis));
    }
    if (motivationalTip != null) {
      tips.add(motivationalTip.toBudgetingTip(monthlyNet: monthlyNet, budgetAnalysis: budgetAnalysis));
    }

    return tips;
  }

  /// Get a random tip for specific framework and category
  static ComprehensiveBudgetingTip? _getRandomTip(BudgetingFramework framework, TipCategory category, user_models.User? user) {
    final tips = _getTipsForFrameworkAndCategory(framework, category, user);
    if (tips.isEmpty) return null;

    // Use date-based randomization for consistency within the day
    final today = DateTime.now();
    final seed = today.year * 10000 + today.month * 100 + today.day + framework.index * 10 + category.index;
    final random = Random(seed);

    return tips[random.nextInt(tips.length)];
  }

  /// Get all tips for a specific framework and category
  static List<ComprehensiveBudgetingTip> _getTipsForFrameworkAndCategory(
    BudgetingFramework framework,
    TipCategory category,
    user_models.User? user
  ) {
    // For family-centric framework, we need to filter based on number of children
    if (framework == BudgetingFramework.familyCentric && user != null) {
      // Get the number of children
      final numberOfChildren = user.numberOfChildren;
      
      // Filter tips based on family size tiers
      if (numberOfChildren != null) {
        // Tier 1: Small Families (1-2 children) - 60/25/15
        if (numberOfChildren >= 1 && numberOfChildren <= 2) {
          var filteredTips = _allTips.where((tip) =>
            tip.framework == framework && 
            tip.category == category &&
            _isSmallFamilyTip(tip) &&
            _matchesUserGender(tip, user.gender)
          ).toList();
          
          // If no gender-specific tips are found, fall back to neutral tips
          if (filteredTips.isEmpty) {
            filteredTips = _allTips.where((tip) =>
              tip.framework == framework && 
              tip.category == category &&
              _isSmallFamilyTip(tip) &&
              (tip.title.startsWith('Neutral: ') || tip.message.startsWith('Neutral: '))
            ).toList();
          }
          
          return filteredTips;
        }
        // Tier 2: Growing Families (3-5 children) - 65/20/15
        else if (numberOfChildren >= 3 && numberOfChildren <= 5) {
          var filteredTips = _allTips.where((tip) =>
            tip.framework == framework && 
            tip.category == category &&
            _isGrowingFamilyTip(tip) &&
            _matchesUserGender(tip, user.gender)
          ).toList();
          
          // If no gender-specific tips are found, fall back to neutral tips
          if (filteredTips.isEmpty) {
            filteredTips = _allTips.where((tip) =>
              tip.framework == framework && 
              tip.category == category &&
              _isGrowingFamilyTip(tip) &&
              (tip.title.startsWith('Neutral: ') || tip.message.startsWith('Neutral: '))
            ).toList();
          }
          
          return filteredTips;
        }
        // Tier 3: Large Families (6+ children) - 70/15/15
        else if (numberOfChildren >= 6) {
          var filteredTips = _allTips.where((tip) =>
            tip.framework == framework && 
            tip.category == category &&
            _isLargeFamilyTip(tip) &&
            _matchesUserGender(tip, user.gender)
          ).toList();
          
          // If no gender-specific tips are found, fall back to neutral tips
          if (filteredTips.isEmpty) {
            filteredTips = _allTips.where((tip) =>
              tip.framework == framework && 
              tip.category == category &&
              _isLargeFamilyTip(tip) &&
              (tip.title.startsWith('Neutral: ') || tip.message.startsWith('Neutral: '))
            ).toList();
          }
          
          return filteredTips;
        }
      } else {
        // Default to small family tips if numberOfChildren is not specified
        var filteredTips = _allTips.where((tip) =>
          tip.framework == framework && 
          tip.category == category &&
          _isSmallFamilyTip(tip) &&
          _matchesUserGender(tip, user.gender)
        ).toList();
        
        // If no gender-specific tips are found, fall back to neutral tips
        if (filteredTips.isEmpty) {
          filteredTips = _allTips.where((tip) =>
            tip.framework == framework && 
            tip.category == category &&
            _isSmallFamilyTip(tip) &&
            (tip.title.startsWith('Neutral: ') || tip.message.startsWith('Neutral: '))
          ).toList();
        }
        
        return filteredTips;
      }
    }
    
    // Filter tips based on user's gender for general and motivational tips
    if ((framework == BudgetingFramework.pocketPilotGeneral || 
         framework == BudgetingFramework.motivational ||
         category == TipCategory.general) && 
        user != null) {
      var filteredTips = _allTips.where((tip) =>
        tip.framework == framework && 
        tip.category == category &&
        _matchesUserGender(tip, user.gender)
      ).toList();
      
      // If no gender-specific tips are found, fall back to neutral tips
      if (filteredTips.isEmpty) {
        filteredTips = _allTips.where((tip) =>
          tip.framework == framework && 
          tip.category == category &&
          (tip.title.startsWith('Neutral: ') || tip.message.startsWith('Neutral: '))
        ).toList();
      }
      
      return filteredTips;
    }
    
    return _allTips.where((tip) =>
      tip.framework == framework && tip.category == category
    ).toList();
  }
  
  /// Check if a tip matches the user's gender
  static bool _matchesUserGender(ComprehensiveBudgetingTip tip, user_models.Gender? userGender) {
    // If user gender is not specified, show all tips
    if (userGender == null) {
      return true;
    }
    
    final title = tip.title;
    final message = tip.message;
    
    // If the tip is gender-neutral (starts with "Neutral: "), it should be included for all users
    final isNeutral = title.startsWith('Neutral: ') || message.startsWith('Neutral: ');
    
    // If the tip is male-specific (starts with "Male: "), it should only be included for male users
    final isMale = title.startsWith('Male: ') || message.startsWith('Male: ');
    
    // If the tip is female-specific (starts with "Female: "), it should only be included for female users
    final isFemale = title.startsWith('Female: ') || message.startsWith('Female: ');
    
    // Return based on user's gender - show only gender-specific tips, not neutral ones
    switch (userGender) {
      case user_models.Gender.male:
        return isMale; // Only show male-specific tips to male users
      case user_models.Gender.female:
        return isFemale; // Only show female-specific tips to female users
      default:
        return isNeutral; // For other genders, only show neutral tips
    }
  }
  
  /// Check if a tip is for small families (1-2 children)
  static bool _isSmallFamilyTip(ComprehensiveBudgetingTip tip) {
    // Small family tips don't have specific markers, but they're the default
    // We'll identify them by the absence of markers for other tiers
    final title = tip.title.toLowerCase();
    final message = tip.message.toLowerCase();
    
    // Check if this is explicitly a growing or large family tip
    final isGrowingFamilyTip = title.contains('growing') || title.contains('3–5') || 
                              message.contains('3–5') || message.contains('3-5');
    final isLargeFamilyTip = title.contains('large') || title.contains('6+') || 
                            message.contains('6+') || message.contains('big families');
    
    return !isGrowingFamilyTip && !isLargeFamilyTip;
  }
  
  /// Check if a tip is for growing families (3-5 children)
  static bool _isGrowingFamilyTip(ComprehensiveBudgetingTip tip) {
    final title = tip.title.toLowerCase();
    final message = tip.message.toLowerCase();
    
    return title.contains('growing') || title.contains('3–5') || 
           message.contains('3–5') || message.contains('3-5');
  }
  
  /// Check if a tip is for large families (6+ children)
  static bool _isLargeFamilyTip(ComprehensiveBudgetingTip tip) {
    final title = tip.title.toLowerCase();
    final message = tip.message.toLowerCase();
    
    return title.contains('large') || title.contains('6+') || 
           message.contains('6+') || message.contains('big families');
  }

  /// Complete library of comprehensive budgeting tips
  static final List<ComprehensiveBudgetingTip> _allTips = [
    // Debt Heavy Recovery Framework (70/20/10)
    // For users focusing on paying off debt fast
    // General tips - gender based
    ComprehensiveBudgetingTip(
      title: 'Neutral: You’re not stuck — you’re staging a comeback.',
      message: 'Neutral: Treat debt like a challenge you’re built to overcome.',
      icon: '🟥',
      framework: BudgetingFramework.debtHeavyRecovery,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: You’re regaining control — rebuild your strength with discipline.',
      message: 'Male: Treat debt as a test of persistence — you’re built to conquer it.',
      icon: '🟥',
      framework: BudgetingFramework.debtHeavyRecovery,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: You’re rising stronger — this is your chance to reclaim your freedom.',
      message: 'Female: See debt as a hurdle you’re strong enough to rise above.',
      icon: '🟥',
      framework: BudgetingFramework.debtHeavyRecovery,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Progress isn’t about perfection — it’s about direction.',
      message: 'Neutral: Every payment is proof you’re winning your fight.',
      icon: '🟥',
      framework: BudgetingFramework.debtHeavyRecovery,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Keep moving forward — focus beats perfection every time.',
      message: 'Male: Each payment shows your strength and determination.',
      icon: '🟥',
      framework: BudgetingFramework.debtHeavyRecovery,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Keep progressing — growth matters more than flawlessness.',
      message: 'Female: Every payment proves your commitment and courage.',
      icon: '🟥',
      framework: BudgetingFramework.debtHeavyRecovery,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Discipline now means freedom later.',
      message: 'Neutral: You’re not stuck — you’re staging a comeback.',
      icon: '🟥',
      framework: BudgetingFramework.debtHeavyRecovery,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: The man who practices control earns his freedom early.',
      message: 'Male: You’re regaining control — rebuild your strength with discipline.',
      icon: '🟥',
      framework: BudgetingFramework.debtHeavyRecovery,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Your patience and discipline now buy tomorrow’s peace.',
      message: 'Female: You’re rising stronger — this is your chance to reclaim your freedom.',
      icon: '🟥',
      framework: BudgetingFramework.debtHeavyRecovery,
      category: TipCategory.general,
    ),

    ComprehensiveBudgetingTip(
      title: 'Food, Groceries – ₱(monthlyNet × 0.25)',
      message: 'Cook simple, fuel your goals, not cravings.',
      icon: '🟥',
      framework: BudgetingFramework.debtHeavyRecovery,
      category: TipCategory.spending,
    ),
    ComprehensiveBudgetingTip(
      title: 'Transportation – ₱(monthlyNet × 0.10)',
      message: 'Move with purpose, save with intention.',
      icon: '🟥',
      framework: BudgetingFramework.debtHeavyRecovery,
      category: TipCategory.spending,
    ),
    ComprehensiveBudgetingTip(
      title: 'Essentials (Housing & Utilities) – ₱(monthlyNet × 0.35)',
      message: 'Keep your foundation steady.',
      icon: '🟥',
      framework: BudgetingFramework.debtHeavyRecovery,
      category: TipCategory.spending,
    ),
    ComprehensiveBudgetingTip(
      title: 'Debt Payment – ₱(monthlyNet × 0.20)',
      message: 'Prioritize paydown — your future self thanks you.',
      icon: '🟥',
      framework: BudgetingFramework.debtHeavyRecovery,
      category: TipCategory.spending,
    ),
    ComprehensiveBudgetingTip(
      title: 'Savings – ₱(monthlyNet × 0.10)',
      message: 'Save first, spend later — security before comfort.',
      icon: '🟥',
      framework: BudgetingFramework.debtHeavyRecovery,
      category: TipCategory.spending,
    ),

    ComprehensiveBudgetingTip(
      title: 'Emergency Fund – ₱(monthlyNet × 0.10)',
      message: 'Protect yourself from slipping back into debt.',
      icon: '🟥',
      framework: BudgetingFramework.debtHeavyRecovery,
      category: TipCategory.savings,
    ),
    ComprehensiveBudgetingTip(
      title: 'Save ₱(monthlyNet × 0.20) like your peace of mind depends on it — because it does.',
      message: 'Even small savings are victories — consistency beats amount.',
      icon: '🟥',
      framework: BudgetingFramework.debtHeavyRecovery,
      category: TipCategory.savings,
    ),
    ComprehensiveBudgetingTip(
      title: 'Even small savings are victories — consistency beats amount.',
      message: 'Emergency Fund – ₱(monthlyNet × 0.10): Protect yourself from slipping back into debt.',
      icon: '🟥',
      framework: BudgetingFramework.debtHeavyRecovery,
      category: TipCategory.savings,
    ),
    ComprehensiveBudgetingTip(
      title: 'Save first, spend later — security before comfort.',
      message: 'Save ₱(monthlyNet × 0.20) like your peace of mind depends on it — because it does.',
      icon: '🟥',
      framework: BudgetingFramework.debtHeavyRecovery,
      category: TipCategory.savings,
    ),
    ComprehensiveBudgetingTip(
      title: 'Prioritize paydown — your future self thanks you.',
      message: 'Even small savings are victories — consistency beats amount.',
      icon: '🟥',
      framework: BudgetingFramework.debtHeavyRecovery,
      category: TipCategory.savings,
    ),

    // Family Centric Framework - Tier 1 (1-2 children) - 60/25/15
    // For families balancing essentials, bonding, and future goals
    // Small Families (1–2 kids)
    // General tips - gender based
    ComprehensiveBudgetingTip(
      title: 'Neutral: Strong families plan together — teamwork multiplies peace.',
      message: 'Neutral: Money lessons start at home.',
      icon: '💜',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Lead with example — unity starts with you.',
      message: 'Male: Be the teacher — your kids will follow your habits.',
      icon: '💜',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Guide with care — teamwork keeps your family strong.',
      message: 'Female: Teach through example — your children watch and learn.',
      icon: '💜',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Money lessons start at home.',
      message: 'Neutral: Teach saving as early as you teach sharing.',
      icon: '💜',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Show your kids that saving builds strength and pride.',
      message: 'Male: Provide through purpose — peace comes from preparation.',
      icon: '💜',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Raise savers — every little habit shapes their future.',
      message: 'Female: Plan with love — care and structure build harmony.',
      icon: '💜',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Teach saving as early as you teach sharing.',
      message: 'Neutral: Love grows through planning, not pressure.',
      icon: '💜',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Acknowledge progress — it strengthens your bond.',
      message: 'Male: Lead with example — unity starts with you.',
      icon: '💜',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Celebrate growth — joy keeps your family united.',
      message: 'Female: Guide with care — teamwork keeps your family strong.',
      icon: '💜',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.general,
    ),

    ComprehensiveBudgetingTip(
      title: 'Food, Groceries – ₱(monthlyNet × 0.25)',
      message: 'Cook together — bonding and budgeting in one.',
      icon: '💜',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.spending,
    ),
    ComprehensiveBudgetingTip(
      title: 'Transportation – ₱(monthlyNet × 0.08)',
      message: 'Plan trips, save fuel.',
      icon: '💜',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.spending,
    ),
    ComprehensiveBudgetingTip(
      title: 'Essentials (Housing & Utilities) – ₱(monthlyNet × 0.17)',
      message: 'Stability means comfort for everyone.',
      icon: '💜',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.spending,
    ),
    ComprehensiveBudgetingTip(
      title: 'Education/Childcare – ₱(monthlyNet × 0.10)',
      message: 'Invest in your children’s growth.',
      icon: '💜',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.spending,
    ),
    ComprehensiveBudgetingTip(
      title: 'Savings – ₱(monthlyNet × 0.15)',
      message: 'Save for family stability and future.',
      icon: '💜',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.spending,
    ),

    ComprehensiveBudgetingTip(
      title: 'Family Emergency Fund – ₱(monthlyNet × 0.10)',
      message: 'Keep your safety net ready.',
      icon: '💜',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.savings,
    ),
    ComprehensiveBudgetingTip(
      title: 'Family Savings Fund – ₱(monthlyNet × 0.05)',
      message: 'Save for vacations or future upgrades.',
      icon: '💜',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.savings,
    ),
    ComprehensiveBudgetingTip(
      title: 'Every peso saved together builds stronger trust.',
      message: 'Family Emergency Fund – ₱(monthlyNet × 0.10): Keep your safety net ready.',
      icon: '💜',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.savings,
    ),
    ComprehensiveBudgetingTip(
      title: 'Keep your safety net ready.',
      message: 'Family Savings Fund – ₱(monthlyNet × 0.05): Save for vacations or future upgrades.',
      icon: '💜',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.savings,
    ),
    ComprehensiveBudgetingTip(
      title: 'Save for vacations or future upgrades.',
      message: 'Every peso saved together builds stronger trust.',
      icon: '💜',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.savings,
    ),

    // Growing Families (3–5 kids) - Tier 2 - 65/20/15
    // General tips - gender based
    ComprehensiveBudgetingTip(
      title: 'Neutral: Budgeting together teaches fairness and unity.',
      message: 'Neutral: Structure brings peace — predictability helps everyone.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Lead fair — your guidance shapes their values.',
      message: 'Male: Create order — your consistency keeps the family steady.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Plan together — shared fairness keeps peace at home.',
      message: 'Female: Maintain structure — routine helps your family thrive.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Structure brings peace — predictability helps everyone.',
      message: 'Neutral: Focus on needs first; joy follows security.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Provide for essentials — joy grows from stability.',
      message: 'Male: Focus on needs first; joy follows security.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Prioritize needs — peace follows when the basics are met.',
      message: 'Female: Teach kids to value priorities, not prices.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Focus on needs first; joy follows security.',
      message: 'Neutral: Teach kids to value priorities, not prices.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Lead with clarity — order brings calm.',
      message: 'Male: Create order — your consistency keeps the family steady.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Plan with intention — your calm guides the home.',
      message: 'Female: Maintain structure — routine helps your family thrive.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.general,
    ),

    ComprehensiveBudgetingTip(
      title: 'Food, Groceries – ₱(monthlyNet × 0.30)',
      message: 'Cook in bulk and stretch meals smartly.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.spending,
    ),
    ComprehensiveBudgetingTip(
      title: 'Transportation – ₱(monthlyNet × 0.08)',
      message: 'Share rides and plan errands.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.spending,
    ),
    ComprehensiveBudgetingTip(
      title: 'Essentials (Housing & Utilities) – ₱(monthlyNet × 0.17)',
      message: 'Consistency over luxury.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.spending,
    ),
    ComprehensiveBudgetingTip(
      title: 'Education/Health – ₱(monthlyNet × 0.10)',
      message: 'Secure the future while nurturing today.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.spending,
    ),
    ComprehensiveBudgetingTip(
      title: 'Savings – ₱(monthlyNet × 0.15)',
      message: 'Save for family needs and future.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.spending,
    ),

    ComprehensiveBudgetingTip(
      title: 'Emergency & School Fund – ₱(monthlyNet × 0.10)',
      message: 'Build for safety and learning.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.savings,
    ),
    ComprehensiveBudgetingTip(
      title: 'Family Savings Fund – ₱(monthlyNet × 0.05)',
      message: 'Save for shared milestones.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.savings,
    ),
    ComprehensiveBudgetingTip(
      title: 'Small savings teach big lessons.',
      message: 'Emergency & School Fund – ₱(monthlyNet × 0.10): Build for safety and learning.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.savings,
    ),
    ComprehensiveBudgetingTip(
      title: 'Build for safety and learning.',
      message: 'Family Savings Fund – ₱(monthlyNet × 0.05): Save for shared milestones.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.savings,
    ),
    ComprehensiveBudgetingTip(
      title: 'Save for shared milestones.',
      message: 'Small savings teach big lessons.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.savings,
    ),

    // Large Families (6+ kids) - Tier 3 - 70/15/15
    // General tips - gender based
    ComprehensiveBudgetingTip(
      title: 'Neutral: Teamwork is your greatest wealth.',
      message: 'Neutral: Simplicity keeps the family strong.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Lead your team — unity is your legacy.',
      message: 'Male: Simplicity sharpens focus — strength follows discipline.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Nurture your team — together, you’re unstoppable.',
      message: 'Female: Keep it simple — peace grows where priorities are clear.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Simplicity keeps the family strong.',
      message: 'Neutral: Focus on togetherness, not comparison.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Lead your home — comparison steals contentment.',
      message: 'Male: Every effort strengthens your home’s foundation.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Stay united — comparison weakens connection.',
      message: 'Female: Every act of love adds to your family’s stability.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Focus on togetherness, not comparison.',
      message: 'Neutral: Every contribution counts — unity builds stability.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Teach teamwork — discipline unites strength.',
      message: 'Male: Lead your team — unity is your legacy.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Model consistency — shared effort brings shared peace.',
      message: 'Female: Nurture your team — together, you’re unstoppable.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.general,
    ),

    ComprehensiveBudgetingTip(
      title: 'Food, Groceries – ₱(monthlyNet × 0.35)',
      message: 'Plan weekly meals and buy in bulk.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.spending,
    ),
    ComprehensiveBudgetingTip(
      title: 'Transportation – ₱(monthlyNet × 0.10)',
      message: 'Coordinate family trips wisely.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.spending,
    ),
    ComprehensiveBudgetingTip(
      title: 'Essentials (Housing & Utilities) – ₱(monthlyNet × 0.17)',
      message: 'Keep basics secure and stable.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.spending,
    ),
    ComprehensiveBudgetingTip(
      title: 'Education – ₱(monthlyNet × 0.08)',
      message: 'Invest equally in every child’s potential.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.spending,
    ),
    ComprehensiveBudgetingTip(
      title: 'Savings – ₱(monthlyNet × 0.15)',
      message: 'Save for family stability and future.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.spending,
    ),

    ComprehensiveBudgetingTip(
      title: 'Emergency & Health Fund – ₱(monthlyNet × 0.10)',
      message: 'Your shield against life’s surprises.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.savings,
    ),
    ComprehensiveBudgetingTip(
      title: 'Education/Family Goals – ₱(monthlyNet × 0.05)',
      message: 'Future-proof your household.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.savings,
    ),
    ComprehensiveBudgetingTip(
      title: 'Saving as a family builds teamwork that lasts generations.',
      message: 'Emergency & Health Fund – ₱(monthlyNet × 0.10): Your shield against life’s surprises.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.savings,
    ),
    ComprehensiveBudgetingTip(
      title: 'Your shield against life’s surprises.',
      message: 'Education/Family Goals – ₱(monthlyNet × 0.05): Future-proof your household.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.savings,
    ),
    ComprehensiveBudgetingTip(
      title: 'Future-proof your household.',
      message: 'Saving as a family builds teamwork that lasts generations.',
      icon: '👪',
      framework: BudgetingFramework.familyCentric,
      category: TipCategory.savings,
    ),

    // Risk Control Framework (40/40/20)
    // For users with unstable income or variable work
    // General tips - gender based
    ComprehensiveBudgetingTip(
      title: 'Neutral: You can’t predict income, but you can control your actions.',
      message: 'Neutral: Flexibility is your shield — be ready for both lean and full months.',
      icon: '🟨',
      framework: BudgetingFramework.riskControl,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: You can’t control the market, but you can master your response.',
      message: 'Male: Adaptability keeps you in the game no matter the season.',
      icon: '🟨',
      framework: BudgetingFramework.riskControl,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: You can’t control everything — but you can stay steady and smart.',
      message: 'Female: Flexibility is your strength — stay ready for life’s shifts.',
      icon: '🟨',
      framework: BudgetingFramework.riskControl,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Flexibility is your shield — be ready for both lean and full months.',
      message: 'Neutral: Calm planning beats panic every time.',
      icon: '🟨',
      framework: BudgetingFramework.riskControl,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Stay composed — logic wins when emotion fades.',
      message: 'Male: Master what’s in your control — let go of the rest.',
      icon: '🟨',
      framework: BudgetingFramework.riskControl,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Breathe and plan — calm thinking protects your goals.',
      message: 'Female: Adjust your plans wisely — don’t waste strength on what’s beyond you.',
      icon: '🟨',
      framework: BudgetingFramework.riskControl,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Calm planning beats panic every time.',
      message: 'Neutral: Focus on what you can adjust, not what you can’t.',
      icon: '🟨',
      framework: BudgetingFramework.riskControl,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Consistency protects you more than luck ever will.',
      message: 'Male: Stay composed — logic wins when emotion fades.',
      icon: '🟨',
      framework: BudgetingFramework.riskControl,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Discipline shields you — it’s your quiet power.',
      message: 'Female: Breathe and plan — calm thinking protects your goals.',
      icon: '🟨',
      framework: BudgetingFramework.riskControl,
      category: TipCategory.general,
    ),

    ComprehensiveBudgetingTip(
      title: 'Food, Groceries – ₱(monthlyNet × 0.20)',
      message: 'Cook in bulk — stability starts in your kitchen.',
      icon: '🟨',
      framework: BudgetingFramework.riskControl,
      category: TipCategory.spending,
    ),
    ComprehensiveBudgetingTip(
      title: 'Transportation – ₱(monthlyNet × 0.10)',
      message: 'Travel smart, stay efficient.',
      icon: '🟨',
      framework: BudgetingFramework.riskControl,
      category: TipCategory.spending,
    ),
    ComprehensiveBudgetingTip(
      title: 'Essentials (Housing & Utilities) – ₱(monthlyNet × 0.10)',
      message: 'Keep bills light for peace of mind.',
      icon: '🟨',
      framework: BudgetingFramework.riskControl,
      category: TipCategory.spending,
    ),
    ComprehensiveBudgetingTip(
      title: 'Flexible Fund – ₱(monthlyNet × 0.40)',
      message: 'Adjust fast when income changes — agility wins.',
      icon: '🟨',
      framework: BudgetingFramework.riskControl,
      category: TipCategory.spending,
    ),
    ComprehensiveBudgetingTip(
      title: 'Savings – ₱(monthlyNet × 0.20)',
      message: 'Save for flexibility and peace of mind.',
      icon: '🟨',
      framework: BudgetingFramework.riskControl,
      category: TipCategory.spending,
    ),

    ComprehensiveBudgetingTip(
      title: 'Emergency Fund – ₱(monthlyNet × 0.10)',
      message: 'Save first, spend later — security before comfort.',
      icon: '🟨',
      framework: BudgetingFramework.riskControl,
      category: TipCategory.savings,
    ),
    ComprehensiveBudgetingTip(
      title: 'Build your reserve - ₱(monthlyNet × 0.20)',
      message: 'It’s your freedom during unstable months.',
      icon: '🟨',
      framework: BudgetingFramework.riskControl,
      category: TipCategory.savings,
    ),
    ComprehensiveBudgetingTip(
      title: 'Every surplus is a future lifeline.',
      message: 'Emergency Fund – ₱(monthlyNet × 0.10): Save first, spend later — security before comfort.',
      icon: '🟨',
      framework: BudgetingFramework.riskControl,
      category: TipCategory.savings,
    ),
    ComprehensiveBudgetingTip(
      title: 'Save first, spend later — security before comfort.',
      message: 'Build your reserve - ₱(monthlyNet × 0.20): It’s your freedom during unstable months.',
      icon: '🟨',
      framework: BudgetingFramework.riskControl,
      category: TipCategory.savings,
    ),
    ComprehensiveBudgetingTip(
      title: 'It’s your freedom during unstable months.',
      message: 'Every surplus is a future lifeline.',
      icon: '🟨',
      framework: BudgetingFramework.riskControl,
      category: TipCategory.savings,
    ),

    // Balanced Framework (50/30/20)
    // For users aiming for healthy financial balance
    // General tips - gender based
    ComprehensiveBudgetingTip(
      title: 'Neutral: Balance isn’t restriction — it’s confidence with control.',
      message: 'Neutral: Enjoy life without losing sight of your goals.',
      icon: '💚',
      framework: BudgetingFramework.balanced,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Balance builds power — control gives you freedom.',
      message: 'Male: Live smart — pleasure means more when purpose stays clear.',
      icon: '💚',
      framework: BudgetingFramework.balanced,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Balance empowers — it’s strength wrapped in calm.',
      message: 'Female: Enjoy the moment, but keep your dreams in view.',
      icon: '💚',
      framework: BudgetingFramework.balanced,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Spend with purpose, not emotion.',
      message: 'Neutral: Every peso should either serve or secure you.',
      icon: '💚',
      framework: BudgetingFramework.balanced,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Let logic, not impulse, guide your wallet.',
      message: 'Male: Let logic, not impulse, guide your wallet.',
      icon: '💚',
      framework: BudgetingFramework.balanced,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Let your values, not moods, lead your spending.',
      message: 'Female: Let your values, not moods, lead your spending.',
      icon: '💚',
      framework: BudgetingFramework.balanced,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Every peso should either serve or secure you.',
      message: 'Neutral: Balance brings peace — not pressure.',
      icon: '💚',
      framework: BudgetingFramework.balanced,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Balance creates control — that’s real peace.',
      message: 'Male: Balance builds power — control gives you freedom.',
      icon: '💚',
      framework: BudgetingFramework.balanced,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Harmony in choices brings calm and confidence.',
      message: 'Female: Balance empowers — it’s strength wrapped in calm.',
      icon: '💚',
      framework: BudgetingFramework.balanced,
      category: TipCategory.general,
    ),

    ComprehensiveBudgetingTip(
      title: 'Food, Groceries – ₱(monthlyNet × 0.20)',
      message: 'Eat smart, enjoy variety within reason.',
      icon: '💚',
      framework: BudgetingFramework.balanced,
      category: TipCategory.spending,
    ),
    ComprehensiveBudgetingTip(
      title: 'Transportation – ₱(monthlyNet × 0.10)',
      message: 'Plan routes and stay consistent.',
      icon: '💚',
      framework: BudgetingFramework.balanced,
      category: TipCategory.spending,
    ),
    ComprehensiveBudgetingTip(
      title: 'Essentials (Housing & Utilities) – ₱(monthlyNet × 0.10)',
      message: 'Keep living costs predictable.',
      icon: '💚',
      framework: BudgetingFramework.balanced,
      category: TipCategory.spending,
    ),
    ComprehensiveBudgetingTip(
      title: 'Entertainment & Lifestyle – ₱(monthlyNet × 0.10)',
      message: 'Fun is healthy — just budget it.',
      icon: '💚',
      framework: BudgetingFramework.balanced,
      category: TipCategory.spending,
    ),
    ComprehensiveBudgetingTip(
      title: 'Savings – ₱(monthlyNet × 0.20)',
      message: 'Save for balance and future goals.',
      icon: '💚',
      framework: BudgetingFramework.balanced,
      category: TipCategory.spending,
    ),

    ComprehensiveBudgetingTip(
      title: 'Emergency Fund – ₱(monthlyNet × 0.10)',
      message: 'Your peace-of-mind fund.',
      icon: '💚',
      framework: BudgetingFramework.balanced,
      category: TipCategory.savings,
    ),
    ComprehensiveBudgetingTip(
      title: 'Goal/Savings Fund – ₱(monthlyNet × 0.10)',
      message: 'Fuel your dreams with discipline.',
      icon: '💚',
      framework: BudgetingFramework.balanced,
      category: TipCategory.savings,
    ),
    ComprehensiveBudgetingTip(
      title: 'Savings = stability, investments = growth.',
      message: 'Emergency Fund – ₱(monthlyNet × 0.10): Your peace-of-mind fund.',
      icon: '💚',
      framework: BudgetingFramework.balanced,
      category: TipCategory.savings,
    ),
    ComprehensiveBudgetingTip(
      title: 'Your peace-of-mind fund.',
      message: 'Goal/Savings Fund – ₱(monthlyNet × 0.10): Fuel your dreams with discipline.',
      icon: '💚',
      framework: BudgetingFramework.balanced,
      category: TipCategory.savings,
    ),
    ComprehensiveBudgetingTip(
      title: 'Fuel your dreams with discipline.',
      message: 'Savings = stability, investments = growth.',
      icon: '💚',
      framework: BudgetingFramework.balanced,
      category: TipCategory.savings,
    ),

    // Builder Framework (60/20/20)
    // For users building their financial base
    // General tips - gender based
    ComprehensiveBudgetingTip(
      title: 'Neutral: You’re not just earning — you’re constructing your future.',
      message: 'Neutral: Invest in learning; your skills are your strongest asset.',
      icon: '🧱',
      framework: BudgetingFramework.builder,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Each effort you make builds your legacy.',
      message: 'Male: Upgrade your knowledge — it’s the man’s best investment.',
      icon: '🧱',
      framework: BudgetingFramework.builder,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Every action you take shapes your future foundation.',
      message: 'Female: Keep learning — your skills are your lifelong power.',
      icon: '🧱',
      framework: BudgetingFramework.builder,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Invest in learning; your skills are your strongest asset.',
      message: 'Neutral: Be patient — growth takes steady effort.',
      icon: '🧱',
      framework: BudgetingFramework.builder,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Patience builds strength — success favors persistence.',
      message: 'Male: Routine builds mastery — keep stacking your wins.',
      icon: '🧱',
      framework: BudgetingFramework.builder,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Growth blooms with patience — stay consistent and calm.',
      message: 'Female: Each month of discipline adds to your confidence and growth.',
      icon: '🧱',
      framework: BudgetingFramework.builder,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Be patient — growth takes steady effort.',
      message: 'Neutral: Each disciplined month builds momentum.',
      icon: '🧱',
      framework: BudgetingFramework.builder,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Your discipline defines your worth — invest in yourself.',
      message: 'Male: Each effort you make builds your legacy.',
      icon: '🧱',
      framework: BudgetingFramework.builder,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: You are your greatest asset — nurture your growth.',
      message: 'Female: Every action you take shapes your future foundation.',
      icon: '🧱',
      framework: BudgetingFramework.builder,
      category: TipCategory.general,
    ),

    ComprehensiveBudgetingTip(
      title: 'Food,  Groceries – ₱(monthlyNet × 0.25)',
      message: 'Fuel your productivity, not your cravings.',
      icon: '🧱',
      framework: BudgetingFramework.builder,
      category: TipCategory.spending,
    ),
    ComprehensiveBudgetingTip(
      title: 'Transportation – ₱(monthlyNet × 0.08)',
      message: 'Get there smart, not flashy.',
      icon: '🧱',
      framework: BudgetingFramework.builder,
      category: TipCategory.spending,
    ),
    ComprehensiveBudgetingTip(
      title: 'Essentials (Housing & Utilities) – ₱(monthlyNet × 0.22)',
      message: 'Stay consistent; predictability builds peace.',
      icon: '🧱',
      framework: BudgetingFramework.builder,
      category: TipCategory.spending,
    ),
    ComprehensiveBudgetingTip(
      title: 'Education/Skill Building – ₱(monthlyNet × 0.05)',
      message: 'Learn now, earn more later.',
      icon: '🧱',
      framework: BudgetingFramework.builder,
      category: TipCategory.spending,
    ),
    ComprehensiveBudgetingTip(
      title: 'Savings – ₱(monthlyNet × 0.20)',
      message: 'Save for growth and future goals.',
      icon: '🧱',
      framework: BudgetingFramework.builder,
      category: TipCategory.spending,
    ),

    ComprehensiveBudgetingTip(
      title: 'Emergency Fund – ₱(monthlyNet × 0.10)',
      message: 'Secure your foundation first.',
      icon: '🧱',
      framework: BudgetingFramework.builder,
      category: TipCategory.savings,
    ),
    ComprehensiveBudgetingTip(
      title: 'Savings/Goal Fund – ₱(monthlyNet × 0.10)',
      message: 'Build assets that grow with you.',
      icon: '🧱',
      framework: BudgetingFramework.builder,
      category: TipCategory.savings,
    ),
    ComprehensiveBudgetingTip(
      title: 'Save early — it’s how you buy freedom later.',
      message: 'Emergency Fund – ₱(monthlyNet × 0.10): Secure your foundation first.',
      icon: '🧱',
      framework: BudgetingFramework.builder,
      category: TipCategory.savings,
    ),
    ComprehensiveBudgetingTip(
      title: 'Secure your foundation first.',
      message: 'Savings/Goal Fund – ₱(monthlyNet × 0.10): Build assets that grow with you.',
      icon: '🧱',
      framework: BudgetingFramework.builder,
      category: TipCategory.savings,
    ),
    ComprehensiveBudgetingTip(
      title: 'Build assets that grow with you.',
      message: 'Save early — it’s how you buy freedom later.',
      icon: '🧱',
      framework: BudgetingFramework.builder,
      category: TipCategory.savings,
    ),

    // Conservative Framework (75/10/15)
    // For users valuing security and long-term peace
    // General tips - gender based
    ComprehensiveBudgetingTip(
      title: 'Neutral: You’ve earned your calm — now protect it.',
      message: 'Neutral: Peace of mind is your best return on investment.',
      icon: '🩵',
      framework: BudgetingFramework.conservative,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Guard your peace — stability is your best strength.',
      message: 'Male: Protect your focus — a clear mind drives success.',
      icon: '🩵',
      framework: BudgetingFramework.conservative,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Keep your calm — you’ve worked hard for this balance.',
      message: 'Female: Treasure your peace — it’s worth more than any return.',
      icon: '🩵',
      framework: BudgetingFramework.conservative,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Predictability beats excitement when it comes to money.',
      message: 'Neutral: Stability is the reward of wise choices.',
      icon: '🩵',
      framework: BudgetingFramework.conservative,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Choose security over thrill — stability builds strength.',
      message: 'Male: Smart planning earns you lasting strength.',
      icon: '🩵',
      framework: BudgetingFramework.conservative,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Choose steadiness — calm control outlasts excitement.',
      message: 'Female: Wise habits bring the comfort you deserve.',
      icon: '🩵',
      framework: BudgetingFramework.conservative,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Stability is the reward of wise choices.',
      message: 'Neutral: Security today ensures comfort tomorrow.',
      icon: '🩵',
      framework: BudgetingFramework.conservative,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Build your safety now so your future self can rest.',
      message: 'Male: Choose security over thrill — stability builds strength.',
      icon: '🩵',
      framework: BudgetingFramework.conservative,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Secure your today — your tomorrow will thank you.',
      message: 'Female: Keep your calm — you’ve worked hard for this balance.',
      icon: '🩵',
      framework: BudgetingFramework.conservative,
      category: TipCategory.general,
    ),

    ComprehensiveBudgetingTip(
      title: 'Food, Groceries – ₱(monthlyNet × 0.25)',
      message: 'Nourish your health, not your habits.',
      icon: '🩵',
      framework: BudgetingFramework.conservative,
      category: TipCategory.spending,
    ),
    ComprehensiveBudgetingTip(
      title: 'Transportation – ₱(monthlyNet × 0.10)',
      message: 'Keep it practical and consistent.',
      icon: '🩵',
      framework: BudgetingFramework.conservative,
      category: TipCategory.spending,
    ),
    ComprehensiveBudgetingTip(
      title: 'Health & Personal Care – ₱(monthlyNet × 0.15)',
      message: 'Prioritize wellness over wants.',
      icon: '🩵',
      framework: BudgetingFramework.conservative,
      category: TipCategory.spending,
    ),
    ComprehensiveBudgetingTip(
      title: 'Essentials (Rent/Utilities) – ₱(monthlyNet × 0.25)',
      message: 'Stability starts at home.',
      icon: '🩵',
      framework: BudgetingFramework.conservative,
      category: TipCategory.spending,
    ),
    ComprehensiveBudgetingTip(
      title: 'Savings – ₱(monthlyNet × 0.15)',
      message: 'Save for stability and peace.',
      icon: '🩵',
      framework: BudgetingFramework.conservative,
      category: TipCategory.spending,
    ),

    ComprehensiveBudgetingTip(
      title: 'Emergency & Medical Fund – ₱(monthlyNet × 0.10)',
      message: 'Your safety net keeps you secure.',
      icon: '🩵',
      framework: BudgetingFramework.conservative,
      category: TipCategory.savings,
    ),
    ComprehensiveBudgetingTip(
      title: 'Legacy or Long-Term Savings – ₱(monthlyNet × 0.05)',
      message: 'Build quiet wealth for your family.',
      icon: '🩵',
      framework: BudgetingFramework.conservative,
      category: TipCategory.savings,
    ),
    ComprehensiveBudgetingTip(
      title: 'Saving isn’t a task — it’s your legacy.',
      message: 'Emergency & Medical Fund – ₱(monthlyNet × 0.10): Your safety net keeps you secure.',
      icon: '🩵',
      framework: BudgetingFramework.conservative,
      category: TipCategory.savings,
    ),
    ComprehensiveBudgetingTip(
      title: 'Your safety net keeps you secure.',
      message: 'Legacy or Long-Term Savings – ₱(monthlyNet × 0.05): Build quiet wealth for your family.',
      icon: '🩵',
      framework: BudgetingFramework.conservative,
      category: TipCategory.savings,
    ),
    ComprehensiveBudgetingTip(
      title: 'Build quiet wealth for your family.',
      message: 'Saving isn’t a task — it’s your legacy.',
      icon: '🩵',
      framework: BudgetingFramework.conservative,
      category: TipCategory.savings,
    ),

    // PocketPilot General Budgeting Tips
    ComprehensiveBudgetingTip(
      title: 'Neutral: Bare Minimum',
      message: 'Neutral: Stick strictly to what\'s required to live.',
      icon: '📏',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Stay sharp',
      message: 'Male: Cut the excess and focus on what truly matters.',
      icon: '📏',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Keep it simple',
      message: 'Female: Meet your needs and protect your peace.',
      icon: '📏',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),

    // PocketPilot General Budgeting Tips
    ComprehensiveBudgetingTip(
      title: 'Neutral: Budget Boss',
      message: 'Neutral: You control your money, not the other way around.',
      icon: '👑',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Be the captain',
      message: 'Male: Your cash follows your command.',
      icon: '👑',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Take the lead',
      message: 'Female: Guide your money with confidence and care.',
      icon: '👑',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Goal Getter',
      message: 'Neutral: Set clear financial goals to guide your decisions.',
      icon: '🎯',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Define your targets',
      message: 'Male: Success starts with precision.',
      icon: '🎯',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Set your vision',
      message: 'Female: Direction turns dreams into results.',
      icon: '🎯',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Save First, Spend Later',
      message: 'Neutral: Treat savings like a bill that must be paid.',
      icon: '💰',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Pay your future first',
      message: 'Male: That’s real discipline.',
      icon: '💰',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Prioritize your peace',
      message: 'Female: Savings come before spending.',
      icon: '💰',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Track to Triumph',
      message: 'Neutral: Awareness is your strongest budgeting tool.',
      icon: '📊',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Know your numbers',
      message: 'Male: Mastery begins with measurement.',
      icon: '📊',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Stay mindful',
      message: 'Female: Awareness builds lasting control.',
      icon: '📊',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Cashflow King',
      message: 'Neutral: Know when money comes in and where it goes.',
      icon: '👑',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Rule your inflow',
      message: 'Male: Command every peso like a strategist.',
      icon: '👑',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Manage your rhythm',
      message: 'Female: Understand your flow to stay secure.',
      icon: '👑',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Delayed Delight',
      message: 'Neutral: Waiting often leads to smarter purchases.',
      icon: '⏳',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Hold the impulse',
      message: 'Male: Patience multiplies rewards.',
      icon: '⏳',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Pause with purpose',
      message: 'Female: The best buys come with timing.',
      icon: '⏳',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Automate Success',
      message: 'Neutral: Make saving effortless with auto-transfers.',
      icon: '🤖',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Set it, forget it, grow it',
      message: 'Male: Let automation build your wealth.',
      icon: '🤖',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Simplify your success',
      message: 'Female: Automate peace of mind.',
      icon: '🤖',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Emergency Armor',
      message: 'Neutral: Build your 3-month safety net gradually.',
      icon: '🛡',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Prepare like a warrior',
      message: 'Male: Protection ensures survival.',
      icon: '🛡',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Secure your shield',
      message: 'Female: Your safety net brings calm confidence.',
      icon: '🛡',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Small Steps, Big Impact',
      message: 'Neutral: Even small consistent actions grow wealth.',
      icon: '🌱',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Consistency compounds',
      message: 'Male: Progress favors persistence.',
      icon: '🌱',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Every small habit plants the seeds of abundance',
      message: 'Female: Every small habit plants the seeds of abundance.',
      icon: '🌱',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Needs Over Wants',
      message: 'Neutral: Always prioritize essentials before indulgence.',
      icon: '⚖',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Choose strength',
      message: 'Male: Wants can wait, priorities can’t.',
      icon: '⚖',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Ground yourself',
      message: 'Female: Essentials first, comfort follows.',
      icon: '⚖',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Invest in Learning',
      message: 'Neutral: Financial literacy pays lifetime dividends.',
      icon: '📚',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Skill is power',
      message: 'Male: Keep sharpening your mind.',
      icon: '📚',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Growth is grace',
      message: 'Female: Learn, evolve, and rise higher.',
      icon: '📚',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Review Regularly',
      message: 'Neutral: Monthly check-ins keep your plan on track.',
      icon: '📅',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Stay accountable',
      message: 'Male: Your plan deserves attention.',
      icon: '📅',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Reflect and adjust',
      message: 'Female: Awareness leads to balance.',
      icon: '📅',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Stay Realistic',
      message: 'Neutral: Set achievable goals based on your income.',
      icon: '🎯',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Face the facts',
      message: 'Male: Progress starts with truth.',
      icon: '🎯',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Stay grounded',
      message: 'Female: Realistic goals lead to steady growth.',
      icon: '🎯',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Cut the Leaks',
      message: 'Neutral: Identify and eliminate recurring wasteful costs.',
      icon: '🚰',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Trim the excess',
      message: 'Male: Waste weakens your progress.',
      icon: '🚰',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Clean your flow',
      message: 'Female: Remove what drains your peace.',
      icon: '🚰',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Reward Yourself Wisely',
      message: 'Neutral: Celebrate milestones within budget.',
      icon: '🎉',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Earn your wins',
      message: 'Male: Reward discipline, not impulse.',
      icon: '🎉',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Celebrate growth',
      message: 'Female: You deserve joy within balance.',
      icon: '🎉',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Emergency = Action',
      message: 'Neutral: When unexpected costs hit, adapt quickly.',
      icon: '⚡',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: React with control',
      message: 'Male: Quick thinking keeps you stable.',
      icon: '⚡',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Stay composed',
      message: 'Female: Adapt with calm and confidence.',
      icon: '⚡',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Future-Proof Finances',
      message: 'Neutral: Save today for tomorrow\'s surprises.',
      icon: '🔮',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Secure your legacy',
      message: 'Male: Protect what’s ahead.',
      icon: '🔮',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Safeguard your future',
      message: 'Female: Prepare with heart and wisdom.',
      icon: '🔮',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Money Mindset',
      message: 'Neutral: Wealth starts with positive, consistent habits.',
      icon: '🧠',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Think growth',
      message: 'Male: Discipline fuels success.',
      icon: '🧠',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Think abundance',
      message: 'Female: Grace and consistency attract progress.',
      icon: '🧠',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Track Every Peso',
      message: 'Neutral: Awareness transforms spending behavior.',
      icon: '👁',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Consistency Wins',
      message: 'Budgeting works only when done continuously.',
      icon: '🏆',
      framework: BudgetingFramework.pocketPilotGeneral,
      category: TipCategory.general,
    ),

    // Motivational Tips
    ComprehensiveBudgetingTip(
      title: 'Neutral: Start Where You Are',
      message: 'Neutral: You don\'t need a perfect plan—just begin.',
      icon: '🚀',
      framework: BudgetingFramework.motivational,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Begin with what you have',
      message: 'Male: Action builds results.',
      icon: '🚀',
      framework: BudgetingFramework.motivational,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Start now',
      message: 'Female: Even small beginnings bloom beautifully.',
      icon: '🚀',
      framework: BudgetingFramework.motivational,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Small Wins, Big Momentum',
      message: 'Neutral: Celebrate every small step; growth builds confidence.',
      icon: '🌟',
      framework: BudgetingFramework.motivational,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Stack your victories',
      message: 'Male: Momentum makes mastery.',
      icon: '🌟',
      framework: BudgetingFramework.motivational,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Honor your progress',
      message: 'Female: Small wins shape success.',
      icon: '🌟',
      framework: BudgetingFramework.motivational,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Discipline Beats Motivation',
      message: 'Neutral: Habits will sustain you when willpower fades.',
      icon: '💪',
      framework: BudgetingFramework.motivational,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Build habits like armor',
      message: 'Male: Consistency outlasts drive.',
      icon: '💪',
      framework: BudgetingFramework.motivational,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Let routine be your anchor',
      message: 'Female: Habits protect your purpose.',
      icon: '💪',
      framework: BudgetingFramework.motivational,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Progress Over Perfection',
      message: 'Neutral: Learn from mistakes; keep moving forward.',
      icon: '📈',
      framework: BudgetingFramework.motivational,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Don\'t chase perfect',
      message: 'Male: Progress is power.',
      icon: '📈',
      framework: BudgetingFramework.motivational,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Grace over perfection',
      message: 'Female: Every step forward matters.',
      icon: '📈',
      framework: BudgetingFramework.motivational,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Your Future Self Will Thank You',
      message: 'Neutral: Every smart choice builds tomorrow\'s freedom.',
      icon: '🙏',
      framework: BudgetingFramework.motivational,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Build for tomorrow',
      message: 'Male: Your future self is counting on you.',
      icon: '🙏',
      framework: BudgetingFramework.motivational,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Nurture your future',
      message: 'Female: Today\'s care creates tomorrow\'s ease.',
      icon: '🙏',
      framework: BudgetingFramework.motivational,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Don\'t Compare, Commit',
      message: 'Neutral: Focus on your goals, not anyone else\'s path.',
      icon: '🎯',
      framework: BudgetingFramework.motivational,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Stay in your lane',
      message: 'Male: Focus beats comparison.',
      icon: '🎯',
      framework: BudgetingFramework.motivational,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Walk your own pace',
      message: 'Female: Your journey is uniquely yours.',
      icon: '🎯',
      framework: BudgetingFramework.motivational,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Mind Over Money',
      message: 'Neutral: Budgeting is empowerment, not restriction.',
      icon: '🧠',
      framework: BudgetingFramework.motivational,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Control the game',
      message: 'Male: Your mindset drives mastery.',
      icon: '🧠',
      framework: BudgetingFramework.motivational,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Lead with calm',
      message: 'Female: Mindset turns money into peace.',
      icon: '🧠',
      framework: BudgetingFramework.motivational,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Consistency Creates Change',
      message: 'Neutral: Tiny daily actions lead to major transformation.',
      icon: '🔄',
      framework: BudgetingFramework.motivational,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Repetition builds greatness',
      message: 'Male: Stay disciplined.',
      icon: '🔄',
      framework: BudgetingFramework.motivational,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Small routines create big results',
      message: 'Female: Keep going gently but firmly.',
      icon: '🔄',
      framework: BudgetingFramework.motivational,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: You\'re Closer Than You Think',
      message: 'Neutral: Every saved peso brings you nearer to your dream.',
      icon: '🎯',
      framework: BudgetingFramework.motivational,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Stay driven',
      message: 'Male: Every move inches you closer to victory.',
      icon: '🎯',
      framework: BudgetingFramework.motivational,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Believe it',
      message: 'Female: Every act of discipline draws you nearer to success.',
      icon: '🎯',
      framework: BudgetingFramework.motivational,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Neutral: Freedom is Worth the Fight',
      message: 'Neutral: Every sacrifice today buys tomorrow\'s peace.',
      icon: '🆓',
      framework: BudgetingFramework.motivational,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Male: Endure the grind',
      message: 'Male: Strength now brings freedom later.',
      icon: '🆓',
      framework: BudgetingFramework.motivational,
      category: TipCategory.general,
    ),
    ComprehensiveBudgetingTip(
      title: 'Female: Stay strong',
      message: 'Female: Every sacrifice plants peace for tomorrow.',
      icon: '🆓',
      framework: BudgetingFramework.motivational,
      category: TipCategory.general,
    ),
  ];
}