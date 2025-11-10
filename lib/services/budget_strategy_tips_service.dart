import '../models/user.dart';
import '../models/budget_prescription.dart';

/// Enum for different budget strategies based on user's financial situation
enum BudgetStrategy {
  debtHeavyRecovery, // 70/20/10 - Debt payments with strict deadlines
  conservative,      // 75/10/15 - Retirement or fixed income
  familyCentric,     // Child-Based Framework (60/25/15, 65/20/15, 70/15/15)
  riskControl,       // 40/40/20 - Inconsistent income
  builder,           // 60/20/20 - Growing obligations (mortgage, dependents)
  balanced,          // 50/30/20 - Default, independent, early career
}

/// Enhanced budgeting tip with strategy context
class StrategyBudgetingTip {
  final String category;
  final String title;
  final String message;
  final String action;
  final String icon;
  final BudgetStrategy strategy;
  final int priority; // 1-5, where 1 is highest priority

  StrategyBudgetingTip({
    required this.category,
    required this.title,
    required this.message,
    required this.action,
    required this.icon,
    required this.strategy,
    required this.priority,
  });

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'title': title,
      'message': message,
      'action': action,
      'icon': icon,
      'strategy': strategy.toString(),
      'priority': priority,
    };
  }

  factory StrategyBudgetingTip.fromJson(Map<String, dynamic> json) {
    return StrategyBudgetingTip(
      category: json['category'],
      title: json['title'],
      message: json['message'],
      action: json['action'],
      icon: json['icon'],
      strategy: BudgetStrategy.values.firstWhere(
        (e) => e.toString() == json['strategy'],
        orElse: () => BudgetStrategy.balanced,
      ),
      priority: json['priority'],
    );
  }

  /// Convert to regular BudgetingTip for compatibility
  BudgetingTip toBudgetingTip() {
    return BudgetingTip(
      category: category,
      title: title,
      message: message,
      action: action,
      icon: icon,
    );
  }
}

/// Service for determining budget strategy and generating coaching-style tips
class BudgetStrategyTipsService {
  // DECISION TREE START: Core Framework Selection Logic - Determines which of 6 budget frameworks to use based on user characteristics
  /// Determine the most appropriate budget strategy based on user data
  /// 
  /// Priority Order:
  /// 1. Debt Heavy Recovery (70/20/10) - 2+ debts
  /// 2. Risk Control (40/40/20) - Irregular income, unemployed, business owner
  /// 3. Conservative (75/10/15) - Retired, age ≥ 55, fixed income
  /// 4. Family-Centric (Child-based) - Has children, fixed income
  /// 5. Builder (60/20/20) - Mortgage, no children
  /// 6. Balanced (50/30/20) - Default
  static BudgetStrategy determineBudgetStrategy(User user) {
    // Priority 1: Debt Heavy Recovery (70/20/10)
    // Condition: Has 2 or more debts (credit card + loan)
    if (_hasHighRiskDebt(user)) {
      return BudgetStrategy.debtHeavyRecovery;
    }

    // Priority 2: Risk Control (40/40/20)
    // Conditions: Income type is irregular, OR Profession is unemployed, OR Is a business owner
    if (_hasIncomeStabilityRisks(user)) {
      return BudgetStrategy.riskControl;
    }

    // Priority 3: Conservative (75/10/15)
    // Conditions: Age ≥ 55, OR profession is retired, AND income type is fixed
    if (_isConservativeEligible(user)) {
      return BudgetStrategy.conservative;
    }

    // Priority 4: Family-Centric
    // Conditions: Has children, Income type is fixed, 
    // Applies to: Single, Married, Widow, or Living with partner
    if (_isFamilyCentricEligible(user)) {
      return BudgetStrategy.familyCentric;
    }

    // Priority 5: Builder (60/20/20)
    // Conditions: Has mortgage and no children,
    // Applies to: Single, Married, Widow, or Living with partner
    if (_isInGrowthStage(user)) {
      return BudgetStrategy.builder;
    }

    // Priority 6: Balanced (50/30/20) - Default
    // Conditions: No children, No mortgage, Fixed income,
    // Applies to: Single, Married, or Widow
    if (_isBalancedEligible(user)) {
      return BudgetStrategy.balanced;
    }
    
    // Fallback to balanced if no other conditions are met
    return BudgetStrategy.balanced;
  }
  // DECISION TREE END: Core Framework Selection Logic

  /// Generate 3-5 motivational, coaching-style tips based on strategy
  static List<StrategyBudgetingTip> generateStrategyTips(
    User user,
    BudgetStrategy strategy,
  ) {
    final tips = <StrategyBudgetingTip>[];

    switch (strategy) {
      case BudgetStrategy.debtHeavyRecovery:
        tips.addAll(_generateDebtHeavyRecoveryTips(user));
        break;
      case BudgetStrategy.familyCentric:
        tips.addAll(_generateFamilyCentricTips(user));
        break;
      case BudgetStrategy.riskControl:
        tips.addAll(_generateRiskControlTips(user));
        break;
      case BudgetStrategy.conservative:
        tips.addAll(_generateConservativeTips(user));
        break;
      case BudgetStrategy.builder:
        tips.addAll(_generateBuilderTips(user));
        break;
      case BudgetStrategy.balanced:
        tips.addAll(_generateBalancedTips(user));
        break;
    }

    // Sort by priority and return top 5
    tips.sort((a, b) => a.priority.compareTo(b.priority));
    return tips.take(5).toList();
  }

  /// Check if user has high-risk debt situation (2 or more debts)
  /// Conditions: Has 2 or more debts (credit card + loan)
  static bool _hasHighRiskDebt(User user) {
    final debtStatuses = user.debtStatuses;
    
    // Count actual debt statuses (excluding noDebt)
    final actualDebtCount = debtStatuses.where((debt) => debt != DebtStatus.noDebt).length;
    
    // Has 2 or more debts
    return actualDebtCount >= 2;
  }

  /// Check if user is eligible for conservative strategy
  /// Conditions: age ≥ 55, OR profession is retired, AND income type is fixed
  static bool _isConservativeEligible(User user) {
    // Check age ≥ 55 OR profession is retired
    bool ageOrProfessionMatch = false;
    
    // Check age ≥ 55
    if (user.birthYear != null) {
      final age = DateTime.now().year - user.birthYear!;
      if (age >= 55) {
        ageOrProfessionMatch = true;
      }
    }
    
    // OR profession is retired
    if (user.profession == Profession.retired) {
      ageOrProfessionMatch = true;
    }
    
    if (!ageOrProfessionMatch) {
      return false;
    }

    // Check incomeType = fixed (incomeFrequency = fixed)
    if (user.incomeFrequency != IncomeFrequency.fixed) {
      return false;
    }

    return true;
  }

  /// Check if user is eligible for family-centric strategy
  /// Conditions: Has children, Income type is fixed,
  /// Applies to: Single, Married, Widow, or Living with partner
  static bool _isFamilyCentricEligible(User user) {
    // Base Conditions (ALL required):
    // hasKids = true
    if (user.hasKids != true) {
      return false;
    }

    // civilStatus = single, married, widowed, or livingWithPartner
    if (user.civilStatus != CivilStatus.single && 
        user.civilStatus != CivilStatus.married && 
        user.civilStatus != CivilStatus.widowed && 
        user.civilStatus != CivilStatus.livingWithPartner) {
      return false;
    }

    // Check incomeType = fixed
    if (user.incomeFrequency != IncomeFrequency.fixed) {
      return false;
    }

    return true;
  }

  /// Check for income stability risks
  /// Conditions: incomeType = irregular OR profession = unemployed OR isBusinessOwner = true
  static bool _hasIncomeStabilityRisks(User user) {
    // incomeType = irregular
    if (user.incomeFrequency == IncomeFrequency.irregular) {
      return true;
    }

    // profession = unemployed
    if (user.profession == Profession.unemployed) {
      return true;
    }

    // isBusinessOwner = true
    if (user.isBusinessOwner == true) {
      return true;
    }

    return false;
  }

  /// Check if user is in growth stage requiring builder approach
  /// Conditions: Has mortgage and no children,
  /// Applies to: Single, Married, Widow, or Living with partner
  static bool _isInGrowthStage(User user) {
    // Check civilStatus = single, married, widowed, or livingWithPartner
    if (user.civilStatus != CivilStatus.single && 
        user.civilStatus != CivilStatus.married && 
        user.civilStatus != CivilStatus.widowed && 
        user.civilStatus != CivilStatus.livingWithPartner) {
      return false;
    }

    // Check has no children
    if (user.hasKids == true) {
      return false;
    }

    // Check has mortgage
    if (user.householdSituation != HouseholdSituation.mortgage) {
      return false;
    }

    return true;
  }

  /// Check if user is eligible for balanced strategy
  /// Conditions: No children, No mortgage, Fixed income,
  /// Applies to: Single, Married, or Widow
  static bool _isBalancedEligible(User user) {
    // Check has no children
    if (user.hasKids == true) {
      return false;
    }

    // Check has no mortgage
    if (user.householdSituation == HouseholdSituation.mortgage) {
      return false;
    }

    // Check incomeType = fixed
    if (user.incomeFrequency != IncomeFrequency.fixed) {
      return false;
    }

    // Check civilStatus = single, married, or widowed
    if (user.civilStatus != CivilStatus.single && 
        user.civilStatus != CivilStatus.married && 
        user.civilStatus != CivilStatus.widowed) {
      return false;
    }

    return true;
  }

  /// Generate tips for debt-heavy recovery strategy (70/20/10)
  static List<StrategyBudgetingTip> _generateDebtHeavyRecoveryTips(User user) {
    return [
      StrategyBudgetingTip(
        category: 'Debt Freedom',
        title: 'Your Path to Financial Freedom Starts Now',
        message: 'Every peso you redirect from wants to debt payments brings you closer to liberation.',
        action: 'Focus 70% of your income on absolute necessities and debt elimination.',
        icon: '🔓',
        strategy: BudgetStrategy.debtHeavyRecovery,
        priority: 1,
      ),
      StrategyBudgetingTip(
        category: 'Emergency Mindset',
        title: 'Think Emergency, Act Deliberately',
        message: 'Your debt has deadlines and growing interest - treat this as your financial emergency.',
        action: 'Cut all non-essential spending until you see real progress on debt reduction.',
        icon: '🚨',
        strategy: BudgetStrategy.debtHeavyRecovery,
        priority: 2,
      ),
      StrategyBudgetingTip(
        category: 'Smart Savings',
        title: 'Save Smart While You Pay',
        message: 'Even small savings create a safety net that prevents more debt.',
        action: 'Set aside 10% for emergency fund while aggressively paying down high-interest debt.',
        icon: '🛡',
        strategy: BudgetStrategy.debtHeavyRecovery,
        priority: 3,
      ),
      StrategyBudgetingTip(
        category: 'Lifestyle Shift',
        title: 'Temporary Sacrifice, Permanent Gain',
        message: 'This intense focus is temporary - every month brings you closer to financial peace.',
        action: 'Embrace a minimalist lifestyle temporarily to accelerate your debt-free journey.',
        icon: '💪',
        strategy: BudgetStrategy.debtHeavyRecovery,
        priority: 4,
      ),
    ];
  }

  /// Generate tips for family-centric strategy (Tier-Based Framework)
  static List<StrategyBudgetingTip> _generateFamilyCentricTips(User user) {
    // Determine which tier to use based on number of children
    int? numberOfChildren = user.numberOfChildren;
    
    if (numberOfChildren != null) {
      // Tier 3 — Large Family (6+ Children) – 70/15/15
      if (numberOfChildren >= 6) {
        return [
          StrategyBudgetingTip(
            category: 'Family Strength',
            title: 'Strength in Numbers',
            message: 'Everyone plays a role in family stability.',
            action: 'Clear money rules protect family peace.',
            icon: '👪',
            strategy: BudgetStrategy.familyCentric,
            priority: 1,
          ),
          StrategyBudgetingTip(
            category: 'Simple Living',
            title: 'Simple Living, Strong Values',
            message: 'Peace thrives in disciplined households.',
            action: 'Every choice impacts many lives ahead.',
            icon: '🏡',
            strategy: BudgetStrategy.familyCentric,
            priority: 2,
          ),
          StrategyBudgetingTip(
            category: 'Long-Term Thinking',
            title: 'Think Long-Term',
            message: 'Every choice impacts many lives ahead.',
            action: 'Encourage responsibility, regardless of age.',
            icon: '🔮',
            strategy: BudgetStrategy.familyCentric,
            priority: 3,
          ),
          StrategyBudgetingTip(
            category: 'Financial Focus',
            title: 'Needs Only',
            message: 'Focus strictly on food, shelter, school, health.',
            action: 'Prioritize hand-me-downs and DIY solutions.',
            icon: '🎯',
            strategy: BudgetStrategy.familyCentric,
            priority: 4,
          ),
          StrategyBudgetingTip(
            category: 'Emergency Preparedness',
            title: 'Emergency Comes First',
            message: 'Large families must prepare for crisis.',
            action: 'Even minimal savings grow over time.',
            icon: '🛡',
            strategy: BudgetStrategy.familyCentric,
            priority: 5,
          ),
        ];
      }
      // Tier 2 — Growing Family (3–5 Children) – 65/20/15
      else if (numberOfChildren >= 3) {
        return [
          StrategyBudgetingTip(
            category: 'Teamwork',
            title: 'Unity in Budgeting',
            message: 'Financial teamwork is essential in a busy household.',
            action: 'Good habits bring calm amid activity.',
            icon: '🤝',
            strategy: BudgetStrategy.familyCentric,
            priority: 1,
          ),
          StrategyBudgetingTip(
            category: 'Stability',
            title: 'Stability Through Routine',
            message: 'Good habits bring calm amid activity.',
            action: 'Clear money rules protect family peace.',
            icon: '📅',
            strategy: BudgetStrategy.familyCentric,
            priority: 2,
          ),
          StrategyBudgetingTip(
            category: 'Financial Focus',
            title: 'Essentials First',
            message: 'Prioritize food, education, and healthcare.',
            action: 'Check subscriptions, bills, and recurring costs.',
            icon: '📋',
            strategy: BudgetStrategy.familyCentric,
            priority: 3,
          ),
          StrategyBudgetingTip(
            category: 'Smart Shopping',
            title: 'Bulk & Save',
            message: 'Buy in volume to stretch each peso further.',
            action: 'Low-cost quality time beats expensive outings.',
            icon: '🛒',
            strategy: BudgetStrategy.familyCentric,
            priority: 4,
          ),
          StrategyBudgetingTip(
            category: 'Emergency Preparedness',
            title: 'Expect the Unexpected',
            message: 'More children mean more surprise costs.',
            action: 'Use simple saving challenges for kids.',
            icon: '⚠',
            strategy: BudgetStrategy.familyCentric,
            priority: 5,
          ),
        ];
      }
      // Tier 1 — Small Family (1–2 Children) – 60/25/15
      else {
        return [
          StrategyBudgetingTip(
            category: 'Discipline',
            title: 'Start Strong',
            message: 'A small family is ideal for building disciplined habits early.',
            action: 'Budget with long-term family peace in mind.',
            icon: '💪',
            strategy: BudgetStrategy.familyCentric,
            priority: 1,
          ),
          StrategyBudgetingTip(
            category: 'Protection',
            title: 'Protect Priorities',
            message: 'Focus on essentials while leaving room for shared joy.',
            action: 'Honor milestones, even small ones, to build motivation.',
            icon: '🛡',
            strategy: BudgetStrategy.familyCentric,
            priority: 2,
          ),
          StrategyBudgetingTip(
            category: 'Financial Focus',
            title: 'Needs Over Trends',
            message: 'Avoid lifestyle comparison and social pressure.',
            action: 'Ask, "Is this essential?" to avoid impulse buys.',
            icon: '🛍',
            strategy: BudgetStrategy.familyCentric,
            priority: 3,
          ),
          StrategyBudgetingTip(
            category: 'Smart Planning',
            title: 'Plan Purchases',
            message: 'Budget for school, food, and outings in advance.',
            action: 'Invest in memories, not material distractions.',
            icon: '📝',
            strategy: BudgetStrategy.familyCentric,
            priority: 4,
          ),
          StrategyBudgetingTip(
            category: 'Savings',
            title: 'Build Safety Net',
            message: 'Even small, consistent savings protect the family.',
            action: 'Make saving automatic, not optional.',
            icon: '🏦',
            strategy: BudgetStrategy.familyCentric,
            priority: 5,
          ),
        ];
      }
    }
    
    // Default tips if numberOfChildren is not specified
    return [
      StrategyBudgetingTip(
        category: 'Family Security',
        title: 'Your Family\'s Financial Foundation',
        message: 'Strong families are built on solid financial ground - you\'re creating that foundation.',
        action: 'Prioritize family needs and savings to protect your loved ones.',
        icon: '🏠',
        strategy: BudgetStrategy.familyCentric,
        priority: 1,
      ),
      StrategyBudgetingTip(
        category: 'Smart Family Spending',
        title: 'Quality Over Quantity in Family Life',
        message: 'Your family needs security more than luxuries - invest in experiences over things.',
        action: 'Focus family fun on free or low-cost activities that create lasting memories.',
        icon: '👪',
        strategy: BudgetStrategy.familyCentric,
        priority: 2,
      ),
      StrategyBudgetingTip(
        category: 'Future Planning',
        title: 'Building Your Family\'s Tomorrow',
        message: 'Every peso saved today is an investment in your family\'s future opportunities.',
        action: 'Automate savings to ensure your family\'s long-term security without thinking about it.',
        icon: '🌱',
        strategy: BudgetStrategy.familyCentric,
        priority: 3,
      ),
      StrategyBudgetingTip(
        category: 'Resource Optimization',
        title: 'Maximize Every Family Peso',
        message: 'Smart shopping and meal planning can stretch your family budget significantly.',
        action: 'Plan weekly meals and shop with a list to avoid impulse purchases.',
        icon: '📋',
        strategy: BudgetStrategy.familyCentric,
        priority: 4,
      ),
    ];
  }

  /// Generate tips for risk control strategy (40/40/20)
  static List<StrategyBudgetingTip> _generateRiskControlTips(User user) {
    return [
      StrategyBudgetingTip(
        category: 'Income Buffer',
        title: 'Your Safety Net is Your Superpower',
        message: 'Irregular income requires a bigger safety cushion - you\'re building financial resilience.',
        action: 'Build an emergency fund equal to 3 months of expenses before increasing lifestyle spending.',
        icon: '🪂',
        strategy: BudgetStrategy.riskControl,
        priority: 1,
      ),
      StrategyBudgetingTip(
        category: 'Cash Flow Management',
        title: 'Smooth Out the Income Waves',
        message: 'High-earning months should cover low-earning months - think like a camel storing water.',
        action: 'Save 40% of high-income months to cover basic needs during lean periods.',
        icon: '🌊',
        strategy: BudgetStrategy.riskControl,
        priority: 2,
      ),
      StrategyBudgetingTip(
        category: 'Flexible Budgeting',
        title: 'Adapt and Overcome',
        message: 'Your variable income is actually an advantage - you can scale expenses based on earnings.',
        action: 'Create base and bonus budgets - live on the base, save the bonus.',
        icon: '🔄',
        strategy: BudgetStrategy.riskControl,
        priority: 3,
      ),
      StrategyBudgetingTip(
        category: 'Income Diversification',
        title: 'Multiple Streams, Multiple Security',
        message: 'The best defense against income uncertainty is having backup income sources.',
        action: 'Consider developing a secondary skill or passive income stream for stability.',
        icon: '🚰',
        strategy: BudgetStrategy.riskControl,
        priority: 4,
      ),
    ];
  }

  /// Generate tips for conservative strategy (75/10/15)
  static List<StrategyBudgetingTip> _generateConservativeTips(User user) {
    return [
      StrategyBudgetingTip(
        category: 'Wealth Preservation',
        title: 'Protect What You\'ve Built',
        message: 'You\'ve worked hard for your financial security - now it\'s time to preserve and protect it.',
        action: 'Focus 75% on essential needs and keep lifestyle inflation in check.',
        icon: '🛡',
        strategy: BudgetStrategy.conservative,
        priority: 1,
      ),
      StrategyBudgetingTip(
        category: 'Fixed Income Mastery',
        title: 'Make Every Peso Count',
        message: 'Fixed income requires fixed discipline - but also brings fixed peace of mind.',
        action: 'Prioritize needs, minimize wants, and maintain your savings safety net.',
        icon: '⚖',
        strategy: BudgetStrategy.conservative,
        priority: 2,
      ),
      StrategyBudgetingTip(
        category: 'Legacy Building',
        title: 'Your Financial Legacy Matters',
        message: 'Conservative spending today ensures you can be generous tomorrow.',
        action: 'Keep savings rate steady to maintain independence and help family when needed.',
        icon: '🎁',
        strategy: BudgetStrategy.conservative,
        priority: 3,
      ),
      StrategyBudgetingTip(
        category: 'Peace of Mind',
        title: 'Simplicity Brings Serenity',
        message: 'A conservative approach eliminates financial stress and brings clarity to life.',
        action: 'Focus on experiences and relationships rather than material accumulation.',
        icon: '☮',
        strategy: BudgetStrategy.conservative,
        priority: 4,
      ),
    ];
  }

  /// Generate tips for builder strategy (60/20/20)
  static List<StrategyBudgetingTip> _generateBuilderTips(User user) {
    return [
      StrategyBudgetingTip(
        category: 'Growth Mindset',
        title: 'You\'re in Your Prime Building Years',
        message: 'This is your time to build the financial foundation that will support your entire future.',
        action: 'Invest 20% in savings and 20% in building the life you want.',
        icon: '🏗',
        strategy: BudgetStrategy.builder,
        priority: 1,
      ),
      StrategyBudgetingTip(
        category: 'Strategic Investment',
        title: 'Invest in Your Future Self',
        message: 'Every peso saved now has decades to grow - you\'re planting trees for future shade.',
        action: 'Prioritize investments that appreciate over time rather than instant gratification.',
        icon: '📈',
        strategy: BudgetStrategy.builder,
        priority: 2,
      ),
      StrategyBudgetingTip(
        category: 'Balanced Living',
        title: 'Build Wealth While Living Life',
        message: 'You can save aggressively while still enjoying life - it\'s about smart choices, not deprivation.',
        action: 'Choose experiences and purchases that align with your long-term goals.',
        icon: '⚖',
        strategy: BudgetStrategy.builder,
        priority: 3,
      ),
      StrategyBudgetingTip(
        category: 'Compound Growth',
        title: 'Time is Your Greatest Asset',
        message: 'Starting early gives you the superpower of compound growth over decades.',
        action: 'Automate your savings to harness the power of consistency and time.',
        icon: '⏰',
        strategy: BudgetStrategy.builder,
        priority: 4,
      ),
    ];
  }

  /// Generate tips for balanced strategy (50/30/20)
  static List<StrategyBudgetingTip> _generateBalancedTips(User user) {
    return [
      StrategyBudgetingTip(
        category: 'Foundation Building',
        title: 'Start Strong, Stay Balanced',
        message: 'You\'re at the perfect stage to build healthy money habits that will serve you for life.',
        action: 'Master the 50/30/20 rule: needs, wants, and savings in perfect harmony.',
        icon: '⚖',
        strategy: BudgetStrategy.balanced,
        priority: 1,
      ),
      StrategyBudgetingTip(
        category: 'Smart Spending',
        title: 'Enjoy Life While Building Wealth',
        message: 'Your 20s and early 30s should be enjoyed - just make sure you\'re also investing in tomorrow.',
        action: 'Use your wants budget guilt-free, but never touch your savings allocation.',
        icon: '🎯',
        strategy: BudgetStrategy.balanced,
        priority: 2,
      ),
      StrategyBudgetingTip(
        category: 'Habit Formation',
        title: 'Build Habits That Build Wealth',
        message: 'The habits you form now will determine your financial future - make them powerful.',
        action: 'Automate your savings and track your spending to build awareness and discipline.',
        icon: '🔧',
        strategy: BudgetStrategy.balanced,
        priority: 3,
      ),
      StrategyBudgetingTip(
        category: 'Future Flexibility',
        title: 'Today\'s Balance, Tomorrow\'s Freedom',
        message: 'Balanced budgeting now gives you flexibility to handle life\'s big changes later.',
        action: 'Stay flexible with your categories but strict with your savings commitment.',
        icon: '🤸',
        strategy: BudgetStrategy.balanced,
        priority: 4,
      ),
    ];
  }



  /// Get strategy description for user interface
  static String getStrategyDescription(BudgetStrategy strategy) {
    switch (strategy) {
      case BudgetStrategy.debtHeavyRecovery:
        return 'Debt Recovery (70/20/10) - Based on your spending patterns';
      case BudgetStrategy.familyCentric:
        return 'Family Focus (Child-Based) - Tailored from your expenses';
      case BudgetStrategy.riskControl:
        return 'Income Protection (40/40/20) - Using your transaction history';
      case BudgetStrategy.conservative:
        return 'Wealth Protection (75/10/15) - Based on your spending data';
      case BudgetStrategy.builder:
        return 'Growth Strategy (60/20/20) - From your financial patterns';
      case BudgetStrategy.balanced:
        return 'Balanced Plan (50/30/20) - Using last month\'s data';
    }
  }

  /// Get strategy-specific budget allocations
  static Map<String, double> getStrategyAllocations(BudgetStrategy strategy, {int? numberOfChildren}) {
    switch (strategy) {
      case BudgetStrategy.debtHeavyRecovery:
        return {'Needs': 70.0, 'Wants': 20.0, 'Savings': 10.0};
      case BudgetStrategy.conservative:
        return {'Needs': 75.0, 'Wants': 10.0, 'Savings': 15.0};
      case BudgetStrategy.familyCentric:
        // Tiers by Children Count:
        // Children    Framework    Category Meaning
        // 1–2         60 / 25 / 15 Wants (normal)
        // 3–5         65 / 20 / 15 Tight wants
        // 6+          70 / 15 / 15 Wants minimized
        if (numberOfChildren != null) {
          if (numberOfChildren >= 6) {
            return {'Needs': 70.0, 'Wants': 15.0, 'Savings': 15.0}; // 70 / 15 / 15
          } else if (numberOfChildren >= 3) {
            return {'Needs': 65.0, 'Wants': 20.0, 'Savings': 15.0}; // 65 / 20 / 15
          } else {
            return {'Needs': 60.0, 'Wants': 25.0, 'Savings': 15.0}; // 60 / 25 / 15
          }
        }
        // Default to 1-2 children if not specified
        return {'Needs': 60.0, 'Wants': 25.0, 'Savings': 15.0};
      case BudgetStrategy.riskControl:
        return {'Needs': 40.0, 'Wants': 40.0, 'Savings': 20.0};
      case BudgetStrategy.builder:
        return {'Needs': 60.0, 'Wants': 20.0, 'Savings': 20.0};
      case BudgetStrategy.balanced:
        return {'Needs': 50.0, 'Wants': 30.0, 'Savings': 20.0};
    }
  }
}